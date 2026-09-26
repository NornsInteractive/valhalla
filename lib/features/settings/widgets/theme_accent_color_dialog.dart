import 'package:flutter/material.dart';
import '../../../core/constants/layout_breakpoints.dart';
import '../../../core/design/motion.dart';
import '../../../core/design/tokens.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/settings_provider.dart';

class ThemeAccentColorDialog extends StatefulWidget {
  final SettingsState settings;
  final SettingsNotifier notifier;
  final AppThemeMode? initialMode;

  const ThemeAccentColorDialog({
    super.key,
    required this.settings,
    required this.notifier,
    this.initialMode,
  });

  @override
  State<ThemeAccentColorDialog> createState() => _ThemeAccentColorDialogState();
}

class _ThemeAccentColorDialogState extends State<ThemeAccentColorDialog> {
  late AppThemeMode _activeMode;
  late Color _lightColor;
  late Color _darkColor;
  late Color _amoledColor;
  late TextEditingController _hexController;
  String? _hexError;
  bool _modeInitialized = false;

  @override
  void initState() {
    super.initState();
    _activeMode =
        widget.initialMode ??
        switch (widget.settings.themeMode) {
          AppThemeMode.system => AppThemeMode.light,
          AppThemeMode.light => AppThemeMode.light,
          AppThemeMode.dark => AppThemeMode.dark,
          AppThemeMode.amoled => AppThemeMode.amoled,
        };
    _lightColor = widget.settings.lightAccentColor;
    _darkColor = widget.settings.darkAccentColor;
    _amoledColor = widget.settings.amoledAccentColor;
    _hexController = TextEditingController(text: _colorToHex(_currentColor));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_modeInitialized &&
        widget.initialMode == null &&
        widget.settings.themeMode == AppThemeMode.system) {
      final systemSlot = Theme.of(context).brightness == Brightness.dark
          ? AppThemeMode.dark
          : AppThemeMode.light;
      _activeMode = systemSlot;
      _hexController.text = _colorToHex(_currentColor);
      _modeInitialized = true;
    }
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  Color get _currentColor => switch (_activeMode) {
    AppThemeMode.light => _lightColor,
    AppThemeMode.dark => _darkColor,
    AppThemeMode.amoled => _amoledColor,
    AppThemeMode.system => _lightColor,
  };

  void _updateCurrentColor(Color color, {bool syncText = true}) {
    final opaque = Color(0xFF000000 | (color.toARGB32() & 0xFFFFFF));
    setState(() {
      switch (_activeMode) {
        case AppThemeMode.light:
          _lightColor = opaque;
          break;
        case AppThemeMode.dark:
          _darkColor = opaque;
          break;
        case AppThemeMode.amoled:
          _amoledColor = opaque;
          break;
        case AppThemeMode.system:
          _lightColor = opaque;
          break;
      }
      _hexError = null;
      if (syncText) {
        _hexController.text = _colorToHex(opaque);
      }
    });
  }

  String _colorToHex(Color color) {
    return (color.toARGB32() & 0xFFFFFF)
        .toRadixString(16)
        .padLeft(6, '0')
        .toUpperCase();
  }

  Color? _parseHex(String text) {
    final clean = text.replaceAll('#', '').trim();
    if (RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(clean)) {
      return Color(0xFF000000 | int.parse(clean, radix: 16));
    }
    return null;
  }

  bool get _isHexValid {
    final clean = _hexController.text.replaceAll('#', '').trim();
    return clean.length == 6 && _parseHex(clean) != null && _hexError == null;
  }

