import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/providers/nas_provider.dart';
import 'package:valhalla/core/providers/nas_sources_provider.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/data/models/nas_media.dart';
import 'package:valhalla/data/models/nas_source.dart';
import 'package:valhalla/data/models/remote_browser.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/features/nas/widgets/nas_scan_config_dialog.dart';
import 'package:valhalla/features/nas/widgets/nas_source_dialog.dart';
import 'package:valhalla/l10n/app_localizations.dart';
import 'package:valhalla/widgets/remote_browser_dialog.dart';
import '../support/nas_browser_fixture.dart';

const _webdav = NasSource(
  id: 'draft-dav',
  name: 'Draft DAV',
  type: NasSourceType.webdav,
  endpoint: 'https://dav.invalid/endpoint',
  username: 'fixture-user',
  rootPath: '/original',
);
const _smb = NasSource(
  id: 'saved-smb',
  name: 'Saved SMB',
  type: NasSourceType.smb,
  endpoint: 'smb://smb.invalid/share/base',
  username: 'fixture-user',
  rootPath: '/original',
);
const _media = NasSource(
  id: 'saved-media',
  name: 'Saved media',
  type: NasSourceType.jellyfin,
  endpoint: 'https://media.invalid',
  username: 'fixture-user',
  userId: 'fixture-user-id',
);
const _movieId = 'library:movies 2026';
const _musicId = 'library:music%2026';
const _libraries = [
  RemoteBrowserEntry(
    id: _movieId,
    name: 'Movies',
    isDirectory: true,
    canEnter: false,
  ),
  RemoteBrowserEntry(
    id: _musicId,
    name: 'Music',
    isDirectory: true,
    canEnter: false,
  ),
];

class _Servers extends ServerListNotifier {
  @override
  List<ServerProfile> build() => const [];
}

class _Active extends ActiveServerNotifier {
  @override
  ServerProfile? build() => null;
}

class _Nas extends NasNotifier {
  int scans = 0;

  @override
  NasState build() => const NasState();

  @override
  Future<void> scan() async => scans++;
}

/// Fake only provider I/O; modal listing/selection/cancellation uses real leases.
class _Sources extends NasSourcesNotifier {
  final List<NasSource> initialSources;
  _Sources([this.initialSources = const []]);

  final opened = <NasSource>[];
  final openedCredentials = <NasCredentials>[];
  final openedSaved = <NasSource>[];
  final leases = <RemoteBrowserSource>[];
  final listedPaths = <String>[];
  final saved = <NasSource>[];
  final savedCredentials = <NasCredentials>[];
  int probes = 0, selections = 0, domainReads = 0;
  Completer<void>? openGate;
  Completer<String>? domainGate;
  Completer<({String userId, NasCredentials credentials})>? authGate;
  Object? domainError;
  int authentications = 0;

  @override
  NasSourcesState build() => NasSourcesState(
    sources: initialSources,
    selectedId: initialSources.firstOrNull?.id,
  );

  void replaceSelected(NasSource source) {
    state = NasSourcesState(sources: [source], selectedId: source.id);
  }

  @override
  Future<void> save(
    NasSource source,
    NasCredentials credentials, {
    bool probe = true,
    bool keepEmptySecrets = false,
  }) async {
    saved.add(source);
    savedCredentials.add(credentials);
  }

  @override
  Future<void> select(String id) async => selections++;

  @override
  Future<void> probe(
    NasSource source,
    NasCredentials credentials, {
    bool keepEmptySecrets = false,
  }) async {
    probes++;
  }

  @override
  Future<String> savedDomain(NasSource source) async {
    domainReads++;
    if (domainError != null) throw domainError!;
    return domainGate == null ? 'SAVED-DOMAIN' : domainGate!.future;
  }

  @override
  Future<({String userId, NasCredentials credentials})> authenticate(
    NasSource source,
    String password,
  ) async {
    authentications++;
    return authGate == null
        ? (
            userId: 'authenticated-user',
            credentials: const NasCredentials(token: 'fixture-token'),
          )
        : authGate!.future;
  }

