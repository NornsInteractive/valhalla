import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/providers/settings_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';

const _experimentalKey = 'valhalla_experimental_features_v1';
const _bottomNavigationKey = 'valhalla_bottom_navigation_v1';
const _quickSectionsKey = 'valhalla_dashboard_quick_sections_v1';
const _startupKey = 'valhalla_startup_section_v1';

Future<LocalStorageService> _storage() async =>
    LocalStorageService(await SharedPreferences.getInstance());

// 只在显式给定初始值时播种：重复调用不得清掉同一用例里已写入的键，
// 否则“跨重启”用例会把自己的持久化结果擦掉。
Future<ProviderContainer> _container({
  Map<String, Object> seed = const {},
}) async {
  if (seed.isNotEmpty) {
    SharedPreferences.setMockInitialValues(Map<String, Object>.of(seed));
  }
  return ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWithValue(await _storage()),
    ],
  );
}

/// 模拟落盘失败：写入抛错且不改动任何既有存储值。
class _FailingStorage extends LocalStorageService {
  _FailingStorage(super.prefs);

  @override
  Future<void> setExperimentalFeatures(List<String> features) async {
    throw StateError('Could not persist experimental features');
  }
}

Future<ProviderContainer> _failingContainer() async {
  SharedPreferences.setMockInitialValues({});
  return ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWithValue(
        _FailingStorage(await SharedPreferences.getInstance()),
      ),
    ],
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('experimentalFeaturesFromStorage 解析', () {
    test('缺键、空列表、未知名字都不开启任何实验特性', () {
      expect(experimentalFeaturesFromStorage(null), isEmpty);
      expect(experimentalFeaturesFromStorage(const []), isEmpty);
      expect(
        experimentalFeaturesFromStorage(const [
          'telemetry',
          'cli_chat',
          'CLIChat',
          'cli-chat',
          '',
        ]),
        isEmpty,
      );
    });

    test('只认枚举名字，大小写与分隔符不同都不算开启', () {
      expect(experimentalFeaturesFromStorage(const ['telemetry', 'cliChat']), {
        ExperimentalFeature.cliChat,
      });
      expect(experimentalFeaturesFromStorage(const ['telemetry', 'nas']), {
        ExperimentalFeature.nas,
      });
      expect(
        experimentalFeaturesFromStorage(const ['CliChat']),
        isEmpty,
        reason: '名字必须精确匹配，持久化用的是 enum.name',
      );
    });

    test('返回不可变集合，外部无法绕过 notifier 改写', () {
      final parsed = experimentalFeaturesFromStorage(const ['cliChat']);
      expect(
        () => parsed.add(ExperimentalFeature.cliChat),
        throwsUnsupportedError,
      );
    });
  });

  group('默认关闭', () {
    test('空存储时 CLI 聊天不可用，实验特性集合为空', () async {
      final container = await _container();
      addTearDown(container.dispose);

      final settings = container.read(settingsProvider);
      expect(settings.enabledExperimentalFeatures, isEmpty);
      expect(settings.isSectionEnabled(AppSection.cliChat), isFalse);
      expect(settings.availableSections, isNot(contains(AppSection.cliChat)));
      expect(settings.isSectionEnabled(AppSection.nas), isFalse);
      expect(settings.availableSections, isNot(contains(AppSection.nas)));
    });

    test('只开启 CLI 不会顺带开启 NAS', () async {
      final container = await _container(
        seed: {
          _experimentalKey: <String>['cliChat'],
        },
      );
      addTearDown(container.dispose);

      final settings = container.read(settingsProvider);
      expect(settings.isSectionEnabled(AppSection.cliChat), isTrue);
      expect(settings.isSectionEnabled(AppSection.nas), isFalse);
      expect(settings.availableSections, contains(AppSection.cliChat));
      expect(settings.availableSections, isNot(contains(AppSection.nas)));
    });

    test('未知特性名字存在时 CLI 仍然关闭', () async {
      final container = await _container(
        seed: {
          _experimentalKey: <String>['telemetry', 'timeTravel'],
        },
      );
      addTearDown(container.dispose);

      expect(
        container.read(settingsProvider).isSectionEnabled(AppSection.cliChat),
        isFalse,
      );
    });

    test('显式空列表同样保持关闭', () async {
      final container = await _container(seed: {_experimentalKey: <String>[]});
      addTearDown(container.dispose);

      expect(
        container.read(settingsProvider).enabledExperimentalFeatures,
        isEmpty,
      );
    });
  });

  group('持久化：开启、关闭、重启', () {
    test('开启先落盘再更新状态，跨重启读回', () async {
      final first = await _container();
      await first
          .read(settingsProvider.notifier)
          .setExperimentalFeature(ExperimentalFeature.cliChat, true);
      expect(
        first.read(settingsProvider).isSectionEnabled(AppSection.cliChat),
        isTrue,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(_experimentalKey), ['cliChat']);
      first.dispose();

      // 模拟重启：新容器读同一份存储。
      final second = await _container();
      addTearDown(second.dispose);
      expect(
        second.read(settingsProvider).isSectionEnabled(AppSection.cliChat),
        isTrue,
        reason: '重启后必须仍是开启，否则用户会以为勾选丢失',
      );
    });

    test('关闭后落盘为空并跨重启保持关闭', () async {
      final first = await _container(
        seed: {
          _experimentalKey: <String>['cliChat'],
        },
      );
      await first
          .read(settingsProvider.notifier)
          .setExperimentalFeature(ExperimentalFeature.cliChat, false);

      expect(
        first.read(settingsProvider).isSectionEnabled(AppSection.cliChat),
        isFalse,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(_experimentalKey), isEmpty);
      first.dispose();

      final second = await _container();
      addTearDown(second.dispose);
      expect(
        second.read(settingsProvider).isSectionEnabled(AppSection.cliChat),
        isFalse,
      );
    });

    test('重复开启幂等，不产生重复名字', () async {
      final container = await _container();
      addTearDown(container.dispose);
      final notifier = container.read(settingsProvider.notifier);

      await notifier.setExperimentalFeature(ExperimentalFeature.cliChat, true);
      await notifier.setExperimentalFeature(ExperimentalFeature.cliChat, true);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(_experimentalKey), ['cliChat']);
    });

    test('NAS 独立开启落盘并跨重启读回，reset 后关闭', () async {
      final first = await _container();
      await first
          .read(settingsProvider.notifier)
          .setExperimentalFeature(ExperimentalFeature.nas, true);
      expect(
        first.read(settingsProvider).isSectionEnabled(AppSection.nas),
        isTrue,
      );
      expect(
        first.read(settingsProvider).isSectionEnabled(AppSection.cliChat),
        isFalse,
        reason: 'NAS 开启不能带动 CLI 开启',
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(_experimentalKey), ['nas']);
      first.dispose();

      final second = await _container();
      addTearDown(second.dispose);
      expect(
        second.read(settingsProvider).isSectionEnabled(AppSection.nas),
        isTrue,
        reason: '重启后 NAS 仍然开启',
      );

      await second.read(settingsProvider.notifier).resetDefaults();
      expect(
        second.read(settingsProvider).enabledExperimentalFeatures,
        isEmpty,
      );
      expect(
        second.read(settingsProvider).isSectionEnabled(AppSection.nas),
        isFalse,
      );
      final stored = await SharedPreferences.getInstance();
      expect(stored.getStringList(_experimentalKey), isEmpty);
    });

    test('resetDefaults 关闭实验特性并落盘空列表', () async {
      final container = await _container(
        seed: {
          _experimentalKey: <String>['cliChat'],
          _bottomNavigationKey: <String>['files'],
        },
      );
      addTearDown(container.dispose);

      await container.read(settingsProvider.notifier).resetDefaults();

      expect(
        container.read(settingsProvider).enabledExperimentalFeatures,
        isEmpty,
      );
      expect(
        container.read(settingsProvider).isSectionEnabled(AppSection.cliChat),
        isFalse,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(_experimentalKey), isEmpty);
    });
  });

  group('落盘失败不得报告已开启', () {
    test('写入抛错时状态保持关闭，存储也没有被写成开启', () async {
      final container = await _failingContainer();
      addTearDown(container.dispose);
      final notifier = container.read(settingsProvider.notifier);

      await expectLater(
        notifier.setExperimentalFeature(ExperimentalFeature.cliChat, true),
        throwsStateError,
      );

      expect(
        container.read(settingsProvider).enabledExperimentalFeatures,
        isEmpty,
        reason: '先落盘后改状态：写失败就不能出现“已开启”',
      );
      expect(
        container.read(settingsProvider).isSectionEnabled(AppSection.cliChat),
        isFalse,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(_experimentalKey), isNull);
    });

    test('写入抛错时 NAS 保持关闭，存储没有被写成开启', () async {
      final container = await _failingContainer();
      addTearDown(container.dispose);
      final notifier = container.read(settingsProvider.notifier);

      await expectLater(
        notifier.setExperimentalFeature(ExperimentalFeature.nas, true),
        throwsStateError,
      );

      expect(
        container.read(settingsProvider).enabledExperimentalFeatures,
        isEmpty,
      );
      expect(
        container.read(settingsProvider).isSectionEnabled(AppSection.nas),
        isFalse,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(_experimentalKey), isNull);
    });

    test('已经开启后关闭失败，旧值仍然保持开启而不是半吊子状态', () async {
      SharedPreferences.setMockInitialValues({
        _experimentalKey: <String>['cliChat'],
      });
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(_FailingStorage(prefs)),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(settingsProvider.notifier);
      expect(
        container.read(settingsProvider).isSectionEnabled(AppSection.cliChat),
        isTrue,
      );

      await expectLater(
        notifier.setExperimentalFeature(ExperimentalFeature.cliChat, false),
        throwsStateError,
      );

      expect(
        container.read(settingsProvider).isSectionEnabled(AppSection.cliChat),
        isTrue,
        reason: '内存与磁盘必须一致，不能内存已关而磁盘仍是开',
      );
      final stored = await SharedPreferences.getInstance();
      expect(stored.getStringList(_experimentalKey), ['cliChat']);
    });
  });

  group('导航与启动页可见性：原始槽位必须保留', () {
    Future<ProviderContainer> configured() => _container(
      seed: {
        _experimentalKey: <String>['nas'],
        _bottomNavigationKey: <String>['dashboard', 'cliChat', 'files', 'nas'],
        _quickSectionsKey: <String>['aiChat', 'cliChat', 'system'],
        _startupKey: 'cliChat',
      },
    );

    test('关闭时可见列表过滤 CLI，但原始列表原样保留', () async {
      final container = await configured();
      addTearDown(container.dispose);
      final settings = container.read(settingsProvider);

      expect(settings.bottomNavigationSections, [
        AppSection.dashboard,
        AppSection.cliChat,
        AppSection.files,
        AppSection.nas,
      ]);
      expect(settings.dashboardQuickSections, [
        AppSection.aiChat,
        AppSection.cliChat,
        AppSection.system,
      ]);
      expect(settings.visibleBottomNavigationSections, [
        AppSection.dashboard,
        AppSection.files,
        AppSection.nas,
      ]);
      expect(settings.visibleDashboardQuickSections, [
        AppSection.aiChat,
        AppSection.system,
      ]);
    });

    test('CLI 启动页在关闭时回退仪表盘，开启后恢复为 CLI', () async {
      final container = await configured();
      addTearDown(container.dispose);
      expect(
        container.read(settingsProvider).startupSection,
        AppSection.cliChat,
      );
      expect(
        container.read(settingsProvider).effectiveStartupSection,
        AppSection.dashboard,
        reason: '启动页不可用时必须回退，不能停在隐藏页',
      );

      await container
          .read(settingsProvider.notifier)
          .setExperimentalFeature(ExperimentalFeature.cliChat, true);

      expect(
        container.read(settingsProvider).effectiveStartupSection,
        AppSection.cliChat,
      );
      expect(container.read(settingsProvider).visibleBottomNavigationSections, [
        AppSection.dashboard,
        AppSection.cliChat,
        AppSection.files,
        AppSection.nas,
      ]);
      expect(container.read(settingsProvider).visibleDashboardQuickSections, [
        AppSection.aiChat,
        AppSection.cliChat,
        AppSection.system,
      ]);
    });

    test('隐藏条目不改变稳定下标，NAS 仍是 index9', () async {
      final container = await configured();
      addTearDown(container.dispose);

      expect(AppSection.values[AppSection.cliChat.index], AppSection.cliChat);
      expect(AppSection.values[8], AppSection.cliChat);
      expect(AppSection.values[9], AppSection.nas);
      final hidden = container.read(settingsProvider).availableSections;
      expect(hidden, isNot(contains(AppSection.cliChat)));
      expect(hidden, contains(AppSection.nas));

      await container
          .read(settingsProvider.notifier)
          .setExperimentalFeature(ExperimentalFeature.cliChat, true);
      expect(
        container.read(settingsProvider).availableSections,
        AppSection.values,
        reason: '开启后候选列表应等于全部枚举，顺序稳定',
      );
    });

    test('重排可见子集时隐藏条目保留原槽位，重新开启恢复原顺序', () async {
      final container = await configured();
      addTearDown(container.dispose);
      final notifier = container.read(settingsProvider.notifier);

      await notifier.setVisibleBottomNavigationSections(const [
        AppSection.nas,
        AppSection.files,
        AppSection.dashboard,
      ]);

      final hiddenState = container.read(settingsProvider);
      expect(hiddenState.visibleBottomNavigationSections, [
        AppSection.nas,
        AppSection.files,
        AppSection.dashboard,
      ]);
      expect(
        hiddenState.bottomNavigationSections[1],
        AppSection.cliChat,
        reason: '隐藏的 CLI 条目必须留在原来的槽位，不能被重排挤掉或删除',
      );
      expect(hiddenState.bottomNavigationSections, [
        AppSection.nas,
        AppSection.cliChat,
        AppSection.files,
        AppSection.dashboard,
      ]);

      await notifier.setExperimentalFeature(ExperimentalFeature.cliChat, true);
      expect(container.read(settingsProvider).visibleBottomNavigationSections, [
        AppSection.nas,
        AppSection.cliChat,
        AppSection.files,
        AppSection.dashboard,
      ]);
    });

    test('显式清空底栏只清可见项，隐藏的 CLI 条目仍然留着', () async {
      final container = await configured();
      addTearDown(container.dispose);
      final notifier = container.read(settingsProvider.notifier);

      await notifier.setVisibleBottomNavigationSections(const []);

      final state = container.read(settingsProvider);
      expect(state.visibleBottomNavigationSections, isEmpty);
      expect(state.bottomNavigationSections, [AppSection.cliChat]);

      await notifier.setExperimentalFeature(ExperimentalFeature.cliChat, true);
      expect(
        container.read(settingsProvider).visibleBottomNavigationSections,
        [AppSection.cliChat],
        reason: '重新开启后原有 CLI 槽位按原顺序回来',
      );
    });

    test('快捷入口重排同样保留隐藏条目', () async {
      final container = await configured();
      addTearDown(container.dispose);
      final notifier = container.read(settingsProvider.notifier);

      await notifier.setVisibleDashboardQuickSections(const [
        AppSection.system,
        AppSection.aiChat,
      ]);

      expect(container.read(settingsProvider).dashboardQuickSections, [
        AppSection.system,
        AppSection.cliChat,
        AppSection.aiChat,
      ]);
      expect(container.read(settingsProvider).visibleDashboardQuickSections, [
        AppSection.system,
        AppSection.aiChat,
      ]);
    });

    test('可见子集里混入隐藏的 CLI 会被忽略，不会顶掉可见项', () async {
      final container = await configured();
      addTearDown(container.dispose);
      final notifier = container.read(settingsProvider.notifier);

      await notifier.setVisibleDashboardQuickSections(const [
        AppSection.cliChat,
        AppSection.system,
        AppSection.aiChat,
      ]);

      final state = container.read(settingsProvider);
      expect(state.visibleDashboardQuickSections, [
        AppSection.system,
        AppSection.aiChat,
      ]);
      expect(state.dashboardQuickSections, [
        AppSection.system,
        AppSection.cliChat,
        AppSection.aiChat,
      ]);
    });

    test('NAS 启动页在关闭时回退仪表盘，开启后恢复为 NAS', () async {
      final container = await _container(
        seed: {
          _startupKey: 'nas',
          _bottomNavigationKey: <String>['dashboard', 'nas'],
        },
      );
      addTearDown(container.dispose);

      expect(container.read(settingsProvider).startupSection, AppSection.nas);
      expect(
        container.read(settingsProvider).effectiveStartupSection,
        AppSection.dashboard,
        reason: 'NAS 未开启时启动页必须回退，但原始配置保留',
      );
      expect(container.read(settingsProvider).visibleBottomNavigationSections, [
        AppSection.dashboard,
      ]);

      await container
          .read(settingsProvider.notifier)
          .setExperimentalFeature(ExperimentalFeature.nas, true);

      expect(
        container.read(settingsProvider).effectiveStartupSection,
        AppSection.nas,
      );
      expect(
        container.read(settingsProvider).visibleBottomNavigationSections,
        [AppSection.dashboard, AppSection.nas],
        reason: '开启后原有 NAS 槽位按原顺序恢复',
      );
    });

    test('CLI 与 NAS 都隐藏时可见列表过滤两者，原始槽位各自保留并分别恢复', () async {
      final container = await _container(
        seed: {
          _bottomNavigationKey: <String>[
            'dashboard',
            'cliChat',
            'files',
            'nas',
          ],
          _quickSectionsKey: <String>['aiChat', 'cliChat', 'system', 'nas'],
        },
      );
      addTearDown(container.dispose);
      final notifier = container.read(settingsProvider.notifier);

      expect(container.read(settingsProvider).visibleBottomNavigationSections, [
        AppSection.dashboard,
        AppSection.files,
      ]);
      expect(container.read(settingsProvider).visibleDashboardQuickSections, [
        AppSection.aiChat,
        AppSection.system,
      ]);
      expect(container.read(settingsProvider).bottomNavigationSections, [
        AppSection.dashboard,
        AppSection.cliChat,
        AppSection.files,
        AppSection.nas,
      ]);
      expect(container.read(settingsProvider).dashboardQuickSections, [
        AppSection.aiChat,
        AppSection.cliChat,
        AppSection.system,
        AppSection.nas,
      ]);

      await notifier.setExperimentalFeature(ExperimentalFeature.nas, true);
      expect(container.read(settingsProvider).visibleBottomNavigationSections, [
        AppSection.dashboard,
        AppSection.files,
        AppSection.nas,
      ]);
      expect(container.read(settingsProvider).visibleDashboardQuickSections, [
        AppSection.aiChat,
        AppSection.system,
        AppSection.nas,
      ]);

      await notifier.setExperimentalFeature(ExperimentalFeature.cliChat, true);
      expect(container.read(settingsProvider).visibleBottomNavigationSections, [
        AppSection.dashboard,
        AppSection.cliChat,
        AppSection.files,
        AppSection.nas,
      ]);
      expect(container.read(settingsProvider).visibleDashboardQuickSections, [
        AppSection.aiChat,
        AppSection.cliChat,
        AppSection.system,
        AppSection.nas,
      ]);

      await notifier.setExperimentalFeature(ExperimentalFeature.nas, false);
      expect(container.read(settingsProvider).visibleBottomNavigationSections, [
        AppSection.dashboard,
        AppSection.cliChat,
        AppSection.files,
      ]);
      expect(container.read(settingsProvider).bottomNavigationSections, [
        AppSection.dashboard,
        AppSection.cliChat,
        AppSection.files,
        AppSection.nas,
      ]);
    });
  });
}
