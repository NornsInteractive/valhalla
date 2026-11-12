import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:xterm/core.dart';

/// Handles scrolling gestures in both regular and alternate screen buffers.
/// In alternate screen buffer (tmux, vim, less, htop), scroll gestures and wheel
/// events are converted to mouse wheel escape sequences (or arrow keys).
/// In regular buffer, vertical gestures drive [scrollController] for scrollback history.
class TerminalScrollGestureHandler extends StatefulWidget {
  const TerminalScrollGestureHandler({
    super.key,
    required this.terminal,
    required this.getCellOffset,
    required this.getLineHeight,
    this.simulateScroll = true,
    this.scrollController,
    required this.child,
  });

  final Terminal terminal;

  /// Returns the cell offset for the pixel offset.
  final CellOffset Function(Offset) getCellOffset;

  /// Returns the pixel height of lines in the terminal.
  final double Function() getLineHeight;

  /// Whether to simulate scroll events in the terminal when the application
  /// doesn't declare it supports mouse wheel events. true by default as it
  /// is the default behavior of most terminals.
  final bool simulateScroll;

  /// Optional scroll controller from the parent Scrollable, used to drive
  /// scrollback buffer scrolling during normal buffer vertical drag.
  final ScrollController? scrollController;

  final Widget child;

  @override
  State<TerminalScrollGestureHandler> createState() =>
      _TerminalScrollGestureHandlerState();
}