  RemoteBrowserSource _lease(NasSource source, bool Function()? isCurrent) {
    final lease = RemoteBrowserSource(
      targetKey: 'fixture::${source.id}::${source.endpoint}',
      label: source.name,
      rootPath: '/',
      initialPath: source.isMediaServer || source.type == NasSourceType.webdav
          ? '/'
          : source.rootPath,
      flat: source.isMediaServer,
      isCurrent: () => ref.mounted && (isCurrent?.call() ?? true),
      list: (path, cancelled) async* {
        listedPaths.add(path);
        if (source.isMediaServer) {
          yield _libraries;
        } else if (path == '/photos') {
          yield const [];
        } else {
          yield const [
            RemoteBrowserEntry(
              id: '/photos',
              name: 'Photos',
              isDirectory: true,
            ),
          ];
        }
      },
    );
    leases.add(lease);
    return lease;
  }

  @override
  Future<RemoteBrowserSource> openBrowser(
    NasSource source,
    NasCredentials credentials, {
    bool keepEmptySecrets = false,
    bool Function()? isCurrent,
  }) async {
    opened.add(source);
    openedCredentials.add(credentials);
    final lease = _lease(source, isCurrent);
    if (openGate != null) await openGate!.future;
    return lease;
  }

  @override
  Future<RemoteBrowserSource> openSavedBrowser(
    NasSource source, {
    bool Function()? isCurrent,
  }) async {
    openedSaved.add(source);
    return _lease(source, isCurrent);
  }
}

