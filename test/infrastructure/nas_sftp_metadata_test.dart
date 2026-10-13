import 'dart:async';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/data/models/nas_media.dart';
import 'package:valhalla/data/models/nas_source.dart';
import 'package:valhalla/infrastructure/nas/nas_sftp_adapter.dart';
import 'package:valhalla/infrastructure/ssh/ssh_client_manager.dart';

class _Ssh extends Fake implements SSHClient {
  final _Sftp Function() create;
  final channels = <_Sftp>[];
  _Ssh(this.create);
  @override
  bool get isClosed => false;
  @override
  Future<SftpClient> sftp() async {
    final channel = create();
    channels.add(channel);
    return channel;
  }
}

class _Executor extends Fake implements SshCommandExecutor {
  final _Ssh client;
  _Executor(this.client);
  @override
  SSHClient? getClient(String serverId) => client;
}

class _Sftp extends Fake implements SftpClient {
  final SftpFileAttrs attributes;
  final _File? file;
  final List<List<SftpName>> pages;
  final Map<String, Object> links;
  final listed = <String>[];
  bool closed = false;
  _Sftp(
    this.attributes, {
    this.file,
    this.pages = const [],
    this.links = const {},
  });
  @override
  Future<SftpFileAttrs> stat(String path, {bool followLink = true}) async {
    final value = links[path];
    if (value != null && value is! SftpFileAttrs) throw value;
    return value as SftpFileAttrs? ?? attributes;
  }

  @override
  Stream<List<SftpName>> readdir(String path) async* {
    listed.add(path);
    for (final page in pages) {
      if (closed) throw StateError('fixture channel closed');
      yield page;
    }
  }

  @override
  Future<SftpFile> open(
    String path, {
    SftpFileOpenMode mode = SftpFileOpenMode.read,
  }) async => file!;
  @override
  Future<void> close() async {
    closed = true;
  }
}

class _File extends Fake implements SftpFile {
  final Uint8List bytes;
  final SftpFileAttrs attributes;
  final requests = <({int offset, int? length, int pending})>[];
  bool closed = false;
  _File(this.bytes, this.attributes);
  @override
  Future<SftpFileAttrs> stat() async => attributes;
  @override
  Stream<Uint8List> read({
    int? length,
    int offset = 0,
    void Function(int)? onProgress,
    int chunkSize = 32768,
    int maxPendingRequests = 64,
  }) async* {
    requests.add((offset: offset, length: length, pending: maxPendingRequests));
    if (length == null) {
      throw StateError('fixture requires explicit read length');
    }
    if (offset >= bytes.length || length == 0) return;
    final end = (offset + length).clamp(0, bytes.length);
    yield Uint8List.sublistView(bytes, offset, end);
  }

  @override
  Future<void> close() async {
    closed = true;
  }
}

const _source = NasSource(
  id: 'sftp',
  name: 'SFTP',
  type: NasSourceType.sftp,
  sshServerId: 'server',
  rootPath: '/default',
);
const _item = NasMediaItem(
  serverId: 'sftp',
  path: '/media/song.mp3',
  kind: NasMediaKind.audio,
  sizeBytes: 3,
  modifiedEpoch: 1,
);

