import 'package:valhalla/core/providers/settings_provider.dart';

export 'package:valhalla/core/providers/settings_provider.dart'
    show settingsProvider;

/// Non-persistence feature fixtures still supply the application's settings seam.
/// Storage round trips are exercised separately with real mock preferences.
class InMemoryAppSettings extends SettingsNotifier {
  @override
  SettingsState build() => const SettingsState();

  @override
  Future<void> setRemotePathDisplayMode(
    RemotePathDisplayMode mode, {
    required bool picker,
  }) async {
    state = state.copyWith(
      filePathDisplayMode: picker ? null : mode,
      pickerPathDisplayMode: picker ? mode : null,
    );
  }
}