class _TerminalScrollGestureHandlerState
    extends State<TerminalScrollGestureHandler> {
  var isAltBuffer = false;
  var mouseMode = MouseMode.none;
  var lastPointerPosition = Offset.zero;

  Drag? _activeScrollDrag;
  double _accumulatedDragDelta = 0.0;
  double _accumulatedPointerScrollDelta = 0.0;
  Timer? _flingTimer;

  @override
  void initState() {
    widget.terminal.addListener(_onTerminalUpdated);
    isAltBuffer = widget.terminal.isUsingAltBuffer;
    mouseMode = widget.terminal.mouseMode;
    super.initState();
  }

  @override
  void dispose() {
    _flingTimer?.cancel();
    _activeScrollDrag?.cancel();
    _activeScrollDrag = null;
    widget.terminal.removeListener(_onTerminalUpdated);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TerminalScrollGestureHandler oldWidget) {
    if (oldWidget.terminal != widget.terminal) {
      oldWidget.terminal.removeListener(_onTerminalUpdated);
      widget.terminal.addListener(_onTerminalUpdated);
      isAltBuffer = widget.terminal.isUsingAltBuffer;
      mouseMode = widget.terminal.mouseMode;
    }
    super.didUpdateWidget(oldWidget);
  }

  void _onTerminalUpdated() {
    final newAlt = widget.terminal.isUsingAltBuffer;
    final newMouse = widget.terminal.mouseMode;
    if (isAltBuffer != newAlt || mouseMode != newMouse) {
      isAltBuffer = newAlt;
      mouseMode = newMouse;
      setState(() {});
    }
  }

  bool get _isAltOrMouseMode =>
      isAltBuffer || widget.terminal.mouseMode != MouseMode.none;

  /// Send a single scroll event to the terminal. If [simulateScroll] is true,
  /// then if the application doesn't recognize mouse wheel events, this method
  /// will simulate scroll events by sending up/down arrow keys.
  void _sendScrollEvent(bool up) {
    final position = widget.getCellOffset(lastPointerPosition);

    final handled = widget.terminal.mouseInput(
      up ? TerminalMouseButton.wheelUp : TerminalMouseButton.wheelDown,
      TerminalMouseButtonState.down,
      position,
    );

    if (!handled && widget.simulateScroll) {
      widget.terminal.keyInput(
        up ? TerminalKey.arrowUp : TerminalKey.arrowDown,
      );
    }
  }

  void _onPointerScroll(PointerScrollEvent event) {
    _accumulatedPointerScrollDelta += event.scrollDelta.dy;
    final lineHeight = widget.getLineHeight();
    final effectiveLineHeight = lineHeight > 0 ? lineHeight : 16.0;

    while (_accumulatedPointerScrollDelta <= -effectiveLineHeight) {
      _sendScrollEvent(true);
      _accumulatedPointerScrollDelta += effectiveLineHeight;
    }
    while (_accumulatedPointerScrollDelta >= effectiveLineHeight) {
      _sendScrollEvent(false);
      _accumulatedPointerScrollDelta -= effectiveLineHeight;
    }
  }

  void _onPointerPanZoom(PointerPanZoomUpdateEvent event) {
    _accumulatedPointerScrollDelta -= event.pan.dy;
    final lineHeight = widget.getLineHeight();
    final effectiveLineHeight = lineHeight > 0 ? lineHeight : 16.0;

    while (_accumulatedPointerScrollDelta <= -effectiveLineHeight) {
      _sendScrollEvent(true);
      _accumulatedPointerScrollDelta += effectiveLineHeight;
    }
    while (_accumulatedPointerScrollDelta >= effectiveLineHeight) {
      _sendScrollEvent(false);
      _accumulatedPointerScrollDelta -= effectiveLineHeight;
    }
  }

  void _handleDragStart(DragStartDetails details) {
    _flingTimer?.cancel();
    lastPointerPosition = details.localPosition;
    _accumulatedDragDelta = 0.0;

    if (!_isAltOrMouseMode &&
        widget.scrollController != null &&
        widget.scrollController!.hasClients) {
      _activeScrollDrag = widget.scrollController!.position.drag(details, () {
        _activeScrollDrag = null;
      });
    }
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    lastPointerPosition = details.localPosition;

    if (_isAltOrMouseMode) {
      final dy = details.primaryDelta ?? details.delta.dy;
      _accumulatedDragDelta += dy;
      final lineHeight = widget.getLineHeight();
      final effectiveLineHeight = lineHeight > 0 ? lineHeight : 16.0;
      // In mouse reporting mode (e.g. tmux copy-mode, vim, less), each wheel event
      // usually scrolls 3-5 lines on the host. We use a tuned threshold (effectiveLineHeight * 1.6)
      // to give comfortable, controllable touch drag without runaway acceleration.
      final stepThreshold = effectiveLineHeight * 1.6;

      // Note: Dragging finger DOWN (dy > 0) pulls content down to see earlier lines -> wheelUp (true).
      // Dragging finger UP (dy < 0) pulls content up to see newer lines -> wheelDown (false).
      while (_accumulatedDragDelta >= stepThreshold) {
        _sendScrollEvent(true);
        _accumulatedDragDelta -= stepThreshold;
      }
      while (_accumulatedDragDelta <= -stepThreshold) {
        _sendScrollEvent(false);
        _accumulatedDragDelta += stepThreshold;
      }
    } else {
      if (_activeScrollDrag != null) {
        _activeScrollDrag!.update(details);
      } else if (widget.scrollController != null &&
          widget.scrollController!.hasClients) {
        final pos = widget.scrollController!.position;
        final dy = details.primaryDelta ?? details.delta.dy;
        final newOffset =
            (pos.pixels - dy).clamp(pos.minScrollExtent, pos.maxScrollExtent);
        pos.jumpTo(newOffset);
      }
    }
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_isAltOrMouseMode) {
      final velocity = details.primaryVelocity ?? 0.0;
      if (velocity.abs() > 300) {
        _performAltFling(velocity);
      }
      _accumulatedDragDelta = 0.0;
    } else {
      if (_activeScrollDrag != null) {
        _activeScrollDrag!.end(details);
        _activeScrollDrag = null;
      }
    }
  }

  void _handleDragCancel() {
    _activeScrollDrag?.cancel();
    _activeScrollDrag = null;
    _accumulatedDragDelta = 0.0;
    _flingTimer?.cancel();
  }

  void _performAltFling(double initialVelocity) {
    _flingTimer?.cancel();
    final up = initialVelocity > 0;
    var stepCount = (initialVelocity.abs() / 400).round().clamp(1, 12);
    _flingTimer = Timer.periodic(const Duration(milliseconds: 36), (timer) {
      if (!mounted || stepCount <= 0) {
        timer.cancel();
        return;
      }
      _sendScrollEvent(up);
      stepCount--;
    });
  }

  @override
  Widget build(BuildContext context) {
    final gestures = <Type, GestureRecognizerFactory>{};

    gestures[VerticalDragGestureRecognizer] =
        GestureRecognizerFactoryWithHandlers<VerticalDragGestureRecognizer>(
      () => VerticalDragGestureRecognizer(
        debugOwner: this,
        supportedDevices: const <PointerDeviceKind>{
          PointerDeviceKind.touch,
          PointerDeviceKind.stylus,
          PointerDeviceKind.invertedStylus,
          PointerDeviceKind.trackpad,
        },
      ),
      (VerticalDragGestureRecognizer instance) {
        instance
          ..onStart = _handleDragStart
          ..onUpdate = _handleDragUpdate
          ..onEnd = _handleDragEnd
          ..onCancel = _handleDragCancel;
      },
    );

    return Listener(
      onPointerSignal: (event) {
        lastPointerPosition = event.position;
        if (event is PointerScrollEvent && _isAltOrMouseMode) {
          _onPointerScroll(event);
        }
      },
      onPointerPanZoomUpdate: (event) {
        lastPointerPosition = event.position;
        if (_isAltOrMouseMode) {
          _onPointerPanZoom(event);
        }
      },
      onPointerDown: (event) {
        lastPointerPosition = event.position;
      },
      child: RawGestureDetector(
        gestures: gestures,
        behavior: HitTestBehavior.translucent,
        child: widget.child,
      ),
    );
  }
}
