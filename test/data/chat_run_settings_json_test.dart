import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/data/models/chat_run_settings.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';

/// ChatRunSettings 的旧/新持久化格式契约。
///
/// 旧 JSON 没有 `customModel` 键，必须解析成 false（普通目录选择）；
/// 新格式把它写成显式的布尔值并完整往返。没有破坏性迁移。
void main() {
  const defaultsKey = 'valhalla_chat_run_defaults_v1';

  group('ChatRunSettings 旧 JSON', () {
    test('没有 customModel 键时解析为 false，并保留其余字段', () {
      final parsed = ChatRunSettings.fromJson(const {
        'modelId': 'legacy-model',
        'reasoningId': 'high',
        'permissionPolicy': 'autoAllowAll',
        'modeId': 'code',
        'configValues': {'a': 'b'},
      });

      expect(parsed.customModel, isFalse, reason: '旧格式必须等同于普通目录选择');
      expect(parsed.modelId, 'legacy-model');
      expect(parsed.reasoningId, 'high');
      expect(parsed.permissionPolicy, OperationPermissionPolicy.autoAllowAll);
      expect(parsed.modeId, 'code');
      expect(parsed.configValues, {'a': 'b'});
    });

    test('空对象返回全默认值', () {
      final parsed = ChatRunSettings.fromJson(const {});

      expect(parsed.customModel, isFalse);
      expect(parsed.modelId, isNull);
      expect(parsed.reasoningId, isNull);
      expect(parsed.modeId, isNull);
      expect(parsed.permissionPolicy, OperationPermissionPolicy.askEveryTime);
      expect(parsed.configValues, isEmpty);
    });

    test('非布尔 customModel 不得被当成 true', () {
      const alternatives = <Object>['true', 'TRUE', 1, 1.0, <String>[]];

      for (final raw in alternatives) {
        final parsed = ChatRunSettings.fromJson({'customModel': raw});
        expect(
          parsed.customModel,
          isFalse,
          reason: '只有字面 true 才代表手动态，收到的是 $raw',
        );
      }
    });

    test('默认构造的 customModel 为 false', () {
      expect(const ChatRunSettings().customModel, isFalse);
      expect(const ChatRunSettings(modelId: 'listed').customModel, isFalse);
    });
  });

  group('ChatRunSettings 新 JSON', () {
    test('手动态完整往返', () {
      const settings = ChatRunSettings(
        modelId: 'my-manual-model',
        customModel: true,
        reasoningId: 'high',
        permissionPolicy: OperationPermissionPolicy.autoAllowSafe,
        modeId: 'code',
        configValues: {'theme': 'dark'},
      );

      final json = settings.toJson();
      expect(json['customModel'], isTrue, reason: '新格式必须显式写出手动态');
      expect(json.keys, contains('modelId'));

      final restored = ChatRunSettings.fromJson(json);
      expect(restored.modelId, 'my-manual-model');
      expect(restored.customModel, isTrue);
      expect(restored.reasoningId, 'high');
      expect(
        restored.permissionPolicy,
        OperationPermissionPolicy.autoAllowSafe,
      );
      expect(restored.modeId, 'code');
      expect(restored.configValues, {'theme': 'dark'});
      expect(restored.toJson(), json, reason: '第二次序列化必须逐字段相同');
    });

    test('普通目录选择的 JSON 也显式写出 false', () {
      const settings = ChatRunSettings(modelId: 'gpt-5-codex');

      final json = settings.toJson();
      expect(json.keys, contains('customModel'));
      expect(json['customModel'], isFalse);
      expect(ChatRunSettings.fromJson(json).customModel, isFalse);
    });

    test('copyWith 保留手动态，clearModel 一并清除', () {
      const base = ChatRunSettings(modelId: 'manual', customModel: true);

      expect(base.copyWith(reasoningId: 'high').customModel, isTrue);
      expect(base.copyWith(modelId: 'other').customModel, isTrue);
      expect(base.copyWith(modelId: 'other').modelId, 'other');

      final off = base.copyWith(customModel: false);
      expect(off.customModel, isFalse);
      expect(off.modelId, 'manual', reason: '关掉手动态仍保留已选 ID');

      final cleared = base.copyWith(clearModel: true);
      expect(cleared.modelId, isNull);
      expect(cleared.customModel, isFalse, reason: '清空模型必须同时清掉手动态');

      expect(base.copyWith().customModel, isTrue);
      expect(base.copyWith().modelId, 'manual');
    });
  });

  group('草稿持久化', () {
    test('saveChatRunDefault/getChatRunDefault 往返手动态', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = LocalStorageService(
        await SharedPreferences.getInstance(),
      );

      await storage.saveChatRunDefault(
        'srv-1',
        'builtin-codex',
        const ChatRunSettings(modelId: 'manual-1', customModel: true),
      );

      final restored = storage.getChatRunDefault('srv-1', 'builtin-codex');
      expect(restored.modelId, 'manual-1');
      expect(restored.customModel, isTrue);
      expect(
        storage.getChatRunDefault('srv-1', 'other-agent').customModel,
        isFalse,
        reason: '没有记录时回落到默认，而不是共享别人的设置',
      );
    });

    test('旧存储条目没有 customModel 键，读出来是 false', () async {
      SharedPreferences.setMockInitialValues({
        defaultsKey:
            '{"srv-1::legacy-agent":{"modelId":"old-model",'
            '"reasoningId":"high","permissionPolicy":"askEveryTime"}}',
      });
      final storage = LocalStorageService(
        await SharedPreferences.getInstance(),
      );

      final restored = storage.getChatRunDefault('srv-1', 'legacy-agent');
      expect(restored.modelId, 'old-model');
      expect(restored.customModel, isFalse);
      expect(restored.reasoningId, 'high');
    });

    test('新写入不破坏同一存储里的其他条目', () async {
      SharedPreferences.setMockInitialValues({
        defaultsKey: '{"srv-1::legacy-agent":{"modelId":"old-model"}}',
      });
      final storage = LocalStorageService(
        await SharedPreferences.getInstance(),
      );

      await storage.saveChatRunDefault(
        'srv-1',
        'builtin-codex',
        const ChatRunSettings(modelId: 'manual-1', customModel: true),
      );

      expect(
        storage.getChatRunDefault('srv-1', 'legacy-agent').modelId,
        'old-model',
        reason: '新增手动态不得清掉已有草稿',
      );
      final written = storage.getChatRunDefault('srv-1', 'builtin-codex');
      expect(written.modelId, 'manual-1');
      expect(written.customModel, isTrue);
    });

    test('saveCliRunSettings 同步默认草稿，手动态一并保留', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = LocalStorageService(
        await SharedPreferences.getInstance(),
      );

      await storage.saveCliRunSettings(
        'srv-1',
        'builtin-codex',
        null,
        const ChatRunSettings(modelId: 'manual-2', customModel: true),
      );

      expect(
        storage.getCliRunSettings('srv-1', 'builtin-codex', null).customModel,
        isTrue,
      );
      expect(
        storage.getChatRunDefault('srv-1', 'builtin-codex').customModel,
        isTrue,
      );
      expect(
        storage.getChatRunDefault('srv-1', 'builtin-codex').modelId,
        'manual-2',
      );
    });
  });
}
