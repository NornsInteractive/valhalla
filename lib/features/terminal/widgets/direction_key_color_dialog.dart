import 'package:flutter/material.dart';
import '../../../core/design/tokens.dart';
import '../../../core/extensions/context_extensions.dart';

class DirectionKeyColorResult {
  final bool resetToTheme;
  final int? colorValue;

  const DirectionKeyColorResult({this.resetToTheme = false, this.colorValue});
}

class DirectionKeyColorDialog extends StatefulWidget {
  final int? initialColorValue;

  const DirectionKeyColorDialog({super.key, this.initialColorValue});

  static Future<DirectionKeyColorResult?> show(
    BuildContext context, {
    int? initialColorValue,
  }) {
    return showDialog<DirectionKeyColorResult>(
      context: context,
      builder: (_) =>
          DirectionKeyColorDialog(initialColorValue: initialColorValue),
    );
  }

  @override
  State<DirectionKeyColorDialog> createState() =>
      _DirectionKeyColorDialogState();
}

class _DirectionKeyColorDialogState extends State<DirectionKeyColorDialog> {
  static const List<Color> _presetColors = [
    Color(0xFF3B82F6), // Blue
    Color(0xFF06B6D4), // Cyan
    Color(0xFF10B981), // Emerald
    Color(0xFFF59E0B), // Amber
    Color(0xFF8B5CF6), // Violet
    Color(0xFF0D9488), // Teal
    Color(0xFFF97316), // Orange
    Color(0xFF64748B), // Slate
  ];

  late Color _currentColor;
  late TextEditingController _hexController;
  String? _hexError;

  @override
  void initState() {
    super.initState();
    _currentColor = widget.initialColorValue != null
        ? Color(widget.initialColorValue!)
        : _presetColors.first;
    _hexController = TextEditingController(text: _colorToHex(_currentColor));
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  void _updateCurrentColor(Color color, {bool syncText = true}) {
    final opaque = Color(0xFF000000 | (color.toARGB32() & 0xFFFFFF));
    setState(() {
      _currentColor = opaque;
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

  void _handleSvPan(Offset offset, double width, double height, double hue) {
    final sat = (offset.dx / width).clamp(0.0, 1.0);
    final val = (1.0 - offset.dy / height).clamp(0.0, 1.0);
    final color = HSVColor.fromAHSV(1.0, hue, sat, val).toColor();
    _updateCurrentColor(color);
  }

  @override
  Widget build(BuildContext context) {
    final hsv = HSVColor.fromColor(_currentColor);
    final brightness = Theme.of(context).brightness;
    final derivedScheme = ColorScheme.fromSeed(
      seedColor: _currentColor,
      brightness: brightness,
    );

    final dialogWidth = (MediaQuery.sizeOf(context).width - 48).clamp(
      280.0,
      440.0,
    );

    return AlertDialog(
      title: Text(context.l10n.terminalDirectionKeyColor),
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      content: SizedBox(
        width: dialogWidth,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Live preview card with normal and active state
              Text(
                context.l10n.accentColorPreview,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: context.colorScheme.outlineVariant.withValues(
                      alpha: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // Idle state preview
                    Column(
                      children: [
                        Text(
                          context.l10n.terminalDirectionKeyNormal,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: derivedScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '↑',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'JetBrains Mono',
                              color: derivedScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Active/pressed state preview
                    Column(
                      children: [
                        Text(
                          context.l10n.terminalDirectionKeyPressed,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: derivedScheme.primary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '↑',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'JetBrains Mono',
                              color: derivedScheme.onPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 2. Preset color swatches (44dp touch target)
              Text(
                context.l10n.accentColorPresets,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: _presetColors.map((color) {
                  final isCurrent =
                      (color.toARGB32() & 0xFFFFFF) ==
                      (_currentColor.toARGB32() & 0xFFFFFF);
                  return SizedBox(
                    width: 44,
                    height: 44,
                    child: InkWell(
                      onTap: () => _updateCurrentColor(color),
                      borderRadius: BorderRadius.circular(22),
                      child: Center(
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isCurrent
                                  ? context.colorScheme.onSurface
                                  : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                          child: isCurrent
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 16,
                                )
                              : null,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),

              // 3. HSV Color Palette (SV 2D Plane)
              Text(
                context.l10n.accentColorHsvPicker,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 130,
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
                          painter: _DirectionSvPainter(
                            hue: hsv.hue,
                            saturation: hsv.saturation,
                            value: hsv.value,
                          ),
                          size: const Size(double.infinity, 130),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // 4. Hue Slider
              Container(
                height: 28,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
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
                      elevation: 2,
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
              const SizedBox(height: 12),

              // 5. Hex Input
              Text(
                context.l10n.accentColorHexCode,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _hexController,
                maxLength: 6,
                style: monoTextStyle(fontSize: 13),
                decoration: InputDecoration(
                  prefixText: '# ',
                  counterText: '',
                  isDense: true,
                  errorText: _hexError,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
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
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(
              context,
            ).pop(const DirectionKeyColorResult(resetToTheme: true));
          },
          child: Text(context.l10n.terminalDirectionKeyColorReset),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed: _isHexValid
              ? () {
                  Navigator.of(context).pop(
                    DirectionKeyColorResult(
                      colorValue: _currentColor.toARGB32(),
                    ),
                  );
                }
              : null,
          child: Text(context.l10n.confirm),
        ),
      ],
    );
  }
}

class _DirectionSvPainter extends CustomPainter {
  final double hue;
  final double saturation;
  final double value;

  _DirectionSvPainter({
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
      colors: [Colors.white, Colors.white.withValues(alpha: 0.0)],
    );
    canvas.drawRect(rect, Paint()..shader = satGradient.createShader(rect));

    // Value gradient (transparent -> black)
    final valGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Colors.transparent, Colors.black],
    );
    canvas.drawRect(rect, Paint()..shader = valGradient.createShader(rect));

    // Thumb indicator
    final thumbX = (saturation * size.width).clamp(0.0, size.width);
    final thumbY = ((1.0 - value) * size.height).clamp(0.0, size.height);
    final thumbPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(Offset(thumbX, thumbY), 6.0, thumbPaint);
    canvas.drawCircle(
      Offset(thumbX, thumbY),
      5.0,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(covariant _DirectionSvPainter oldDelegate) {
    return oldDelegate.hue != hue ||
        oldDelegate.saturation != saturation ||
        oldDelegate.value != value;
  }
}
