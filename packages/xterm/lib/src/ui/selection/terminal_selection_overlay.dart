import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/src/core/buffer/cell_offset.dart';
import 'package:xterm/src/terminal.dart';
import 'package:xterm/src/terminal_view.dart';
import 'package:xterm/src/ui/controller.dart';
import 'package:xterm/src/ui/render.dart';
import 'package:xterm/src/ui/selection_mode.dart';

const double _kHandleRadius = 11.0;
const double _kTouchTargetSize = 44.0;

/// Type of selection handle.
enum TerminalSelectionHandleType {
  /// Start of the selection (left/top endpoint).
  start,

  /// End of the selection (right/bottom endpoint).
  end,
}

/// Overlay that renders and manages draggable selection handles for [TerminalView].
class TerminalSelectionOverlay extends StatefulWidget {
  const TerminalSelectionOverlay({
    super.key,
    required this.terminalView,
    required this.controller,
    required this.scrollController,
    required this.terminal,
    this.handleColor,
    this.enabled = true,
  });

  final TerminalViewState terminalView;
  final TerminalController controller;
  final ScrollController scrollController;
  final Terminal terminal;
  final Color? handleColor;
  final bool enabled;

  @override
  State<TerminalSelectionOverlay> createState() => _TerminalSelectionOverlayState();
}

class _TerminalSelectionOverlayState extends State<TerminalSelectionOverlay> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onStateChanged);
    widget.scrollController.addListener(_onStateChanged);
    widget.terminal.addListener(_onStateChanged);
  }

  @override
  void didUpdateWidget(TerminalSelectionOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onStateChanged);
      widget.controller.addListener(_onStateChanged);
    }
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_onStateChanged);
      widget.scrollController.addListener(_onStateChanged);
    }
    if (oldWidget.terminal != widget.terminal) {
      oldWidget.terminal.removeListener(_onStateChanged);
      widget.terminal.addListener(_onStateChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onStateChanged);
    widget.scrollController.removeListener(_onStateChanged);
    widget.terminal.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  RenderTerminal? get _renderTerminal {
    try {
      final render = widget.terminalView.renderTerminal;
      if (render.hasSize) {
        return render;
      }
    } catch (_) {}
    return null;
  }

  void _onHandlePanUpdate(
    DragUpdateDetails details,
    TerminalSelectionHandleType type,
  ) {
    final render = _renderTerminal;
    if (render == null) return;

    final currentSelection = widget.controller.selection?.normalized;
    if (currentSelection == null) return;

    final localPos = render.globalToLocal(details.globalPosition);
    final lineHeight = render.lineHeight;
    final viewportHeight = render.size.height;

    // Adjust target point vertically so text line directly above the user's
    // finger tip is selected rather than the cell under the teardrop.
    final targetY = localPos.dy - (lineHeight * 0.7);
    final targetX = localPos.dx;
    final rawCell = render.getCellOffset(Offset(targetX, targetY));

    // Auto-scroll when dragging near viewport top/bottom edges
    if (localPos.dy < 36 && widget.scrollController.hasClients) {
      final targetOffset = (widget.scrollController.offset - lineHeight)
          .clamp(0.0, widget.scrollController.position.maxScrollExtent);
      if (targetOffset != widget.scrollController.offset) {
        widget.scrollController.jumpTo(targetOffset);
      }
    } else if (localPos.dy > viewportHeight - 36 &&
        widget.scrollController.hasClients) {
      final targetOffset = (widget.scrollController.offset + lineHeight)
          .clamp(0.0, widget.scrollController.position.maxScrollExtent);
      if (targetOffset != widget.scrollController.offset) {
        widget.scrollController.jumpTo(targetOffset);
      }
    }

    if (type == TerminalSelectionHandleType.start) {
      final currentEnd = currentSelection.end;
      var newBegin = rawCell;

      // Ensure newBegin does not cross currentEnd
      if (newBegin.y > currentEnd.y ||
          (newBegin.y == currentEnd.y && newBegin.x >= currentEnd.x)) {
        if (currentEnd.x > 0) {
          newBegin = CellOffset(currentEnd.x - 1, currentEnd.y);
        } else if (currentEnd.y > 0) {
          newBegin = CellOffset(widget.terminal.viewWidth - 1, currentEnd.y - 1);
        } else {
          newBegin = const CellOffset(0, 0);
        }
      }

      final base = widget.terminal.buffer.createAnchorFromOffset(newBegin);
      final extent = widget.terminal.buffer.createAnchorFromOffset(currentEnd);
      widget.controller.setSelection(base, extent, mode: SelectionMode.line);
    } else {
      final currentBegin = currentSelection.begin;
      // End is exclusive in BufferRangeLine: selecting at cell x means end offset is x + 1
      var newEnd = CellOffset(rawCell.x + 1, rawCell.y);

      // Ensure newEnd does not precede currentBegin
      if (newEnd.y < currentBegin.y ||
          (newEnd.y == currentBegin.y && newEnd.x <= currentBegin.x)) {
        if (currentBegin.x < widget.terminal.viewWidth) {
          newEnd = CellOffset(currentBegin.x + 1, currentBegin.y);
        } else {
          newEnd = CellOffset(1, currentBegin.y + 1);
        }
      }

      final base = widget.terminal.buffer.createAnchorFromOffset(currentBegin);
      final extent = widget.terminal.buffer.createAnchorFromOffset(newEnd);
      widget.controller.setSelection(base, extent, mode: SelectionMode.line);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return const SizedBox.shrink();
    }

    final selection = widget.controller.selection?.normalized;
    if (selection == null) {
      return const SizedBox.shrink();
    }

    final render = _renderTerminal;
    if (render == null) {
      return const SizedBox.shrink();
    }

    final beginOffset = render.getOffset(selection.begin);
    final endOffset = render.getOffset(selection.end);
    final lineHeight = render.lineHeight;
    final viewportSize = render.size;

    // Anchor points:
    // Start handle points to the bottom-left of the first cell
    final startAnchor = Offset(beginOffset.dx, beginOffset.dy + lineHeight);
    // End handle points to the bottom-left of the exclusive end cell (which is bottom-right of last cell)
    final endAnchor = Offset(endOffset.dx, endOffset.dy + lineHeight);

    // Hide handles if scrolled completely offscreen
    final isStartVisible =
        startAnchor.dy >= -20 && startAnchor.dy <= viewportSize.height + 40;
    final isEndVisible =
        endAnchor.dy >= -20 && endAnchor.dy <= viewportSize.height + 40;

    final color = widget.handleColor ??
        TextSelectionTheme.of(context).selectionHandleColor ??
        Theme.of(context).colorScheme.primary;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (isStartVisible)
          _SelectionHandleWidget(
            key: const Key('terminal_selection_start_handle'),
            anchor: startAnchor,
            lineHeight: lineHeight,
            color: color,
            type: TerminalSelectionHandleType.start,
            onPanUpdate: (d) =>
                _onHandlePanUpdate(d, TerminalSelectionHandleType.start),
          ),
        if (isEndVisible)
          _SelectionHandleWidget(
            key: const Key('terminal_selection_end_handle'),
            anchor: endAnchor,
            lineHeight: lineHeight,
            color: color,
            type: TerminalSelectionHandleType.end,
            onPanUpdate: (d) =>
                _onHandlePanUpdate(d, TerminalSelectionHandleType.end),
          ),
      ],
    );
  }
}