  @override
  Widget build(BuildContext context) {
    final hsv = HSVColor.fromColor(_currentColor);
    final isCompact =
        MediaQuery.sizeOf(context).width < LayoutBreakpoints.compactMax;

    if (isCompact) {
      return Dialog.fullscreen(
        child: Scaffold(
          resizeToAvoidBottomInset: true,
          appBar: AppBar(
            title: Row(
              children: [
                Icon(
                  Icons.palette_outlined,
                  color: context.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.l10n.accentColorDialogTitle,
                    style: context.textTheme.titleLarge,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            leading: IconButton(
              icon: const Icon(Icons.close),
              tooltip: context.l10n.cancel,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    child: _buildFormContent(context, hsv, isCompact: true),
                  ),
                ),
                _buildBottomBar(context, isCompact: true),
              ],
            ),
          ),
        ),
      );
    }

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 620,
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(VRadius.dialog),
          child: Scaffold(
            backgroundColor: context.colorScheme.surface,
            resizeToAvoidBottomInset: true,
            appBar: AppBar(
              title: Row(
                children: [
                  Icon(
                    Icons.palette_outlined,
                    color: context.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.l10n.accentColorDialogTitle,
                      style: context.textTheme.titleLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: context.l10n.cancel,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            body: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: _buildFormContent(context, hsv, isCompact: false),
                  ),
                ),
                _buildBottomBar(context, isCompact: false),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormContent(
    BuildContext context,
    HSVColor hsv, {
    required bool isCompact,
  }) {
    final paletteHeight = isCompact ? 200.0 : 180.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Segmented button for mode selection
        Center(
          child: SegmentedButton<AppThemeMode>(
            segments: [
              ButtonSegment(
                value: AppThemeMode.light,
                label: Text(
                  context.l10n.accentColorLightMode,
                  key: const Key('accent_color_tab_light'),
                  style: const TextStyle(fontSize: 11),
                ),
                icon: const Icon(Icons.light_mode, size: 14),
              ),
              ButtonSegment(
                value: AppThemeMode.dark,
                label: Text(
                  context.l10n.accentColorDarkMode,
                  key: const Key('accent_color_tab_dark'),
                  style: const TextStyle(fontSize: 11),
                ),
                icon: const Icon(Icons.dark_mode, size: 14),
              ),
              ButtonSegment(
                value: AppThemeMode.amoled,
                label: Text(
                  context.l10n.accentColorAmoledMode,
                  key: const Key('accent_color_tab_amoled'),
                  style: const TextStyle(fontSize: 11),
                ),
                icon: const Icon(Icons.contrast, size: 14),
              ),
            ],
            selected: {_activeMode},
            onSelectionChanged: (set) {
              if (set.isNotEmpty) {
                setState(() {
                  _activeMode = set.first;
                  _hexController.text = _colorToHex(_currentColor);
                  _hexError = null;
                });
              }
            },
          ),
        ),
        const SizedBox(height: 16),

        // 2. Live preview card
        Text(
          context.l10n.accentColorPreview,
          style: context.textTheme.titleSmall,
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _activeMode == AppThemeMode.amoled
                ? Colors.black
                : (_activeMode == AppThemeMode.dark
                      ? const Color(0xFF1E1E1E)
                      : const Color(0xFFF5F5F5)),
            borderRadius: BorderRadius.circular(VRadius.card),
            border: Border.all(
              color: context.colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _currentColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '#${_colorToHex(_currentColor)}',
                      style: monoTextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _activeMode == AppThemeMode.light
                            ? Colors.black87
                            : Colors.white,
                      ),
                    ),
                    Text(
                      switch (_activeMode) {
                        AppThemeMode.light => context.l10n.accentColorLightMode,
                        AppThemeMode.dark => context.l10n.accentColorDarkMode,
                        AppThemeMode.amoled =>
                          context.l10n.accentColorAmoledMode,
                        AppThemeMode.system => '',
                      },
                      style: TextStyle(
                        fontSize: 10,
                        color: _activeMode == AppThemeMode.light
                            ? Colors.black54
                            : Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _currentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () {},
                child: Text(
                  context.l10n.accentColorSampleButton,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 3. Preset color swatches
        Text(
          context.l10n.accentColorPresets,
          style: context.textTheme.titleSmall,
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: AppAccentColor.values.map((preset) {
            final isCurrent =
                (preset.color.toARGB32() & 0xFFFFFF) ==
                (_currentColor.toARGB32() & 0xFFFFFF);
            return AnimatedScale(
              scale: isCurrent ? 1.1 : 1.0,
              duration: VTiming.base,
              curve: VCurves.springish,
              child: InkWell(
                onTap: () => _updateCurrentColor(preset.color),
                borderRadius: BorderRadius.circular(VRadius.pill),
                child: AnimatedContainer(
                  width: 32,
                  height: 32,
                  duration: VTiming.base,
                  curve: VCurves.emphasized,
                  decoration: BoxDecoration(
                    color: preset.color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isCurrent
                          ? context.colorScheme.onSurface
                          : Colors.transparent,
                      width: 2.5,
                    ),
                    boxShadow: isCurrent
                        ? [
                            BoxShadow(
                              color: preset.color.withValues(alpha: 0.45),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ]
                        : const [],
                  ),
                  child: AnimatedOpacity(
                    duration: VTiming.fast,
                    curve: VCurves.emphasized,
                    opacity: isCurrent ? 1 : 0,
                    child: const Icon(Icons.check, color: Colors.white, size: 16),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        // 4. Large HSV Color Palette (SV 2D Plane)
        Text(
          context.l10n.accentColorHsvPicker,
          style: context.textTheme.titleSmall,
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(VRadius.input),
          child: SizedBox(
            height: paletteHeight,
            width: double.infinity,
            child: Builder(
              builder: (svCtx) {
                return GestureDetector(
                  onPanDown: (details) {
                    final box = svCtx.findRenderObject() as RenderBox?;
                    if (box != null && box.hasSize) {
                      _handleSvPan(
                        details.localPosition,
                        box.size.width,
                        box.size.height,
                        hsv.hue,
                      );
                    }
                  },
                  onPanUpdate: (details) {
                    final box = svCtx.findRenderObject() as RenderBox?;
                    if (box != null && box.hasSize) {
                      _handleSvPan(
                        details.localPosition,
                        box.size.width,
                        box.size.height,
                        hsv.hue,
                      );
                    }
                  },
                  child: CustomPaint(
                    painter: _SvPainter(
                      hue: hsv.hue,
                      saturation: hsv.saturation,
                      value: hsv.value,
                    ),
                    size: Size(double.infinity, paletteHeight),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 10),

        // 5. Large Hue Slider
        Container(
          height: 28,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(VRadius.pill),
            gradient: const LinearGradient(
              colors: [
                Color(0xFFFF0000),
                Color(0xFFFFFF00),
                Color(0xFF00FF00),
                Color(0xFF00FFFF),
                Color(0xFF0000FF),
                Color(0xFFFF00FF),
                Color(0xFFFF0000),
              ],
            ),
          ),
          child: SliderTheme(
            data: SliderThemeData(
              trackShape: const RectangularSliderTrackShape(),
              trackHeight: 0,
              thumbColor: Colors.white,
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 12,
                elevation: 3,
              ),
              overlayColor: Colors.transparent,
            ),
            child: Slider(
              value: hsv.hue.clamp(0.0, 360.0),
              min: 0.0,
              max: 360.0,
              onChanged: (newHue) {
                final newColor = HSVColor.fromAHSV(
                  1.0,
                  newHue,
                  hsv.saturation,
                  hsv.value,
                ).toColor();
                _updateCurrentColor(newColor);
              },
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 6. Hex Input
        Text(
          context.l10n.accentColorHexCode,
          style: context.textTheme.titleSmall,
        ),
        const SizedBox(height: 6),
        TextField(
          key: const Key('accent_hex_input'),
          controller: _hexController,
          maxLength: 6,
          style: monoTextStyle(fontSize: 13),
          decoration: InputDecoration(
            prefixText: '# ',
            counterText: '',
            isDense: true,
            errorText: _hexError,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(VRadius.input),
            ),
          ),
          onChanged: (val) {
            final clean = val.replaceAll('#', '').trim();
            if (clean.length == 6) {
              final parsed = _parseHex(clean);
              if (parsed != null) {
                _updateCurrentColor(parsed, syncText: false);
              } else {
                setState(() {
                  _hexError = context.l10n.accentColorInvalidHex;
                });
              }
            } else {
              setState(() {
                _hexError = clean.isEmpty
                    ? null
                    : context.l10n.accentColorInvalidHex;
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context, {required bool isCompact}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: context.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.l10n.cancel),
            ),
            const SizedBox(width: 12),
            FilledButton(
              key: const Key('accent_color_confirm_button'),
              onPressed: _isHexValid ? _saveAndClose : null,
              child: Text(context.l10n.confirm),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveAndClose() async {
    await widget.notifier.setThemeAccentColor(AppThemeMode.light, _lightColor);
    await widget.notifier.setThemeAccentColor(AppThemeMode.dark, _darkColor);
    await widget.notifier.setThemeAccentColor(
      AppThemeMode.amoled,
      _amoledColor,
    );
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _handleSvPan(Offset offset, double width, double height, double hue) {
    final sat = (offset.dx / width).clamp(0.0, 1.0);
    final val = (1.0 - offset.dy / height).clamp(0.0, 1.0);
    final color = HSVColor.fromAHSV(1.0, hue, sat, val).toColor();
    _updateCurrentColor(color);
  }
}

class _SvPainter extends CustomPainter {
  final double hue;
  final double saturation;
  final double value;

  _SvPainter({
    required this.hue,
    required this.saturation,
    required this.value,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Base pure hue color
    final pureHue = HSVColor.fromAHSV(1.0, hue, 1.0, 1.0).toColor();
    canvas.drawRect(rect, Paint()..color = pureHue);

    // Saturation gradient (white -> transparent)
    final satGradient = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [Colors.white, Colors.white.withValues(alpha: 0)],
    );
    canvas.drawRect(rect, Paint()..shader = satGradient.createShader(rect));

    // Value gradient (transparent -> black)
    final valGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Colors.transparent, Colors.black],
    );
    canvas.drawRect(rect, Paint()..shader = valGradient.createShader(rect));

    // Indicator ring
    final dx = (saturation * size.width).clamp(0.0, size.width);
    final dy = ((1.0 - value) * size.height).clamp(0.0, size.height);
    final indicatorPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(Offset(dx, dy), 7, indicatorPaint);
    canvas.drawCircle(
      Offset(dx, dy),
      8,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _SvPainter oldDelegate) {
    return oldDelegate.hue != hue ||
        oldDelegate.saturation != saturation ||
        oldDelegate.value != value;
  }
}
