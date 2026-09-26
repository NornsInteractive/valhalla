import 'package:flutter/material.dart';

/// Valhalla 设计系统 — "Norse Steel" 设计令牌。
///
/// 本文件是全应用唯一的圆角 / 间距 / 语义色来源。
/// 规则:
///  * 圆角体系全工程统一: 卡片 16、弹窗 20、输入 12、按钮 12、底部弹层顶部 24。
///    严禁在同层级混用其他圆角值。
///  * 语义状态色 (success/info/warning/error) 不随种子色漂移, 亮暗两档微调
///    保证对比度; 其余颜色一律取自 `ColorScheme`, 严禁新硬编码 hex。
///  * 数字 / 主机地址 / 路径 / 指标用 `JetBrains Mono` (`tokens.mono`),
///    UI 文本一律 `Inter` (主题默认字体)。
abstract final class VRadius {
  /// 输入框、小按钮、迷你容器。
  static const double input = 12;

  /// 按钮与小容器。
  static const double button = 12;

  /// 卡片、面板、列表分组容器。
  static const double card = 16;

  /// 大卡片 / 顶部品牌容器。
  static const double cardLarge = 20;

  /// 弹窗。
  static const double dialog = 20;

  /// 底部弹层顶部圆角。
  static const double sheet = 24;

  /// 全圆 (胶囊)。
  static const double pill = 999;
}

/// 间距阶梯 (4 的倍数)。
abstract final class VSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
}

/// 语义状态色。不随种子色变化, 保证"红色=危险、绿色=健康"的肌肉记忆。
abstract final class VColors {
  static const Color successLight = Color(0xFF0E9F6E);
  static const Color successDark = Color(0xFF34D399);
  static const Color infoLight = Color(0xFF0284C7);
  static const Color infoDark = Color(0xFF38BDF8);
  static const Color warningLight = Color(0xFFB45309);
  static const Color warningDark = Color(0xFFFBBF24);
  static const Color dangerLight = Color(0xFFDC2626);
  static const Color dangerDark = Color(0xFFF87171);

  /// 按当前亮度取语义色。
  static Color success(Brightness brightness) =>
      brightness == Brightness.dark ? successDark : successLight;

  static Color info(Brightness brightness) =>
      brightness == Brightness.dark ? infoDark : infoLight;

  static Color warning(Brightness brightness) =>
      brightness == Brightness.dark ? warningDark : warningLight;

  static Color danger(Brightness brightness) =>
      brightness == Brightness.dark ? dangerDark : dangerLight;
}

/// [BuildContext] 语义色语法糖。
extension VColorsExtension on BuildContext {
  Color get vSuccess => VColors.success(Theme.of(this).brightness);

  Color get vInfo => VColors.info(Theme.of(this).brightness);

  Color get vWarning => VColors.warning(Theme.of(this).brightness);

  Color get vDanger => VColors.danger(Theme.of(this).brightness);
}

/// 等宽字体 (数字 / 主机 / 路径 / 指标)。
const String monoFontFamily = 'JetBrains Mono';

/// 等宽文本样式快捷构造。
TextStyle monoTextStyle({
  double fontSize = 12,
  FontWeight fontWeight = FontWeight.w500,
  Color? color,
  double? letterSpacing,
}) => TextStyle(
  fontFamily: monoFontFamily,
  fontSize: fontSize,
  fontWeight: fontWeight,
  color: color,
  letterSpacing: letterSpacing ?? -0.2,
  height: 1.3,
);

/// 卡片悬浮阴影: 冷色调, 随背景色相, 严禁纯黑投影。
List<BoxShadow> vElevation(Brightness brightness, {double strength = 1}) {
  if (brightness == Brightness.dark) {
    return [
      BoxShadow(
        color: const Color(0xFF000000).withValues(alpha: 0.28 * strength),
        blurRadius: 18,
        offset: const Offset(0, 6),
      ),
    ];
  }
  return [
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.06 * strength),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];
}
