import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/design/tokens.dart';

enum AppThemeMode { system, light, dark, amoled }

enum AppAccentColor {
  cyberEmerald(Color(0xFF10B981)),
  techBlue(Color(0xFF2563EB)),
  electricViolet(Color(0xFF8B5CF6)),
  crimsonRed(Color(0xFFEF4444)),
  amberOrange(Color(0xFFF59E0B));

  final Color color;
  const AppAccentColor(this.color);
}

/// Valhalla 设计系统 — "Norse Steel"。
///
/// 钢灰色中性表面 + 单一种子色强调。视觉层级靠表面明度阶梯与 1px 冷描边,
/// 强调色只出现在行动点与选中态上。圆角体系见 [VRadius]。
abstract final class AppTheme {
  /// 暗色 (含 AMOLED) 表面阶梯。
  static const _darkScaffold = Color(0xFF0A0C10);
  static const _darkSurface = Color(0xFF0E1116);
  static const _darkContainerLow = Color(0xFF12151B);
  static const _darkContainer = Color(0xFF161A21);
  static const _darkContainerHigh = Color(0xFF1B2027);
  static const _darkContainerHighest = Color(0xFF21262E);
  static const _darkOutlineVariant = Color(0xFF252B34);
  static const _darkOutline = Color(0xFF39414C);
  static const _darkOnSurface = Color(0xFFE8EAEE);
  static const _darkOnSurfaceVariant = Color(0xFF9BA3AE);

  /// AMOLED: 纯黑底 + 近黑卡片。
  static const _amoledScaffold = Color(0xFF000000);
  static const _amoledSurface = Color(0xFF000000);
  static const _amoledContainerLow = Color(0xFF070708);
  static const _amoledContainer = Color(0xFF0B0B0D);
  static const _amoledContainerHigh = Color(0xFF111114);
  static const _amoledContainerHighest = Color(0xFF17171A);
  static const _amoledOutlineVariant = Color(0xFF1E1E22);

  /// 亮色表面。
  static const _lightScaffold = Color(0xFFF5F6F8);
  static const _lightSurface = Color(0xFFFFFFFF);
  static const _lightContainerLow = Color(0xFFF7F8FA);
  static const _lightContainer = Color(0xFFEFF1F4);
  static const _lightContainerHigh = Color(0xFFE8EBEF);
  static const _lightContainerHighest = Color(0xFFE0E4E9);
  static const _lightOutlineVariant = Color(0xFFE2E6EC);
  static const _lightOutline = Color(0xFFC4CAD3);
  static const _lightOnSurface = Color(0xFF171A1F);
  static const _lightOnSurfaceVariant = Color(0xFF5C6572);

  static ThemeData buildTheme({
    required Brightness brightness,
    required Color seedColor,
    bool isAmoled = false,
  }) {
    final dark = brightness == Brightness.dark;
    final scaffold = isAmoled ? _amoledScaffold : (dark ? _darkScaffold : _lightScaffold);
    final surface = isAmoled ? _amoledSurface : (dark ? _darkSurface : _lightSurface);
    final containerLow = isAmoled ? _amoledContainerLow : (dark ? _darkContainerLow : _lightContainerLow);
    final container = isAmoled ? _amoledContainer : (dark ? _darkContainer : _lightContainer);
    final containerHigh = isAmoled ? _amoledContainerHigh : (dark ? _darkContainerHigh : _lightContainerHigh);
    final containerHighest = isAmoled
        ? _amoledContainerHighest
        : (dark ? _darkContainerHighest : _lightContainerHighest);
    final outlineVariant = isAmoled ? _amoledOutlineVariant : (dark ? _darkOutlineVariant : _lightOutlineVariant);
    final outline = dark ? _darkOutline : _lightOutline;
    final onSurface = dark ? _darkOnSurface : _lightOnSurface;
    final onSurfaceVariant = dark ? _darkOnSurfaceVariant : _lightOnSurfaceVariant;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    ).copyWith(
      surface: surface,
      surfaceContainerLowest: scaffold,
      surfaceContainerLow: containerLow,
      surfaceContainer: container,
      surfaceContainerHigh: containerHigh,
      surfaceContainerHighest: containerHighest,
      surfaceDim: scaffold,
      onSurface: onSurface,
      onSurfaceVariant: onSurfaceVariant,
      outline: outline,
      outlineVariant: outlineVariant,
      scrim: dark ? const Color(0xFF05070A) : const Color(0xFF14161A),
    );

