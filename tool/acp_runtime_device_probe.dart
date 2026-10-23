// Isolated device harness; never reads production preferences or chat history.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:valhalla/core/utils/shell_quote.dart';
import 'package:valhalla/data/models/agent_profile.dart';
import 'package:valhalla/infrastructure/acp/acp_client_adapter.dart';
import 'package:valhalla/infrastructure/acp/acp_runtime_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SizedBox.shrink());
  unawaited(_probe().catchError((Object error, StackTrace stack) {
    debugPrint('ACP_DEVICE_PROBE ${jsonEncode({'error': error.toString()})}');
  }));
}

Future<void> _probe() async {
  final root = Directory(
    '${(await getApplicationSupportDirectory()).path}/acp-device-probe',
  );
  await root.create(recursive: true);
  final file = File('${root.path}/state.json');
  final saved = await file.exists()
      ? jsonDecode(await file.readAsString()) as Map<String, dynamic>
      : <String, dynamic>{};
  final fresh = saved.isEmpty;
  var text = saved['text'] as String? ?? '';
  final key = sha256.convert(utf8.encode('valhalla-device-probe-v1')).toString();
  final ssh = SSHClient(
    await SSHSocket.connect('127.0.0.1', 54323),
    username: 'fixture',
    onPasswordRequest: () => 'fixture-only',
    onVerifyHostKey: (_, _) => true,
  );
  await ssh.authenticated;
  final config = jsonEncode({
    'sessionId': 'device-session',
    'chunks': 30,
    'chunkDelay': 1,
    'promptCountFile': '/tmp/vacp-device/prompts.count',
  });
  final command = 'python3 -u '
      '/workspace/projects/valhalla/tool/acp_device_fake_agent.py '
      '${cliShellQuote(config)}';
  final profile = AgentProfile(
    id: 'acp-device-probe', serverId: 'fixture', name: 'Device probe',
    description: 'No production Agent', cliCommand: command, acpCommand: command,
  );
  final transport = await AcpRuntimeService.open(
    ssh, profile, runtimeKey: key,
    afterSequence: saved['cursor'] as int? ?? 0,
    remoteSessionId: saved['sessionId'] as String?,
  );
  final adapter = ACPClientAdapter(
    profile: profile, transport: transport,
    workingDirectory: '/tmp/vacp-device',
    resumeSessionId: saved['sessionId'] as String?,
  );
  var writes = Future<void>.value();
  var finished = false;
  final complete = Completer<void>();
  Future<void> persist({bool done = false}) {
    final snapshot = jsonEncode({
      'runtimeKey': key, 'sessionId': adapter.sessionId ?? saved['sessionId'],
      'cursor': adapter.runtimeCursor, 'text': text, 'done': done,
    });
    writes = writes.then((_) async {
      final temporary = File('${file.path}.part');
      await temporary.writeAsString(snapshot, flush: true);
      await temporary.rename(file.path);
      debugPrint('ACP_DEVICE_PROBE $snapshot');
    });
    return writes;
  }
  final sub = adapter.eventStream.listen((event) {
    if (event is ACPContentChunkEvent) {
      text += event.chunk;
      unawaited(persist());
    } else if (event is ACPErrorEvent && !finished) {
      if (!complete.isCompleted) complete.completeError(StateError(event.error));
    } else if (event is ACPPersistentStatusEvent && event.settled &&
        event.status == 'completed' && !finished) {
      finished = true;
      unawaited(persist(done: true).then((_) {
        if (!complete.isCompleted) complete.complete();
      }, onError: (Object error, StackTrace stack) {
        if (!complete.isCompleted) complete.completeError(error, stack);
      }));
    }
  });
  try {
    await adapter.prepareSession();
    await persist(done: finished);
    if (fresh) {
      adapter.setPersistentTurn('probe-turn');
      unawaited(adapter.sendPrompt('fixture-only probe'));
    }
    await complete.future.timeout(const Duration(seconds: 90));
    await writes;
    final chunks = RegExp(r'chunk-(\d+)').allMatches(text)
        .map((match) => int.parse(match[1]!)).toList();
    if (chunks.length != 30 || chunks.toSet().length != 30 ||
        chunks.indexed.any((value) => value.$1 != value.$2)) {
      throw StateError('Probe output missing, duplicated or reordered: $chunks');
    }
    debugPrint('ACP_DEVICE_PROBE ${jsonEncode({'passed': true, 'chunks': chunks.length})}');
  } finally {
    adapter.dispose();
    await sub.cancel();
    ssh.close();
  }
}