void main() {
  late _Sources sources;
  late _Nas nas;
  NasScanConfig? savedConfig;
  setUp(() {
    sources = _Sources();
    nas = _Nas();
    savedConfig = null;
  });

  Future<void> host(
    WidgetTester tester, {
    NasSource source = _webdav,
    bool editing = false,
    NasScanConfig? scanConfig,
    bool settle = true,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nasSourcesProvider.overrideWith(() => sources),
          nasProvider.overrideWith(() => nas),
          serverListProvider.overrideWith(_Servers.new),
          activeServerProvider.overrideWith(_Active.new),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () {
                  if (scanConfig != null) {
                    NasScanConfigDialog.show(
                      context,
                      source: source,
                      sourceId: source.id,
                      initialConfig: scanConfig,
                      onSave: (config) => savedConfig = config,
                    );
                  } else {
                    NasSourceDialog.show(
                      context,
                      source: editing ? source : null,
                      initialDraft: editing ? null : source,
                    );
                  }
                },
                child: const Text('Open fixture'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open fixture'));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  String field(WidgetTester tester, String key) =>
      tester.widget<TextField>(find.byKey(Key(key))).controller!.text;

  Future<void> tapKey(
    WidgetTester tester,
    String key, {
    bool settle = true,
  }) async {
    final finder = find.byKey(Key(key));
    await settleNasBrowser(tester);
    expect(finder, findsOneWidget, reason: 'Required migrated caller: $key');
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  Future<void> cancelBrowser(WidgetTester tester) async {
    await tester.tap(
      find.descendant(
        of: find.byType(RemoteBrowserDialog),
        matching: find.widgetWithText(TextButton, 'Cancel'),
      ),
    );
    await tester.pumpAndSettle();
  }

  void expectReadOnly() {
    expect(sources.saved, isEmpty);
    expect(sources.selections, 0);
    expect(sources.probes, 0);
    expect(nas.scans, 0);
  }

  testWidgets('WebDAV draft root browses endpoint root without persisting', (
    tester,
  ) async {
    await host(tester);
    await tester.enterText(
      find.byKey(const Key('nas_source_password_field')),
      'fixture-password',
    );
    await tapKey(tester, 'nas_source_browse_root');
    expect(sources.opened.single.rootPath, '/');
    expect(sources.opened.single.endpoint, _webdav.endpoint);
    expect(sources.openedCredentials.single.password, 'fixture-password');
    expect(sources.listedPaths, ['/']);
    await tester.tap(find.text('Photos'));
    await settleNasBrowser(tester);
    await tapKey(tester, 'remote_browser_confirm_button');
    expect(field(tester, 'nas_source_root_path_field'), '/photos');
    expect(sources.openedSaved, isEmpty);
    expect(sources.leases.single.isCurrent, isFalse);
    expectReadOnly();
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelling draft root browser leaves original form unchanged', (
    tester,
  ) async {
    await host(tester);
    await tapKey(tester, 'nas_source_browse_root');
    await tester.tap(find.text('Photos'));
    await settleNasBrowser(tester);
    await cancelBrowser(tester);
    expect(field(tester, 'nas_source_root_path_field'), '/original');
    expect(field(tester, 'nas_source_endpoint_field'), _webdav.endpoint);
    expect(sources.leases.single.isCurrent, isFalse);
    expectReadOnly();
  });

  testWidgets('late browser result cannot overwrite a revised source draft', (
    tester,
  ) async {
    sources.openGate = Completer<void>();
    await host(tester);
    await tapKey(tester, 'nas_source_browse_root', settle: false);
    expect(sources.opened, hasLength(1));
    // The remote lease is opening, so the source form is still the public route.
    await tester.enterText(
      find.byKey(const Key('nas_source_endpoint_field')),
      'https://replacement.invalid/dav',
    );
    await tester.pump();
    sources.openGate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(RemoteBrowserDialog), findsNothing);
    expect(field(tester, 'nas_source_root_path_field'), '/original');
    expect(
      field(tester, 'nas_source_endpoint_field'),
      'https://replacement.invalid/dav',
    );
    expect(sources.leases.single.isCurrent, isFalse);
    expectReadOnly();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'SMB domain initialization gates actions and explicit clear stays blank',
    (tester) async {
      sources = _Sources([_smb])..domainGate = Completer<String>();
      await host(tester, source: _smb, editing: true, settle: false);
      expect(sources.domainReads, 1);
      // Implementations may disable or await these public actions. Neither may
      // build credentials before the saved domain has finished loading.
      for (final key in [
        'nas_source_browse_root',
        'nas_source_probe_button',
        'nas_source_save_button',
      ]) {
        expect(find.byKey(Key(key)), findsOneWidget);
      }
      await tapKey(tester, 'nas_source_browse_root', settle: false);
      expect(sources.opened, isEmpty);
      expectReadOnly();
      sources.domainGate!.complete('SAVED-DOMAIN');
      await tester.pumpAndSettle();
      // An awaited action may now have opened the browser; close it before editing.
      if (find.byType(RemoteBrowserDialog).evaluate().isNotEmpty) {
        await cancelBrowser(tester);
      }
      expect(field(tester, 'nas_source_domain_field'), 'SAVED-DOMAIN');
      await tester.enterText(
        find.byKey(const Key('nas_source_domain_field')),
        '',
      );
      await tapKey(tester, 'nas_source_browse_root');
      expect(sources.opened.last.endpoint, _smb.endpoint);
      expect(sources.openedCredentials.last.domain, '');
      await cancelBrowser(tester);
      await tapKey(tester, 'nas_source_save_button');
      expect(sources.savedCredentials.single.domain, '');
      expect(sources.saved.single.rootPath, '/original');
      expect(nas.scans, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('media source stores opaque library ID without navigating it', (
    tester,
  ) async {
    sources = _Sources([_media]);
    await host(tester, source: _media, editing: true);
    await tapKey(tester, 'nas_source_browse_root');
    await tester.tap(find.text('Movies'));
    await tester.pumpAndSettle();
    await tapKey(tester, 'remote_browser_confirm_button');
    expect(sources.listedPaths, ['/']);
    expectReadOnly();
    await tapKey(tester, 'nas_source_save_button');
    expect(sources.saved.single.rootPath, _movieId);
    expect(sources.leases.single.isCurrent, isFalse);
  });

  testWidgets('media include selection replaces all sentinel with opaque IDs', (
    tester,
  ) async {
    sources = _Sources([_media]);
    await host(
      tester,
      source: _media,
      scanConfig: const NasScanConfig(includePaths: ['/']),
    );
    await tapKey(tester, 'nas_scan_browse_include');
    expect(sources.opened, isEmpty);
    expect(sources.openedSaved.single, same(_media));
    await tester.tap(find.text('Movies'));
    await tester.pumpAndSettle();
    await tapKey(tester, 'remote_browser_confirm_button');
    await tapKey(tester, 'nas_config_save_button');
    expect(savedConfig!.includePaths, [_movieId]);
    expect(savedConfig!.excludePaths, isEmpty);
    expect(sources.listedPaths, ['/']);
    expectReadOnly();
  });

  testWidgets(
    'include all is exclusive and exclude never offers all libraries',
    (tester) async {
      sources = _Sources([_media]);
      await host(
        tester,
        source: _media,
        scanConfig: const NasScanConfig(includePaths: [_movieId]),
      );
      await tapKey(tester, 'nas_scan_include_all_libraries');
      await tapKey(tester, 'nas_scan_browse_exclude');
      expect(
        find.descendant(
          of: find.byType(RemoteBrowserDialog),
          matching: find.byKey(const Key('nas_scan_include_all_libraries')),
        ),
        findsNothing,
      );
      await tester.tap(find.text('Music'));
      await tester.pumpAndSettle();
      await tapKey(tester, 'remote_browser_confirm_button');
      await tapKey(tester, 'nas_config_save_button');
      expect(savedConfig!.includePaths, ['/']);
      expect(savedConfig!.excludePaths, [_musicId]);
      expect(sources.listedPaths, ['/']);
      expectReadOnly();
    },
  );

  testWidgets('manual media exclusions do not offer or accept all libraries', (
    tester,
  ) async {
    sources = _Sources([_media]);
    await host(
      tester,
      source: _media,
      scanConfig: const NasScanConfig(includePaths: ['/']),
    );
    await tapKey(tester, 'nas_add_exclude_path_button');
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const Key('nas_exclude_path_input')),
          )
          .initialValue,
      '',
    );
    await tester.enterText(
      find.byKey(const Key('nas_exclude_path_input')),
      'all',
    );
    await tapKey(tester, 'nas_confirm_exclude_path');
    expect(find.byType(SnackBar).hitTestable(), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tapKey(tester, 'nas_config_save_button');
    expect(savedConfig!.includePaths, ['/']);
    expect(savedConfig!.excludePaths, isEmpty);
    expectReadOnly();
  });

  testWidgets(
    'same-ID source replacement after picking blocks browse and stale config save',
    (tester) async {
      sources = _Sources([_media]);
      await host(
        tester,
        source: _media,
        scanConfig: const NasScanConfig(includePaths: ['/']),
      );
      await tapKey(tester, 'nas_scan_browse_include');
      await tester.tap(find.text('Movies'));
      await tester.pumpAndSettle();
      await tapKey(tester, 'remote_browser_confirm_button');
      expect(find.text('Movies'), findsOneWidget);
      // Credential-only saves publish a fresh object even when metadata is equal.
      sources.replaceSelected(NasSource.fromJson(_media.toJson()));
      await tapKey(tester, 'nas_scan_browse_exclude');
      expect(sources.openedSaved, hasLength(1));
      expect(find.byType(RemoteBrowserDialog), findsNothing);
      await tapKey(tester, 'nas_config_save_button');
      expect(savedConfig, isNull);
      expect(find.byType(NasScanConfigDialog), findsNothing);
      expectReadOnly();
    },
  );

  testWidgets('scan picker cancellation preserves include and exclude lists', (
    tester,
  ) async {
    sources = _Sources([_media]);
    await host(
      tester,
      source: _media,
      scanConfig: const NasScanConfig(
        includePaths: [_movieId],
        excludePaths: [_musicId],
      ),
    );
    await tapKey(tester, 'nas_scan_browse_include');
    await tester.tap(find.text('Music'));
    await tester.pumpAndSettle();
    await cancelBrowser(tester);
    await tapKey(tester, 'nas_scan_browse_exclude');
    await tester.tap(find.text('Movies'));
    await tester.pumpAndSettle();
    await cancelBrowser(tester);
    await tapKey(tester, 'nas_config_save_button');
    expect(savedConfig!.includePaths, [_movieId]);
    expect(savedConfig!.excludePaths, [_musicId]);
    expect(sources.leases.every((lease) => !lease.isCurrent), isTrue);
    expectReadOnly();
    expect(tester.takeException(), isNull);
  });

  testWidgets('late authentication cannot authorize a revised media endpoint', (
    tester,
  ) async {
    sources = _Sources([_media])
      ..authGate = Completer<({String userId, NasCredentials credentials})>();
    await host(tester, source: _media, editing: true);
    await tapKey(tester, 'nas_source_auth_button', settle: false);
    expect(sources.authentications, 1);
    await tester.enterText(
      find.byKey(const Key('nas_source_endpoint_field')),
      'https://replacement.invalid',
    );
    sources.authGate!.complete((
      userId: 'old-user',
      credentials: const NasCredentials(token: 'old-token'),
    ));
    await tester.pumpAndSettle();
    await tapKey(tester, 'nas_source_browse_root');
    expect(sources.opened.single.endpoint, 'https://replacement.invalid');
    expect(sources.opened.single.userId, isNull);
    expect(sources.openedCredentials.single.token, isEmpty);
    await cancelBrowser(tester);
    expectReadOnly();
  });

  testWidgets(
    'changing media identity clears previously acquired login token',
    (tester) async {
      sources = _Sources([_media]);
      await host(tester, source: _media, editing: true);
      await tapKey(tester, 'nas_source_auth_button');
      await tester.enterText(
        find.byKey(const Key('nas_source_username_field')),
        'different-user',
      );
      await tapKey(tester, 'nas_source_browse_root');
      expect(sources.opened.single.username, 'different-user');
      expect(sources.opened.single.userId, isNull);
      expect(sources.openedCredentials.single.token, isEmpty);
      await cancelBrowser(tester);
      expectReadOnly();
    },
  );

  testWidgets(
    'failed saved domain read blocks credential submission until retry succeeds',
    (tester) async {
      sources = _Sources([_smb])
        ..domainError = StateError('secret=do-not-display');
      await host(tester, source: _smb, editing: true);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('nas_source_save_button')),
            )
            .onPressed,
        isNull,
      );
      await tapKey(tester, 'nas_source_browse_root');
      expect(sources.opened, isEmpty);
      expect(find.textContaining('do-not-display'), findsNothing);
      sources.domainError = null;
      await tapKey(tester, 'nas_source_probe_button');
      expect(field(tester, 'nas_source_domain_field'), 'SAVED-DOMAIN');
      await tapKey(tester, 'nas_source_save_button');
      expect(sources.savedCredentials.single.domain, 'SAVED-DOMAIN');
      expect(sources.domainReads, 2);
    },
  );

  testWidgets(
    'renaming source while saved domain loads preserves credential identity',
    (tester) async {
      sources = _Sources([_smb])..domainGate = Completer<String>();
      await host(tester, source: _smb, editing: true, settle: false);
      await tester.enterText(
        find.byKey(const Key('nas_source_name_field')),
        'Renamed SMB',
      );
      sources.domainGate!.complete('SAVED-DOMAIN');
      await tester.pumpAndSettle();
      expect(field(tester, 'nas_source_domain_field'), 'SAVED-DOMAIN');
      await tapKey(tester, 'nas_source_save_button');
      expect(sources.savedCredentials.single.domain, 'SAVED-DOMAIN');
    },
  );

  testWidgets(
    'unavailable stored library stays visible until explicitly removed',
    (tester) async {
      sources = _Sources([_media]);
      await host(
        tester,
        source: _media,
        scanConfig: const NasScanConfig(includePaths: ['removed-library']),
      );
      expect(find.text('removed-library'), findsOneWidget);
      await tapKey(tester, 'nas_scan_browse_include');
      await tester.tap(find.text('Movies'));
      await tester.pumpAndSettle();
      await tapKey(tester, 'remote_browser_confirm_button');
      expect(find.text('Movies'), findsOneWidget);
      expect(find.text('removed-library'), findsOneWidget);
      await tapKey(tester, 'delete_include_path_removed-library');
      await tapKey(tester, 'nas_config_save_button');
      expect(savedConfig!.includePaths, [_movieId]);
      expectReadOnly();
    },
  );
}
