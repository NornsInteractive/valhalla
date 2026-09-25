import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../constants/layout_breakpoints.dart';

extension ContextExtensions on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
  ThemeData get theme => Theme.of(this);
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  TextTheme get textTheme => Theme.of(this).textTheme;

  /// 当前窗口是否处于扩展桌面宽度（> 1024px）。
  ///
  /// 与 Shell 扩展桌面分支统一基于 [LayoutBreakpoints.expandedMin]，
  /// 彻底修掉 900~1024px 区间内 Shell 判定为中屏而内部页面判定为桌面的冲突。
  bool get isDesktop =>
      MediaQuery.sizeOf(this).width > LayoutBreakpoints.expandedMin;

  /// 当前是否为中屏及以上宽度（>= 600px），对应 NavigationRail 模式。
  bool get isMediumOrWider =>
      MediaQuery.sizeOf(this).width >= LayoutBreakpoints.compactMax;

  /// 当前是否为紧凑型小屏宽度（< 600px），对应移动端底部导航与抽屉模式。
  bool get isCompact =>
      MediaQuery.sizeOf(this).width < LayoutBreakpoints.compactMax;
}