class _SelectionHandleWidget extends StatelessWidget {
  const _SelectionHandleWidget({
    super.key,
    required this.anchor,
    required this.lineHeight,
    required this.color,
    required this.type,
    required this.onPanUpdate,
  });

  final Offset anchor;
  final double lineHeight;
  final Color color;
  final TerminalSelectionHandleType type;
  final GestureDragUpdateCallback onPanUpdate;

  @override
  Widget build(BuildContext context) {
    // We position the touch target so the teardrop tip aligns with the anchor.
    //
    // For Start Handle:
    //   Teardrop circle is centered at (-_kHandleRadius, _kHandleRadius) from anchor.
    //   Touch target center is around (-_kHandleRadius, _kHandleRadius).
    // For End Handle:
    //   Teardrop circle is centered at (_kHandleRadius, _kHandleRadius) from anchor.
    //   Touch target center is around (_kHandleRadius, _kHandleRadius).

    final isStart = type == TerminalSelectionHandleType.start;
    final double left = isStart
        ? anchor.dx - _kTouchTargetSize + (_kTouchTargetSize / 2 - _kHandleRadius)
        : anchor.dx - (_kTouchTargetSize / 2 - _kHandleRadius);

    final double top = anchor.dy - (_kTouchTargetSize / 2 - _kHandleRadius);

    return Positioned(
      left: left,
      top: top,
      width: _kTouchTargetSize,
      height: _kTouchTargetSize,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) {
          HapticFeedback.selectionClick();
        },
        onPanUpdate: onPanUpdate,
        child: CustomPaint(
          size: const Size(_kTouchTargetSize, _kTouchTargetSize),
          painter: _HandlePainter(
            color: color,
            type: type,
          ),
        ),
      ),
    );
  }
}

class _HandlePainter extends CustomPainter {
  _HandlePainter({
    required this.color,
    required this.type,
  });

  final Color color;
  final TerminalSelectionHandleType type;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..isAntiAlias = true
      ..style = PaintingStyle.fill;

    final isStart = type == TerminalSelectionHandleType.start;
    final radius = _kHandleRadius;

    // Anchor point inside the touch target widget:
    final anchorInWidget = isStart
        ? Offset(size.width - (size.width / 2 - radius), size.height / 2 - radius)
        : Offset(size.width / 2 - radius, size.height / 2 - radius);

    // Teardrop path:
    // Circle centered at (anchor.dx - radius, anchor.dy + radius) for start
    // Circle centered at (anchor.dx + radius, anchor.dy + radius) for end
    final circleCenter = isStart
        ? Offset(anchorInWidget.dx - radius, anchorInWidget.dy + radius)
        : Offset(anchorInWidget.dx + radius, anchorInWidget.dy + radius);

    final path = Path()
      ..addOval(Rect.fromCircle(center: circleCenter, radius: radius));

    // Corner connecting to the anchor point
    if (isStart) {
      // Wedge pointing up-right to anchorInWidget
      path.addRect(Rect.fromLTRB(
        circleCenter.dx,
        anchorInWidget.dy,
        anchorInWidget.dx,
        circleCenter.dy,
      ));
    } else {
      // Wedge pointing up-left to anchorInWidget
      path.addRect(Rect.fromLTRB(
        anchorInWidget.dx,
        anchorInWidget.dy,
        circleCenter.dx,
        circleCenter.dy,
      ));
    }

    // Shadow for depth and contrast over dark/light terminals
    canvas.drawShadow(path, Colors.black, 3.0, true);
    canvas.drawPath(path, paint);

    // Subtle 1.5px vertical indicator line touching the baseline
    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.9)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(anchorInWidget.dx, anchorInWidget.dy - 6.0),
      Offset(anchorInWidget.dx, anchorInWidget.dy),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(_HandlePainter oldPainter) {
    return color != oldPainter.color || type != oldPainter.type;
  }
}
