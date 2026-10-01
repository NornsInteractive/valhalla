import 'package:flutter_riverpod/flutter_riverpod.dart';

final appVisibilityProvider = NotifierProvider<AppVisibilityNotifier, bool>(
  AppVisibilityNotifier.new,
);

class AppVisibilityNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void setForeground(bool value) {
    if (state != value) state = value;
  }
}