    final textTheme = _buildTextTheme(brightness: brightness, onSurface: onSurface, onSurfaceVariant: onSurfaceVariant);
    final side = BorderSide(color: outlineVariant, width: 1);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffold,
      fontFamily: 'Inter',
      splashFactory: InkRipple.splashFactory,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      textTheme: textTheme,
      iconTheme: IconThemeData(color: onSurfaceVariant, size: 22),
      primaryIconTheme: IconThemeData(color: colorScheme.onPrimary),
      dividerTheme: DividerThemeData(
        color: outlineVariant.withValues(alpha: 0.7),
        thickness: 1,
        space: 1,
      ),

      // -- App bar ---------------------------------------------------------
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: scaffold,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge,
        systemOverlayStyle: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        iconTheme: IconThemeData(color: onSurface),
      ),

      // -- 卡片 / 面板 ------------------------------------------------------
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VRadius.card), side: side),
        color: container,
        surfaceTintColor: Colors.transparent,
      ),

      // -- 对话框 / 弹层 ----------------------------------------------------
      dialogTheme: DialogThemeData(
        backgroundColor: dark ? containerHigh : _lightSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VRadius.dialog), side: side),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
        barrierColor: Colors.black.withValues(alpha: dark ? 0.55 : 0.35),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: dark ? containerHigh : _lightSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalBarrierColor: Colors.black.withValues(alpha: dark ? 0.55 : 0.35),
        showDragHandle: true,
        dragHandleColor: outline,
        dragHandleSize: const Size(36, 4),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(VRadius.sheet)),
        ),
      ),

      // -- 按钮 -------------------------------------------------------------
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VRadius.button)),
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: outline, width: 1.2),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VRadius.button)),
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VRadius.button)),
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          textStyle: textTheme.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VRadius.button)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VRadius.card)),
      ),

      // -- 输入 -------------------------------------------------------------
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? containerLow : _lightContainerLow,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        hintStyle: textTheme.bodyMedium?.copyWith(color: onSurfaceVariant.withValues(alpha: 0.65)),
        labelStyle: textTheme.bodyMedium?.copyWith(color: onSurfaceVariant),
        helperStyle: textTheme.bodySmall,
        errorStyle: textTheme.bodySmall?.copyWith(color: colorScheme.error),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VRadius.input),
          borderSide: BorderSide(color: outlineVariant, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VRadius.input),
          borderSide: BorderSide(color: outlineVariant, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VRadius.input),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VRadius.input),
          borderSide: BorderSide(color: colorScheme.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VRadius.input),
          borderSide: BorderSide(color: colorScheme.error, width: 1.6),
        ),
      ),

      // -- 列表 / 芯片 / 菜单 ------------------------------------------------
      listTileTheme: ListTileThemeData(
        iconColor: onSurfaceVariant,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VRadius.input)),
        contentPadding: const EdgeInsets.symmetric(horizontal: VSpace.lg),
        titleTextStyle: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
        subtitleTextStyle: textTheme.bodySmall,
        dense: false,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: containerLow,
        side: BorderSide(color: outlineVariant, width: 1),
        shape: const StadiumBorder(),
        labelStyle: textTheme.labelMedium?.copyWith(color: onSurfaceVariant),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: dark ? containerHigh : _lightSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: dark ? 0.4 : 0.14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VRadius.card), side: side),
        textStyle: textTheme.bodyMedium,
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(dark ? containerHigh : _lightSurface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(8),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(VRadius.card), side: side),
          ),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(dark ? containerHigh : _lightSurface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(8),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(VRadius.card), side: side),
          ),
        ),
      ),

      // -- 导航 -------------------------------------------------------------
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scaffold,
        indicatorColor: colorScheme.primaryContainer,
        elevation: 0,
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: colorScheme.onPrimaryContainer);
          }
          return IconThemeData(color: onSurfaceVariant);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final color = states.contains(WidgetState.selected)
              ? colorScheme.onSurface
              : onSurfaceVariant;
          return textTheme.labelSmall!.copyWith(color: color, fontWeight: FontWeight.w600);
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scaffold,
        indicatorColor: colorScheme.primaryContainer,
        elevation: 0,
        selectedIconTheme: IconThemeData(color: colorScheme.onPrimaryContainer),
        unselectedIconTheme: IconThemeData(color: onSurfaceVariant),
        selectedLabelTextStyle: textTheme.labelSmall?.copyWith(
          color: onSurface,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: textTheme.labelSmall?.copyWith(color: onSurfaceVariant),
        labelType: NavigationRailLabelType.all,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: colorScheme.primary,
        unselectedLabelColor: onSurfaceVariant,
        labelStyle: textTheme.labelLarge,
        unselectedLabelStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500),
        indicatorColor: colorScheme.primary,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.label,
      ),

      // -- 指示器 / 反馈 ------------------------------------------------------
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        linearTrackColor: containerHighest,
        circularTrackColor: containerHighest,
        refreshBackgroundColor: containerHigh,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return outlineVariant;
          return _lightSurface;
        }),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark ? containerHigh : const Color(0xFF23272E),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: dark ? onSurface : _lightSurface,
        ),
        actionTextColor: colorScheme.primary,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: dark ? containerHigh : const Color(0xFF23272E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: outlineVariant, width: 1),
        ),
        textStyle: textTheme.labelSmall?.copyWith(
          color: dark ? onSurface : _lightSurface,
          fontSize: 11.5,
        ),
        preferBelow: false,
        waitDuration: const Duration(milliseconds: 450),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thickness: WidgetStatePropertyAll(6.0),
        radius: const Radius.circular(3),
        thumbColor: WidgetStatePropertyAll(outline.withValues(alpha: 0.5)),
      ),
    );
  }

  static TextTheme _buildTextTheme({
    required Brightness brightness,
    required Color onSurface,
    required Color onSurfaceVariant,
  }) {
    // Inter 被注册为默认 fontFamily; 这里显式声明以覆盖 M3 默认并统一字距。
    TextStyle base(
      double size, {
      required double height,
      required FontWeight weight,
      double letterSpacing = 0,
      Color? color,
    }) => TextStyle(
      fontFamily: 'Inter',
      fontSize: size,
      height: height,
      fontWeight: weight,
      letterSpacing: letterSpacing,
      color: color,
    );

    return TextTheme(
      displaySmall: base(32, height: 1.15, weight: FontWeight.w700, letterSpacing: -0.8, color: onSurface),
      headlineMedium: base(26, height: 1.2, weight: FontWeight.w700, letterSpacing: -0.6, color: onSurface),
      headlineSmall: base(23, height: 1.22, weight: FontWeight.w700, letterSpacing: -0.5, color: onSurface),
      titleLarge: base(19, height: 1.25, weight: FontWeight.w700, letterSpacing: -0.4, color: onSurface),
      titleMedium: base(16, height: 1.3, weight: FontWeight.w600, letterSpacing: -0.2, color: onSurface),
      titleSmall: base(14, height: 1.35, weight: FontWeight.w600, letterSpacing: -0.1, color: onSurface),
      bodyLarge: base(15, height: 1.55, weight: FontWeight.w400, color: onSurface),
      bodyMedium: base(14, height: 1.5, weight: FontWeight.w400, color: onSurface),
      bodySmall: base(12.5, height: 1.45, weight: FontWeight.w400, color: onSurfaceVariant),
      labelLarge: base(14, height: 1.2, weight: FontWeight.w600, color: onSurface),
      labelMedium: base(12, height: 1.2, weight: FontWeight.w600, letterSpacing: 0.2, color: onSurfaceVariant),
      labelSmall: base(11, height: 1.2, weight: FontWeight.w500, letterSpacing: 0.3, color: onSurfaceVariant),
    );
  }
}
