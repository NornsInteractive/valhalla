import 'package:path/path.dart' as p;

import '../ssh/ssh_client_manager.dart';

enum RemoteFileAction { copy, move, delete, download }

enum RemoteFileOutcome { completed, queued, skipped, failed }

class RemoteFileResult {
  final String path;
  final RemoteFileOutcome outcome;
  final String? error;

  const RemoteFileResult(this.path, this.outcome, [this.error]);
}

/// Server-side copies never stream file contents through the mobile client.
class RemoteFileActions {
  final SshCommandExecutor executor;
  RemoteFileActions(this.executor);

  static String _quote(String value) => "'${value.replaceAll("'", "'\\''")}'";

  static String command(
    RemoteFileAction action,
    String source,
    String directory,
  ) {
    if (action != RemoteFileAction.copy && action != RemoteFileAction.move) {
      throw ArgumentError.value(action, 'action');
    }
    for (final value in [source, directory]) {
      if (!p.posix.isAbsolute(value) || value.contains('\x00')) {
        throw const FormatException('FILE_PATH_INVALID');
      }
    }
    source = p.posix.normalize(source);
    directory = p.posix.normalize(directory);
    if (source == '/') {
      throw const FormatException('FILE_ROOT_OPERATION_DENIED');
    }
    final target = p.posix.join(directory, p.posix.basename(source));
    if (target == source || p.posix.isWithin(source, target)) {
      throw const FormatException('FILE_TARGET_IS_SOURCE');
    }
    // shortcut: requires GNU coreutils; add a platform adapter only when supporting other hosts.
    // The temporary directory is exclusively created under the chosen parent.
    final operation = action == RemoteFileAction.copy
        ? r'''
stage=$(command mktemp -d -- "$parent/.valhalla-copy.XXXXXXXX") || exit 1
trap 'command rm -rf -- "$stage"' EXIT
command cp -a -- "$src" "$stage/item" || exit 1
command mv -n -T -- "$stage/item" "$dest" || exit 1
if [ -e "$stage/item" ] || [ -L "$stage/item" ]; then
  printf '\nVALHALLA_FILE_SKIPPED\n'
else
  printf '\nVALHALLA_FILE_COMPLETED\n'
fi
'''
        : r'''
command mv -n -T -- "$src" "$dest" || exit 1
if [ -e "$src" ] || [ -L "$src" ]; then
  printf '\nVALHALLA_FILE_SKIPPED\n'
else
  printf '\nVALHALLA_FILE_COMPLETED\n'
fi
''';
    final prelude =
        '''src=${_quote(source)}
parent=${_quote(directory)}
dest=${_quote(target)}
'''
        r'''
set -eu
[ -d "$parent" ] || exit 1
if [ ! -e "$src" ] && [ ! -L "$src" ]; then exit 1; fi
if [ -e "$dest" ] || [ -L "$dest" ]; then
  printf '\nVALHALLA_FILE_SKIPPED\n'; exit 0
fi
if [ -d "$src" ] && [ ! -L "$src" ]; then
  source_real=$(command realpath -e -- "$src") || exit 1
  parent_real=$(command realpath -e -- "$parent") || exit 1
  case "$parent_real/" in "$source_real/"*) exit 1;; esac
fi
''';
    return '$prelude$operation';
  }

  Future<RemoteFileResult> execute(
    String serverId,
    RemoteFileAction action,
    String source,
    String directory,
  ) async {
    final result = await executor.executeWithLoginShell(
      serverId,
      command(action, source, directory),
      timeout: const Duration(minutes: 30),
    );
    if (result.isSuccess &&
        result.stdout.trimRight().endsWith('VALHALLA_FILE_COMPLETED')) {
      return RemoteFileResult(source, RemoteFileOutcome.completed);
    }
    if (result.isSuccess &&
        result.stdout.trimRight().endsWith('VALHALLA_FILE_SKIPPED')) {
      return RemoteFileResult(
        source,
        RemoteFileOutcome.skipped,
        'FILE_TARGET_EXISTS',
      );
    }
    return RemoteFileResult(
      source,
      RemoteFileOutcome.failed,
      'FILE_OPERATION_FAILED: exit ${result.exitCode}: ${result.stderr.trim()}',
    );
  }
}