void main() {
  for (final length in [0, 17, 256 * 1024, 256 * 1024 + 7, 512 * 1024]) {
    test('SFTP unknown stat size reads $length bytes to real EOF', () async {
      final bytes = Uint8List.fromList(
        List.generate(length, (index) => index % 251),
      );
      final attrs = SftpFileAttrs(modifyTime: 10);
      final file = _File(bytes, attrs);
      final ssh = _Ssh(() => _Sftp(attrs, file: file));
      final resource = await NasSftpAdapter(
        _source,
        _Executor(ssh),
      ).resolve(_item);
      expect(resource.sizeBytes, isNull);
      expect(resource.version, isNull);
      final received = await resource.read!(0, null, NasCancellation())
          .expand((chunk) => chunk)
          .toList();
      expect(received, bytes);
      expect(
        file.requests.every(
          (request) => request.length == 256 * 1024 && request.pending == 1,
        ),
        isTrue,
      );
      expect(file.closed, isTrue);
      expect(ssh.channels.every((channel) => channel.closed), isTrue);
    });
  }

  test(
    'unknown stat size respects explicit range without stale index validation',
    () async {
      final attrs = SftpFileAttrs();
      final file = _File(
        Uint8List.fromList(List.generate(100, (i) => i)),
        attrs,
      );
      final ssh = _Ssh(() => _Sftp(attrs, file: file));
      final resource = await NasSftpAdapter(
        _source,
        _Executor(ssh),
      ).resolve(_item);
      expect(
        await resource.read!(17, 40, NasCancellation())
            .expand((chunk) => chunk)
            .toList(),
        List.generate(23, (i) => i + 17),
      );
      expect(file.requests.single.length, 23);
    },
  );

  for (final change in ['size', 'mtime']) {
    test('known SFTP $change change fails before reading', () async {
      final initial = SftpFileAttrs(size: 20, modifyTime: 10);
      final changed = SftpFileAttrs(
        size: change == 'size' ? 21 : 20,
        modifyTime: change == 'mtime' ? 11 : 10,
      );
      final file = _File(Uint8List(20), changed);
      final ssh = _Ssh(() => _Sftp(initial, file: file));
      final resource = await NasSftpAdapter(
        _source,
        _Executor(ssh),
      ).resolve(_item);
      expect(resource.version, 'sftp:20:10');
      await expectLater(
        resource.read!(0, null, NasCancellation()).drain<void>(),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'code',
            'NAS_DOWNLOAD_SOURCE_CHANGED',
          ),
        ),
      );
      expect(file.requests, isEmpty);
      expect(file.closed, isTrue);
    });
  }

  test(
    'unknown size cancellation closes owned channel after first bounded read',
    () async {
      final attrs = SftpFileAttrs();
      final file = _File(Uint8List(512 * 1024), attrs);
      final ssh = _Ssh(() => _Sftp(attrs, file: file));
      final resource = await NasSftpAdapter(
        _source,
        _Executor(ssh),
      ).resolve(_item);
      final cancellation = NasCancellation();
      final iterator = StreamIterator(resource.read!(0, null, cancellation));
      expect(await iterator.moveNext(), isTrue);
      cancellation.cancel();
      await expectLater(iterator.moveNext(), throwsA(isA<NasCancelled>()));
      await iterator.cancel();
      expect(file.requests, hasLength(1));
      expect(ssh.channels.every((channel) => channel.closed), isTrue);
      expect(ssh.isClosed, isFalse);
    },
  );

  test(
    'SFTP browse is one layer, outside default root, resolves and blocks links',
    () async {
      final folder = SftpFileAttrs(mode: SftpFileMode.value(0x4000));
      final link = SftpFileAttrs(mode: SftpFileMode.value(0xa000));
      SftpName entry(String name, SftpFileAttrs attrs) =>
          SftpName(filename: name, longname: '', attr: attrs);
      final channels = <_Sftp>[];
      final ssh = _Ssh(() {
        final channel = _Sftp(
          folder,
          pages: [
            [entry('.', folder), entry('..', folder), entry('alias', link)],
            [entry('broken', link), entry('.hidden', folder)],
          ],
          links: {
            '/other/alias': folder,
            '/other/broken': SftpStatusError(
              SftpStatusCode.noSuchFile,
              'fixture missing',
            ),
          },
        );
        channels.add(channel);
        return channel;
      });
      final pages = await NasSftpAdapter(
        _source,
        _Executor(ssh),
      ).browse('/other', NasCancellation()).toList();
      expect(pages.map((page) => page.length), [1, 2]);
      expect(pages.first.single.id, '/other/alias');
      expect(pages.first.single.isSymbolicLink, isTrue);
      expect(pages.first.single.canEnter, isTrue);
      expect(pages.last.first.selectable, isFalse);
      expect(pages.last.last.isHidden, isTrue);
      expect(channels.single.listed, ['/other']);
      expect(channels.single.closed, isTrue);
    },
  );

  test(
    'SFTP link connection loss propagates instead of becoming broken link',
    () async {
      final link = SftpFileAttrs(mode: SftpFileMode.value(0xa000));
      final ssh = _Ssh(
        () => _Sftp(
          link,
          pages: [
            [SftpName(filename: 'alias', longname: '', attr: link)],
          ],
          links: {
            '/alias': SftpStatusError(
              SftpStatusCode.connectionLost,
              'fixture lost',
            ),
          },
        ),
      );
      await expectLater(
        NasSftpAdapter(
          _source,
          _Executor(ssh),
        ).browse('/', NasCancellation()).drain<void>(),
        throwsA(
          isA<SftpStatusError>().having(
            (error) => error.code,
            'code',
            SftpStatusCode.connectionLost,
          ),
        ),
      );
      expect(ssh.channels.single.closed, isTrue);
    },
  );
}
