import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show SchedulerPhase;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/storage_providers.dart';
import '../../../data/models/terminal_accessory_layout.dart';
import 'direction_key_color_dialog.dart';

export '../../../data/models/terminal_accessory_layout.dart';

enum ModifierLockState { inactive, oneShot, locked }

/// Helper widget that repeats invoking [onPressed] while held down.
/// Differentiates between tap, hold, and drag:
/// - A tap (press and release quickly) fires [onPressed] once on pointer up.
/// - A hold (finger held for >200ms without dragging) fires [onPressed] and repeats.
/// - A drag (finger moved >18dp) cancels repeat and tap so horizontal page swipes never fire.
/// Cancels cleanly on pointer up, drag, pointer cancel, or disposal.
class HoldRepeatKey extends StatefulWidget {
  final VoidCallback onPressed;
  final Widget child;
  final bool Function()? canRepeat;
  final ValueChanged<bool>? onHoldChanged;

  const HoldRepeatKey({
    super.key,
    required this.onPressed,
    required this.child,
    this.canRepeat,
    this.onHoldChanged,
  });

  @override
  State<HoldRepeatKey> createState() => _HoldRepeatKeyState();
}

class _HoldRepeatKeyState extends State<HoldRepeatKey>
    with WidgetsBindingObserver {
  Timer? _initialTimer;
  Timer? _repeatTimer;
  int? _activePointerId;
  Offset? _downPosition;
  bool _isDragSlopExceeded = false;
  bool _hasFired = false;
  bool _isHeld = false;
  bool _isDisposed = false;
  static const double _kDragSlop = 18.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _cancel();
    }
  }

  void _notifyHold(bool held) {
    if (_isHeld == held) return;
    _isHeld = held;
    final callback = widget.onHoldChanged;
    if (callback == null || _isDisposed) return;
    scheduleMicrotask(() {
      if (mounted && !_isDisposed) {
        callback(held);
      }
    });
  }

  void _start(int pointerId, Offset position) {
    if (_activePointerId != null) {
      _cancel();
    }
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) {
      return;
    }
    if (widget.canRepeat != null && !widget.canRepeat!()) {
      return;
    }
    _activePointerId = pointerId;
    _downPosition = position;
    _isDragSlopExceeded = false;
    _hasFired = false;
    _notifyHold(true);

    _initialTimer = Timer(const Duration(milliseconds: 200), () {
      final currentLifecycle = WidgetsBinding.instance.lifecycleState;
      if (!mounted ||
          _isDragSlopExceeded ||
          (currentLifecycle != null &&
              currentLifecycle != AppLifecycleState.resumed) ||
          (widget.canRepeat != null && !widget.canRepeat!())) {
        _cancel();
        return;
      }
      _hasFired = true;
      widget.onPressed();

      _repeatTimer = Timer.periodic(const Duration(milliseconds: 70), (_) {
        final tickLifecycle = WidgetsBinding.instance.lifecycleState;
        if (!mounted ||
            _isDragSlopExceeded ||
            (tickLifecycle != null &&
                tickLifecycle != AppLifecycleState.resumed) ||
            (widget.canRepeat != null && !widget.canRepeat!())) {
          _cancel();
          return;
        }
        widget.onPressed();
      });
    });
  }

  void _cancel() {
    _activePointerId = null;
    _initialTimer?.cancel();
    _initialTimer = null;
    _repeatTimer?.cancel();
    _repeatTimer = null;
    _notifyHold(false);
  }

  @override
  void deactivate() {
    _cancel();
    super.deactivate();
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!TickerMode.of(context)) {
      _cancel();
    }
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e) {
        if (_activePointerId == null) {
          _start(e.pointer, e.position);
        }
      },
      onPointerMove: (e) {
        if (e.pointer == _activePointerId && _downPosition != null) {
          if ((e.position - _downPosition!).distance > _kDragSlop) {
            _isDragSlopExceeded = true;
            _cancel();
          }
        }
      },
      onPointerUp: (e) {
        if (e.pointer == _activePointerId) {
          if (!_isDragSlopExceeded && !_hasFired) {
            _hasFired = true;
            widget.onPressed();
          }
          _cancel();
        }
      },
      onPointerCancel: (e) {
        if (e.pointer == _activePointerId) {
          _cancel();
        }
      },
      child: widget.child,
    );
  }
}

/// Lightweight key feedback wrapper providing immediate visual response (~120ms)
/// without triggering full-bar setState or stealing gestures from horizontal swipes.
class _AccessoryKeyFeedback extends StatefulWidget {
  final VoidCallback? onTap;
  final Widget Function(BuildContext context, bool isPressed) builder;

  const _AccessoryKeyFeedback({this.onTap, required this.builder});

  @override
  State<_AccessoryKeyFeedback> createState() => _AccessoryKeyFeedbackState();
}

class _AccessoryKeyFeedbackState extends State<_AccessoryKeyFeedback>
    with WidgetsBindingObserver {
  static const double _kSlop = 18.0;
  int? _activePointerId;
  int? _cancelledPointerId;
  Offset? _downPosition;
  bool _isPressed = false;
  bool _isPhysicalDown = false;
  bool _isPhysicalCancelled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!TickerMode.of(context) &&
        (_isPressed || _activePointerId != null || _isPhysicalDown)) {
      _cancel();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed &&
        (_isPressed || _activePointerId != null || _isPhysicalDown)) {
      _cancel();
    }
  }

  void _cancel() {
    if (_isPhysicalDown) {
      _isPhysicalCancelled = true;
      _cancelledPointerId = _activePointerId;
    }
    _isPhysicalDown = false;
    _downPosition = null;
    _activePointerId = null;
    if (_isPressed) {
      if (mounted) {
        setState(() {
          _isPressed = false;
        });
      } else {
        _isPressed = false;
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _isPressed = false;
    _activePointerId = null;
    _cancelledPointerId = null;
    _downPosition = null;
    _isPhysicalDown = false;
    _isPhysicalCancelled = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final animDuration = disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 120);

    final isTickerActive = TickerMode.of(context);
    final effectivePressed = isTickerActive && _isPressed;

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e) {
        if (!mounted || _activePointerId != null) return;
        _activePointerId = e.pointer;
        _downPosition = e.position;
        _isPhysicalDown = true;
        _isPhysicalCancelled = false;
        setState(() => _isPressed = true);
      },
      onPointerMove: (e) {
        if (!mounted) return;
        if (e.pointer == _activePointerId && _downPosition != null) {
          if ((e.position - _downPosition!).distance > _kSlop) {
            _cancel();
          }
        }
      },
      onPointerUp: (e) {
        if (!mounted) return;
        if (e.pointer == _cancelledPointerId) {
          _cancelledPointerId = null;
        }
        if (e.pointer == _activePointerId) {
          _isPhysicalDown = false;
          _activePointerId = null;
          _downPosition = null;
          if (_isPressed) {
            setState(() => _isPressed = false);
          }
        }
      },
      onPointerCancel: (e) {
        if (!mounted) return;
        if (e.pointer == _activePointerId || e.pointer == _cancelledPointerId) {
          _isPhysicalDown = false;
          _activePointerId = null;
          _cancelledPointerId = null;
          _isPhysicalCancelled = false;
          _downPosition = null;
          if (_isPressed) {
            setState(() => _isPressed = false);
          }
        }
      },
      child: Semantics(
        button: true,
        enabled: widget.onTap != null,
        onTap: widget.onTap,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: () {
            if (!mounted) return;
            if (_isPhysicalCancelled) {
              _isPhysicalCancelled = false;
              _cancelledPointerId = null;
              return;
            }
            widget.onTap?.call();
          },
          child: RepaintBoundary(
            child: AnimatedScale(
              scale: effectivePressed ? 0.95 : 1.0,
              duration: animDuration,
              curve: Curves.easeOutCubic,
              child: widget.builder(context, effectivePressed),
            ),
          ),
        ),
      ),
    );
  }
}

/// Lightweight self-contained arrow key cell wrapping HoldRepeatKey
/// without triggering full-bar setState on hold changes.
class _ArrowKeyCell extends StatefulWidget {
  final String label;
  final Key? containerKey;
  final ColorScheme? scheme;
  final ThemeData theme;
  final bool isEdit;
  final bool Function()? canRepeat;
  final VoidCallback onPressed;

  const _ArrowKeyCell({
    required this.label,
    this.containerKey,
    required this.scheme,
    required this.theme,
    required this.isEdit,
    required this.canRepeat,
    required this.onPressed,
  });

  @override
  State<_ArrowKeyCell> createState() => _ArrowKeyCellState();
}

class _ArrowKeyCellState extends State<_ArrowKeyCell> {
  bool _isHeld = false;

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final animDuration = disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 120);

    final isTickerActive = TickerMode.of(context);
    final effectiveHeld = isTickerActive && _isHeld;

    Color cellColor;
    Color arrowTextColor;
    if (widget.scheme != null) {
      cellColor = effectiveHeld
          ? widget.scheme!.primary
          : widget.scheme!.secondaryContainer;
      arrowTextColor = effectiveHeld
          ? widget.scheme!.onPrimary
          : widget.scheme!.onSecondaryContainer;
    } else {
      cellColor = effectiveHeld
          ? widget.theme.colorScheme.primary
          : widget.theme.colorScheme.surfaceContainerHigh;
      arrowTextColor = effectiveHeld
          ? widget.theme.colorScheme.onPrimary
          : widget.theme.colorScheme.onSurface;
    }

    return HoldRepeatKey(
      onPressed: () {
        if (!widget.isEdit) {
          widget.onPressed();
        }
      },
      canRepeat: widget.canRepeat,
      onHoldChanged: (held) {
        if (_isHeld != held) {
          setState(() => _isHeld = held);
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: RepaintBoundary(
          child: AnimatedScale(
            scale: effectiveHeld ? 0.95 : 1.0,
            duration: animDuration,
            curve: Curves.easeOutCubic,
            child: Container(
              key: widget.containerKey,
              decoration: BoxDecoration(
                color: cellColor,
                borderRadius: BorderRadius.circular(8),
                boxShadow: effectiveHeld
                    ? const []
                    : const [
                        BoxShadow(
                          color: Color(0x66000000),
                          offset: Offset(0, 1),
                          blurRadius: 0,
                        ),
                      ],
              ),
              alignment: Alignment.center,
              child: Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: fontSizeForLabel(widget.label),
                  fontWeight: FontWeight.bold,
                  color: arrowTextColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModifierKeyButton extends StatefulWidget {
  final String label;
  final ModifierLockState? state;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final void Function(String modifier)? onModifierDown;
  final void Function(String modifier)? onModifierUp;
  final void Function(String modifier)? onModifierCancel;
  final bool isHeld;
  final bool isActive;
  final bool Function()? isOwnerMounted;
  final Widget child;

  const _ModifierKeyButton({
    required this.label,
    this.state,
    this.onTap,
    this.onLongPress,
    this.onModifierDown,
    this.onModifierUp,
    this.onModifierCancel,
    this.isHeld = false,
    this.isActive = false,
    this.isOwnerMounted,
    required this.child,
  });

  @override
  State<_ModifierKeyButton> createState() => _ModifierKeyButtonState();
}

class _ModifierKeyButtonState extends State<_ModifierKeyButton>
    with WidgetsBindingObserver {
  int? _activePointerId;
  int? _cancelledPointerId;
  Offset? _downPosition;
  bool _isDragSlopExceeded = false;
  bool _isPhysicalDown = false;
  bool _isPhysicalCancelled = false;
  int _cancelGeneration = 0;
  static const double _kTouchSlop = 18.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!TickerMode.of(context) &&
        (_activePointerId != null || _isPhysicalDown)) {
      _cancelModifier();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed &&
        (_activePointerId != null || _isPhysicalDown)) {
      _cancelModifier();
    }
  }

  void _safeNotifyCancel(String upper) {
    final generation = ++_cancelGeneration;
    final onCancel = widget.onModifierCancel;
    final isOwnerMounted = widget.isOwnerMounted;

    void notify() {
      final ownerAlive = isOwnerMounted?.call() ?? true;
      if (ownerAlive && _cancelGeneration == generation) {
        onCancel?.call(upper);
      }
    }

    if (WidgetsBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => notify());
    } else {
      scheduleMicrotask(notify);
    }
  }

  void _cancelModifier() {
    final upper = widget.label.toUpperCase();
    if (_isPhysicalDown) {
      _isPhysicalCancelled = true;
      _cancelledPointerId = _activePointerId;
    }
    _isPhysicalDown = false;
    _downPosition = null;
    if (_activePointerId != null) {
      if (mounted) {
        setState(() {
          _activePointerId = null;
        });
      } else {
        _activePointerId = null;
      }
      _safeNotifyCancel(upper);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_activePointerId != null || _isPhysicalDown) {
      final upper = widget.label.toUpperCase();
      _safeNotifyCancel(upper);
    }
    _activePointerId = null;
    _cancelledPointerId = null;
    _isPhysicalDown = false;
    _isPhysicalCancelled = true;
    _downPosition = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final upper = widget.label.toUpperCase();
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final animDuration = disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 120);

    final isTickerActive = TickerMode.of(context);
    final isDepressed =
        isTickerActive && (widget.isHeld || _activePointerId != null);

    final content = RepaintBoundary(
      child: AnimatedScale(
        scale: isDepressed ? 0.95 : 1.0,
        duration: animDuration,
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );

    if (widget.onModifierDown != null) {
      return Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) {
          if (!mounted || _activePointerId != null) return;
          _cancelGeneration++;
          setState(() {
            _activePointerId = event.pointer;
            _downPosition = event.position;
            _isPhysicalDown = true;
            _isPhysicalCancelled = false;
            _isDragSlopExceeded = false;
          });
          widget.onModifierDown!(upper);
        },
        onPointerMove: (event) {
          if (!mounted || event.pointer != _activePointerId) return;
          if (_downPosition != null) {
            final delta = event.position - _downPosition!;
            if (delta.distance > _kTouchSlop) {
              _isDragSlopExceeded = true;
            }
          }
        },
        onPointerUp: (event) {
          if (!mounted) return;
          if (event.pointer == _cancelledPointerId) {
            _cancelledPointerId = null;
          }
          if (event.pointer != _activePointerId) return;
          _isPhysicalDown = false;
          setState(() {
            _activePointerId = null;
          });
          if (_isDragSlopExceeded) {
            _safeNotifyCancel(upper);
          } else {
            if (widget.onModifierUp != null) {
              widget.onModifierUp!(upper);
            } else {
              widget.onTap?.call();
            }
          }
        },
        onPointerCancel: (event) {
          if (!mounted) return;
          if (event.pointer == _activePointerId ||
              event.pointer == _cancelledPointerId) {
            _isPhysicalDown = false;
            _cancelledPointerId = null;
            _isPhysicalCancelled = false;
            if (_activePointerId != null) {
              setState(() {
                _activePointerId = null;
              });
              _safeNotifyCancel(upper);
            }
          }
        },
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {},
            child: content,
          ),
        ),
      );
    }
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) {
        if (!mounted || _activePointerId != null) return;
        _cancelGeneration++;
        setState(() {
          _activePointerId = event.pointer;
          _downPosition = event.position;
          _isPhysicalDown = true;
          _isPhysicalCancelled = false;
          _isDragSlopExceeded = false;
        });
      },
      onPointerMove: (event) {
        if (!mounted || event.pointer != _activePointerId) return;
        if (_downPosition != null) {
          final delta = event.position - _downPosition!;
          if (delta.distance > _kTouchSlop) {
            _cancelModifier();
          }
        }
      },
      onPointerUp: (event) {
        if (!mounted) return;
        if (event.pointer == _cancelledPointerId) {
          _cancelledPointerId = null;
        }
        if (event.pointer == _activePointerId) {
          _isPhysicalDown = false;
          setState(() {
            _activePointerId = null;
          });
        }
      },
      onPointerCancel: (event) {
        if (!mounted) return;
        if (event.pointer == _activePointerId ||
            event.pointer == _cancelledPointerId) {
          _isPhysicalDown = false;
          _cancelledPointerId = null;
          _isPhysicalCancelled = false;
          if (_activePointerId != null) {
            setState(() {
              _activePointerId = null;
            });
          }
        }
      },
      child: Semantics(
        button: true,
        enabled: widget.onTap != null,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: () {
            if (!mounted) return;
            if (_isPhysicalCancelled) {
              _isPhysicalCancelled = false;
              _cancelledPointerId = null;
              return;
            }
            widget.onTap?.call();
          },
          onLongPress: () {
            if (!mounted) return;
            if (_isPhysicalCancelled) {
              _isPhysicalCancelled = false;
              _cancelledPointerId = null;
              return;
            }
            widget.onLongPress?.call();
          },
          child: content,
        ),
      ),
    );
  }
}

/// Self-contained paint-only translation wrapper for drag-and-drop feedback.
/// Moves with finger instantly without relayout, then settles over 120ms to zero offset.
class _AccessoryItemTransform extends StatefulWidget {
  final String itemId;
  final Widget child;
  final Offset dragOffset;
  final bool isDragging;
  final Offset? settleStartOffset;
  final int settleGeneration;
  final VoidCallback? onSettleComplete;

  const _AccessoryItemTransform({
    super.key,
    required this.itemId,
    required this.child,
    this.dragOffset = Offset.zero,
    this.isDragging = false,
    this.settleStartOffset,
    this.settleGeneration = 0,
    this.onSettleComplete,
  });

  @override
  State<_AccessoryItemTransform> createState() =>
      _AccessoryItemTransformState();
}

class _AccessoryItemTransformState extends State<_AccessoryItemTransform>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _controller;
  Animatable<Offset>? _settleTween;
  bool _isSettling = false;
  int _lastHandledGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!TickerMode.of(context) ||
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false)) {
      if (_isSettling || _controller.isAnimating) {
        _stopAndReset();
        widget.onSettleComplete?.call();
      }
    } else if (!_isSettling &&
        widget.settleStartOffset != null &&
        widget.settleGeneration != _lastHandledGeneration &&
        !widget.isDragging) {
      _checkSettle();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed &&
        (_isSettling || _controller.isAnimating)) {
      _stopAndReset();
      widget.onSettleComplete?.call();
    }
  }

  @override
  void didUpdateWidget(covariant _AccessoryItemTransform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isDragging) {
      if (_isSettling || _controller.isAnimating) {
        _stopAndReset();
      }
    } else if (widget.settleGeneration != _lastHandledGeneration &&
        widget.settleStartOffset != null) {
      _checkSettle();
    }
  }

  void _stopAndReset() {
    if (_controller.isAnimating) {
      _controller.stop();
    }
    _isSettling = false;
    _settleTween = null;
  }

  void _safeNotifyComplete(int generation) {
    if (!mounted || _lastHandledGeneration != generation) return;
    widget.onSettleComplete?.call();
  }

  void _checkSettle() {
    if (widget.settleStartOffset == null ||
        widget.settleGeneration == _lastHandledGeneration ||
        widget.isDragging) {
      return;
    }
    _lastHandledGeneration = widget.settleGeneration;
    final currentGen = widget.settleGeneration;

    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final isTickerActive = TickerMode.of(context);

    if (disableAnimations || !isTickerActive) {
      _stopAndReset();
      _safeNotifyComplete(currentGen);
      return;
    }

    _isSettling = true;
    _settleTween = Tween<Offset>(
      begin: widget.settleStartOffset,
      end: Offset.zero,
    ).chain(CurveTween(curve: Curves.easeOutCubic));

    _controller.forward(from: 0.0).catchError((_) {}).then((_) {
      if (mounted && _lastHandledGeneration == currentGen && _isSettling) {
        _isSettling = false;
        _settleTween = null;
        _safeNotifyComplete(currentGen);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopAndReset();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        Offset currentOffset = Offset.zero;
        if (widget.isDragging) {
          currentOffset = widget.dragOffset;
        } else if (_isSettling && _settleTween != null) {
          currentOffset = _settleTween!.evaluate(_controller);
        }
        return Transform.translate(offset: currentOffset, child: child);
      },
      child: widget.child,
    );
  }
}

String formatKeyLabel(String l) {
  return l
      .replaceAll('Ctrl+', '^')
      .replaceAll('Alt+', '⌥')
      .replaceAll('Shift+', '⇧')
      .replaceAll('Meta+', '⌘');
}

double fontSizeForLabel(String text) {
  if (text.length > 4) return 10.0;
  if (text.length > 2) return 12.0;
  return 13.0;
}

// Preset categories for Add tab
final Map<String, List<String>> kPresetSets = {
  'common': [
    'Esc',
    'Tab',
    'Enter',
    'Backspace',
    'Space',
    'Del',
    'Ins',
    'Ctrl+C',
    'Ctrl+D',
    'Ctrl+Z',
    'Ctrl+L',
    'Ctrl+R',
    'Ctrl+A',
    'Ctrl+E',
    'Ctrl+U',
    'Ctrl+W',
    'Ctrl+K',
  ],
  'ctrl': [
    ...List.generate(26, (i) => 'Ctrl+${String.fromCharCode(65 + i)}'),
    'Ctrl+[',
    'Ctrl+]',
    'Ctrl+\\',
    'Ctrl+Space',
  ],
  'alt': [
    ...List.generate(26, (i) => 'Alt+${String.fromCharCode(65 + i)}'),
    'Alt+.',
    'Alt+Backspace',
    'Alt+Enter',
  ],
  'fkeys': List.generate(12, (i) => 'F${i + 1}'),
  'nav': ['↑', '↓', '←', '→', 'Home', 'End', 'PgUp', 'PgDn', 'Ins', 'Del'],
  'sym': '| / \\ ~ - _ . , : ; * & ! @ # \$ % ^ = + ? \' " ` ( ) [ ] { } < >'
      .split(' '),
  'modifiers': ['Ctrl', 'Alt', 'Shift', 'Fn'],
  'custom': [],
};

// =============================================================================
// TerminalAccessoryBar Component
// =============================================================================

class TerminalAccessoryBar extends ConsumerStatefulWidget {
  final void Function(String key, {bool isCtrl, bool isAlt, bool isShift})
  onKey;
  final void Function(String text, {bool appendEnter})? onText;
  final VoidCallback onToggleCtrl;
  final VoidCallback? onLockCtrl;
  final VoidCallback onToggleAlt;
  final VoidCallback? onLockAlt;
  final VoidCallback? onToggleShift;
  final VoidCallback? onLockShift;
  final VoidCallback? onToggleFn;
  final VoidCallback? onLockFn;
  final void Function(String modifier)? onModifierDown;
  final void Function(String modifier)? onModifierUp;
  final void Function(String modifier)? onModifierCancel;
  final VoidCallback onPaste;
  final VoidCallback? onClearModifiers;
  final VoidCallback? onToggleKeyboard;
  final ModifierLockState? ctrlState;
  final ModifierLockState? altState;
  final ModifierLockState? shiftState;
  final ModifierLockState? fnState;
  final bool isCtrlActive;
  final bool isAltActive;
  final bool isCtrlHeld;
  final bool isAltHeld;
  final bool isShiftHeld;
  final bool isFnHeld;
  final bool pinKeyboardButtonTrailing;
  final bool? isKeyboardActive;
  final bool inputEnabled;
  final ValueChanged<double>? onHeightChanged;

  static double calculateBaseHeight(int rows) {
    return 10.0 + rows * kAccessoryCellHeight;
  }

  const TerminalAccessoryBar({
    super.key,
    required this.onKey,
    this.onText,
    required this.onToggleCtrl,
    this.onLockCtrl,
    required this.onToggleAlt,
    this.onLockAlt,
    this.onToggleShift,
    this.onLockShift,
    this.onToggleFn,
    this.onLockFn,
    this.onModifierDown,
    this.onModifierUp,
    this.onModifierCancel,
    required this.onPaste,
    this.onClearModifiers,
    this.onToggleKeyboard,
    this.ctrlState,
    this.altState,
    this.shiftState,
    this.fnState,
    this.isCtrlActive = false,
    this.isAltActive = false,
    this.isCtrlHeld = false,
    this.isAltHeld = false,
    this.isShiftHeld = false,
    this.isFnHeld = false,
    this.pinKeyboardButtonTrailing = false,
    this.isKeyboardActive,
    this.inputEnabled = true,
    this.onHeightChanged,
  });

  @override
  ConsumerState<TerminalAccessoryBar> createState() =>
      _TerminalAccessoryBarState();
}

class _TerminalAccessoryBarState extends ConsumerState<TerminalAccessoryBar>
    with WidgetsBindingObserver {
  late TerminalAccessoryLayout _masterLayout;
  late TerminalAccessoryLayout _draftLayout;
  late TerminalAccessoryLayout _originalLayout;
  final List<TerminalAccessoryLayout> _undoStack = [];
  bool _isDirty = false;
  bool _isSaving = false;

  // Projection & sizing cache
  int _masterRevision = 0;
  TerminalAccessoryLayout? _cachedProjection;
  int? _cachedProjRevision;
  int? _cachedProjColumns;
  int? _cachedProjRows;

  double? _cachedMinCellWidth;
  int? _cachedMinCellRevision;
  TextScaler? _cachedTextScaler;
  Locale? _cachedLocale;

  int _page = 0;
  int _previousPage = 0;
  int _pageDirection = 1;
  bool _edit = false;
  final Set<String> _mods = {};
  String? _sel;
  String _st = 'add'; // 'add', 'key', 'set'
  String _cat = 'common';
  bool _isExpanded = false;
  String _expandedCategory = 'Fn';
  bool _hasCorruptedStorage = false;

  // Dragging state
  String? _draggingId;
  Offset? _dragOffset;
  bool _isDragMoving = false;
  int? _dragTargetC;
  int? _dragTargetR;
  bool _dragTargetValid = false;
  String? _settlingId;
  Offset? _settleStartOffset;
  int _settleGeneration = 0;

  // Swipe gesture dx accumulator
  double _swipeDragDx = 0.0;

  // Text editing controllers for Tab 'key' & Tab 'add' (custom)
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  final TextEditingController _labelCtrl = TextEditingController();
  final TextEditingController _customKeyCtrl = TextEditingController();
  final TextEditingController _customLabelCtrl = TextEditingController();
  final TextEditingController _macroLabelCtrl = TextEditingController();
  final TextEditingController _macroTextCtrl = TextEditingController();
  final Map<String, bool> _customModCheckboxes = {
    'Ctrl': false,
    'Alt': false,
    'Shift': false,
  };
  bool _macroEnterCheckbox = false; // "默认新增宏不回车，旧宏行为保留"

  // Action editing controllers for Tab 'key'
  final TextEditingController _actionKeyCtrl = TextEditingController();
  final TextEditingController _actionTextCtrl = TextEditingController();
  final Map<String, bool> _actionModCheckboxes = {
    'CTRL': false,
    'ALT': false,
    'SHIFT': false,
  };
  bool _actionAppendEnterCheckbox = false;

  AppLifecycleState _appLifecycleState = AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadConfig();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onHeightChanged?.call(
          TerminalAccessoryBar.calculateBaseHeight(_masterLayout.rows),
        );
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchCtrl.dispose();
    _labelCtrl.dispose();
    _customKeyCtrl.dispose();
    _customLabelCtrl.dispose();
    _macroLabelCtrl.dispose();
    _macroTextCtrl.dispose();
    _actionKeyCtrl.dispose();
    _actionTextCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appLifecycleState = state;
  }

  bool _canRepeat() {
    return mounted &&
        widget.inputEnabled &&
        _appLifecycleState == AppLifecycleState.resumed &&
        TickerMode.of(context);
  }

  void _loadConfig() {
    try {
      final storage = ref.read(localStorageServiceProvider);
      final error = storage.getTerminalGridConfigError();
      final raw = storage.getTerminalGridConfig();
      if (error != null && raw == null) {
        _hasCorruptedStorage = true;
        _masterLayout = TerminalAccessoryLayout.defaultLayout();
      } else if (raw != null && raw.isNotEmpty) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        final schema = data['schemaVersion'] ?? 1;
        _masterLayout = TerminalAccessoryLayout.fromJson(data);
        // v1 direction color fallback from old storage seed; v2 explicit null stays null
        if (schema == 1 && _masterLayout.directionSeedColor == null) {
          final fallbackSeed = storage.getTerminalDirectionKeySeedColorValue();
          if (fallbackSeed != null) {
            _masterLayout = _masterLayout.copyWith(
              directionSeedColor: fallbackSeed,
            );
          }
        }
        _hasCorruptedStorage = false;
      } else {
        _masterLayout = TerminalAccessoryLayout.defaultLayout();
        _hasCorruptedStorage = false;
      }
    } catch (_) {
      _masterLayout = TerminalAccessoryLayout.defaultLayout();
    }
    _draftLayout = _masterLayout.copy();
    _originalLayout = _masterLayout.copy();
  }

  double _computeMinCellWidth(
    BuildContext context,
    Iterable<AccessoryItem> items,
  ) {
    final textScaler = MediaQuery.textScalerOf(context);
    final locale = Localizations.maybeLocaleOf(context);
    if (_cachedMinCellWidth != null &&
        _cachedMinCellRevision == _masterRevision &&
        _cachedTextScaler == textScaler &&
        _cachedLocale == locale) {
      return _cachedMinCellWidth!;
    }
    double maxW = 44.0;
    for (final item in items) {
      if (item.t == 'g' || item.t == 'i' || item.t == 'more') continue;
      final label = formatKeyLabel(item.l);
      final painter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontFamily: 'JetBrains Mono',
            fontSize: fontSizeForLabel(label),
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
      )..layout();
      final w = math.max(1, item.w);
      final cellReq = (painter.width + 8.0) / w;
      maxW = math.max(maxW, cellReq);
    }
    _cachedMinCellWidth = maxW;
    _cachedMinCellRevision = _masterRevision;
    _cachedTextScaler = textScaler;
    _cachedLocale = locale;
    return maxW;
  }

  int _calculateColumns(double boardWidth, double minCellWidth) {
    final baseCols = accessoryColumnsForWidth(
      boardWidth + 8,
      minCellWidth: minCellWidth,
    );
    int minCols = 4;
    if (_masterLayout.rows == 1) {
      final customItems = _masterLayout.items.where(
        (i) => i.t != 'i' && i.t != 'more',
      );
      final maxItemW = customItems.isEmpty
          ? 1
          : customItems.map((i) => i.w).reduce(math.max);
      minCols = math.max(4, maxItemW + 2);
    }
    return baseCols.clamp(minCols, 8);
  }

  TerminalAccessoryLayout _getProjectedLayout(int columns) {
    if (_cachedProjection == null ||
        _cachedProjRevision != _masterRevision ||
        _cachedProjColumns != columns ||
        _cachedProjRows != _masterLayout.rows) {
      _cachedProjection = _masterLayout.project(columns);
      _cachedProjRevision = _masterRevision;
      _cachedProjColumns = columns;
      _cachedProjRows = _masterLayout.rows;
    }
    return _cachedProjection!;
  }

  void _enterEditMode(int columns) {
    FocusScope.of(context).unfocus();
    setState(() {
      _edit = true;
      _isExpanded = false;
      _settlingId = null;
      _settleStartOffset = null;
      _draftLayout = _masterLayout.project(columns);
      _originalLayout = _draftLayout.copy();
      _undoStack.clear();
      _isDirty = false;
      _sel = null;
      _st = 'add';
    });
  }

  void _mutateDraft(void Function() mutation) {
    if (_isSaving) return;
    if (_undoStack.length >= 50) {
      _undoStack.removeAt(0);
    }
    _undoStack.add(_draftLayout.copy());
    mutation();
    _isDirty = !_draftLayout.hasSameContent(_originalLayout);
    setState(() {});
  }

  void _undo() {
    if (_undoStack.isEmpty || _isSaving) return;
    setState(() {
      _draftLayout = _undoStack.removeLast();
      _isDirty = !_draftLayout.hasSameContent(_originalLayout);
      if (_page >= _draftLayout.pages) {
        _page = math.max(0, _draftLayout.pages - 1);
      }
      if (!_draftLayout.items.any((i) => i.id == _sel)) {
        _sel = null;
      } else {
        _syncKeyProperties();
      }
    });
  }

  Future<void> _saveEdit() async {
    if (_isSaving) return;
    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);
    try {
      final toSave = _draftLayout.copy();
      toSave.validate(enforceSystemSlots: true);
      final storage = ref.read(localStorageServiceProvider);
      await storage.setTerminalGridConfig(jsonEncode(toSave.toJson()));
      if (!mounted) return;
      final oldRows = _masterLayout.rows;
      _masterLayout = toSave.copy();
      _originalLayout = toSave.copy();
      _masterRevision++;
      _cachedProjection = null;
      _cachedMinCellWidth = null;
      _undoStack.clear();
      _isDirty = false;
      _isSaving = false;
      _edit = false;
      _sel = null;
      _settlingId = null;
      _settleStartOffset = null;
      FocusScope.of(context).unfocus();
      if (_masterLayout.rows != oldRows) {
        widget.onHeightChanged?.call(
          TerminalAccessoryBar.calculateBaseHeight(_masterLayout.rows),
        );
      }
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.terminalGridSaveFailed),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _cancelEdit() async {
    if (_isSaving) return;
    if (_isDirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(context.l10n.terminalGridDiscardConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(context.l10n.confirm),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _edit = false;
      _sel = null;
      _settlingId = null;
      _settleStartOffset = null;
      _undoStack.clear();
      _isDirty = false;
      _draftLayout = _masterLayout.copy();
    });
  }

  void _press(AccessoryItem o) {
    if (_edit) return;

    final act = o.action;
    if (!act.supported) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.terminalGridMetaNotSupported),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (act.type == 'keyboard') {
      widget.onToggleKeyboard?.call();
      return;
    }

    if (act.type == 'more') {
      setState(() {
        _isExpanded = !_isExpanded;
      });
      return;
    }

    if (!widget.inputEnabled) {
      return;
    }

    if (act.type == 'paste') {
      widget.onPaste();
      return;
    }

    if (act.type == 'modifier') {
      final modKey = act.key.toUpperCase();
      if (modKey == 'CTRL') {
        widget.onToggleCtrl();
        return;
      }
      if (modKey == 'ALT') {
        widget.onToggleAlt();
        return;
      }
      if (modKey == 'SHIFT') {
        widget.onToggleShift?.call();
        return;
      }
      if (modKey == 'FN') {
        widget.onToggleFn?.call();
        return;
      }
      setState(() {
        if (_mods.contains(modKey)) {
          _mods.remove(modKey);
        } else {
          _mods.add(modKey);
        }
      });
      return;
    }

    if (act.type == 'text') {
      if (widget.onText != null) {
        widget.onText!(act.text, appendEnter: act.appendEnter);
      }
      return;
    }

    final isCtrl =
        act.modifiers.contains('CTRL') ||
        widget.isCtrlActive ||
        widget.ctrlState == ModifierLockState.oneShot ||
        widget.ctrlState == ModifierLockState.locked ||
        widget.isCtrlHeld ||
        _mods.any((m) => m.toUpperCase() == 'CTRL');
    final isAlt =
        act.modifiers.contains('ALT') ||
        widget.isAltActive ||
        widget.altState == ModifierLockState.oneShot ||
        widget.altState == ModifierLockState.locked ||
        widget.isAltHeld ||
        _mods.any((m) => m.toUpperCase() == 'ALT');
    final isShift =
        act.modifiers.contains('SHIFT') ||
        widget.shiftState == ModifierLockState.oneShot ||
        widget.shiftState == ModifierLockState.locked ||
        widget.isShiftHeld ||
        _mods.any((m) => m.toUpperCase() == 'SHIFT');

    widget.onKey(act.key, isCtrl: isCtrl, isAlt: isAlt, isShift: isShift);

    if (_mods.isNotEmpty) {
      setState(() {
        _mods.clear();
      });
    }
  }

  void _placeItem(AccessoryItem o) {
    final s = findFreeSpot(
      _draftLayout.items,
      1,
      1,
      _page,
      _draftLayout.rows,
      columns: _draftLayout.columns,
    );
    if (s == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.terminalGridNoSpace),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    o.id =
        'n${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(9999)}';
    o.p = _page;
    o.c = s[0];
    o.r = s[1];
    _mutateDraft(() {
      _draftLayout.items.add(o);
      _sel = o.id;
      _st = 'key';
      _syncKeyProperties();
    });
  }

  void _setRows(int n) {
    if (n < 1 || n > 5 || n == _draftLayout.rows || _isSaving) return;

    if (_draftLayout.items.any((i) => i.t == 'g') && n < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.terminalGridArrowsNeedTwoRows),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      final candidate = _draftLayout.project(_draftLayout.columns, rows: n);
      _mutateDraft(() {
        _draftLayout = candidate;
        if (_page >= _draftLayout.pages) {
          _page = _draftLayout.pages - 1;
        }
      });
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.terminalGridNoSpace),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _toggleArrows() {
    final g = _draftLayout.items.where((i) => i.t == 'g').firstOrNull;
    if (g != null) {
      _mutateDraft(() {
        _draftLayout.items.remove(g);
        for (final arr in kArrowOffsets) {
          final l = arr[0] as String;
          final x = arr[1] as int;
          final y = arr[2] as int;
          _draftLayout.items.add(
            AccessoryItem(
              id: 'a$l',
              l: l,
              s: l,
              arrow: 1,
              p: g.p,
              c: g.c + x,
              r: g.r + y,
              action: TerminalAccessoryAction(type: 'key', key: l),
            ),
          );
        }
        _sel = null;
      });
    } else {
      if (_draftLayout.rows < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.terminalGridArrowsNeedTwoRows),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      final oldArrows = _draftLayout.items.where((i) => i.arrow == 1).toList();
      final targetPage = oldArrows.isNotEmpty ? oldArrows.first.p : _page;
      final candidates = _draftLayout.items.where((i) => i.arrow != 1).toList();

      var s = findFreeSpot(
        candidates,
        3,
        2,
        targetPage,
        _draftLayout.rows,
        columns: _draftLayout.columns,
      );
      var chosenPage = targetPage;
      if (s == null && _page != targetPage) {
        s = findFreeSpot(
          candidates,
          3,
          2,
          _page,
          _draftLayout.rows,
          columns: _draftLayout.columns,
        );
        chosenPage = _page;
      }
      if (s == null) {
        for (var p = 0; p < _draftLayout.pages; p++) {
          s = findFreeSpot(
            candidates,
            3,
            2,
            p,
            _draftLayout.rows,
            columns: _draftLayout.columns,
          );
          if (s != null) {
            chosenPage = p;
            break;
          }
        }
      }

      if (s == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.terminalGridArrowsNeedSpace),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      _mutateDraft(() {
        _draftLayout.items.removeWhere((i) => i.arrow == 1);
        final newGroup = AccessoryItem(
          id: 'arrows',
          t: 'g',
          l: 'arrows',
          c: s![0],
          r: s[1],
          w: 3,
          h: 2,
          p: chosenPage,
          action: const TerminalAccessoryAction(type: 'key'),
        );
        _draftLayout.items.add(newGroup);
        _page = chosenPage;
        _sel = newGroup.id;
        _st = 'key';
      });
    }
  }

  void _resetToDefault() {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.terminalGridReset),
        content: Text(context.l10n.terminalGridResetConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.l10n.terminalGridCorruptedReset),
          ),
        ],
      ),
    ).then((confirm) {
      if (confirm == true && mounted) {
        _mutateDraft(() {
          _draftLayout = TerminalAccessoryLayout.defaultLayout().project(
            _draftLayout.columns,
          );
          _page = 0;
          _sel = null;
        });
      }
    });
  }

  void _deleteCurrentPage() {
    if (_draftLayout.pages < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.terminalGridKeepAtLeastOnePage),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.terminalGridDeletePage),
        content: Text(context.l10n.terminalGridDeletePageConfirm(_page + 1)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF7B80),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    ).then((confirm) {
      if (confirm == true && mounted) {
        _mutateDraft(() {
          _draftLayout.items.removeWhere(
            (o) => o.t != 'i' && o.t != 'more' && o.p == _page,
          );
          for (final o in _draftLayout.items) {
            if (o.t != 'i' && o.t != 'more' && o.p > _page) {
              o.p--;
            }
          }
          final newPages = _draftLayout.pages - 1;
          _draftLayout = _draftLayout.copyWith(pages: newPages);
          _page = _page.clamp(0, newPages - 1);
          _sel = null;
        });
      }
    });
  }

  void _syncKeyProperties() {
    final o = _draftLayout.items.where((i) => i.id == _sel).firstOrNull;
    if (o == null) return;
    _labelCtrl.text = o.l;
    if (o.action.type == 'key') {
      _actionKeyCtrl.text = o.action.key;
      _actionModCheckboxes['CTRL'] = o.action.modifiers.contains('CTRL');
      _actionModCheckboxes['ALT'] = o.action.modifiers.contains('ALT');
      _actionModCheckboxes['SHIFT'] = o.action.modifiers.contains('SHIFT');
    } else if (o.action.type == 'text') {
      _actionTextCtrl.text = o.action.text;
      _actionAppendEnterCheckbox = o.action.appendEnter;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final barBgColor = theme.colorScheme.surfaceContainer;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final panelDuration = disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 180);

    Widget panelChild;
    if (_edit) {
      panelChild = KeyedSubtree(
        key: const ValueKey<String>('panel_edit'),
        child: FocusScope(child: _buildEditSheet(context)),
      );
    } else if (_isExpanded) {
      panelChild = KeyedSubtree(
        key: const ValueKey<String>('panel_more'),
        child: ExcludeFocus(
          excluding: true,
          child: _buildExpandedPanel(context),
        ),
      );
    } else {
      panelChild = const SizedBox.shrink(key: ValueKey<String>('panel_none'));
    }

    return PopScope(
      canPop: !_edit && !_isSaving,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _edit && !_isSaving) {
          _cancelEdit();
        }
      },
      child: Container(
        color: barBgColor,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_hasCorruptedStorage) _buildCorruptedWarning(context),
              AnimatedSwitcher(
                duration: panelDuration,
                reverseDuration: panelDuration,
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeOutCubic,
                layoutBuilder: (currentChild, previousChildren) {
                  return Stack(
                    alignment: Alignment.bottomCenter,
                    clipBehavior: Clip.none,
                    children: [
                      ...previousChildren.map(
                        (child) => IgnorePointer(
                          ignoring: true,
                          child: ExcludeFocus(
                            excluding: true,
                            child: TickerMode(enabled: false, child: child),
                          ),
                        ),
                      ),
                      ?currentChild,
                    ],
                  );
                },
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.0, 0.08),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: panelChild,
              ),
              ExcludeFocus(excluding: true, child: _buildBar(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCorruptedWarning(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 16,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.l10n.terminalGridCorruptedPrompt,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              final defaultLayout = TerminalAccessoryLayout.defaultLayout();
              final storage = ref.read(localStorageServiceProvider);
              await storage.setTerminalGridConfig(
                jsonEncode(defaultLayout.toJson()),
              );
              setState(() {
                _masterLayout = defaultLayout;
                _draftLayout = defaultLayout.copy();
                _cachedProjection = null;
                _hasCorruptedStorage = false;
              });
            },
            child: Text(context.l10n.terminalGridCorruptedReset),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Bottom Bar & Grid Board
  // ===========================================================================

  Widget _buildBar(BuildContext context) {
    final theme = Theme.of(context);
    final barBgColor = theme.colorScheme.surfaceContainer;
    final borderColor = theme.colorScheme.outlineVariant;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final pageAnimDuration = disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 160);

    return Container(
      decoration: BoxDecoration(color: barBgColor),
      foregroundDecoration: _edit
          ? null
          : BoxDecoration(
              border: Border(top: BorderSide(color: borderColor, width: 1)),
            ),
      padding: const EdgeInsets.only(top: 4, bottom: 6),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final boardWidth = constraints.maxWidth - 8;
          // In edit mode, columns is FIXED to draft columns (geometric baseline)
          final minCellW = _computeMinCellWidth(context, _masterLayout.items);
          final columns = _edit
              ? _draftLayout.columns
              : _calculateColumns(boardWidth, minCellW);
          final currentLayout = _edit
              ? _draftLayout
              : _getProjectedLayout(columns);
          final pages = currentLayout.pages;
          if (_page >= pages) {
            _page = math.max(0, pages - 1);
          }
          if (_page != _previousPage) {
            _pageDirection = _page > _previousPage ? 1 : -1;
            _previousPage = _page;
          }
          final cw = math.max(44.0, boardWidth / columns);
          final totalBoardWidth = cw * columns;
          final boardHeight = currentLayout.rows * kAccessoryCellHeight;

          Widget boardContent = SizedBox(
            width: totalBoardWidth,
            height: boardHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (_edit &&
                    _isDragMoving &&
                    _dragTargetC != null &&
                    _dragTargetR != null &&
                    _draggingId != null)
                  ..._buildDropIndicator(currentLayout, cw),

                if (_edit)
                  ...currentLayout.items
                      .where((o) => isItemVisible(o, _page))
                      .map(
                        (o) => _buildItemWidget(o, cw, currentLayout, columns),
                      )
                else
                  ClipRect(
                    child: AnimatedSwitcher(
                      duration: pageAnimDuration,
                      reverseDuration: pageAnimDuration,
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeOutCubic,
                      layoutBuilder: (currentChild, previousChildren) {
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            ...previousChildren.map(
                              (child) => IgnorePointer(
                                ignoring: true,
                                child: ExcludeFocus(
                                  excluding: true,
                                  child: TickerMode(
                                    enabled: false,
                                    child: child,
                                  ),
                                ),
                              ),
                            ),
                            ?currentChild,
                          ],
                        );
                      },
                      transitionBuilder: (child, animation) {
                        final isIncoming =
                            (child.key as ValueKey<int>?)?.value == _page;
                        return SlideTransition(
                          position: Tween<Offset>(
                            begin: isIncoming
                                ? Offset(0.2 * _pageDirection, 0.0)
                                : Offset(-0.2 * _pageDirection, 0.0),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        );
                      },
                      child: KeyedSubtree(
                        key: ValueKey<int>(_page),
                        child: SizedBox(
                          width: totalBoardWidth,
                          height: boardHeight,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: currentLayout.items
                                .where((o) => isItemVisible(o, _page))
                                .map(
                                  (o) => _buildItemWidget(
                                    o,
                                    cw,
                                    currentLayout,
                                    columns,
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ),
                    ),
                  ),

                _buildSystemKey(
                  AccessoryItem(id: 'more', t: 'more', l: '...'),
                  cw,
                  currentLayout,
                  columns,
                ),
                _buildSystemKey(
                  AccessoryItem(id: 'ime', t: 'i', l: '⌨'),
                  cw,
                  currentLayout,
                  columns,
                ),

                if (!_edit && pages > 1)
                  Positioned(
                    bottom: -5,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 120),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(math.min(pages, 7), (
                              index,
                            ) {
                              final displayDots = math.min(pages, 7);
                              final activeIndex = pages <= 7
                                  ? _page
                                  : ((_page / (pages - 1)) * (displayDots - 1))
                                        .round();
                              final isActive = index == activeIndex;
                              return Container(
                                width: isActive ? 8 : 3,
                                height: 2,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.outlineVariant
                                            .withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(1),
                                ),
                              );
                            }),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );

          if (totalBoardWidth > boardWidth) {
            boardContent = SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: _edit
                  ? const ClampingScrollPhysics()
                  : const NeverScrollableScrollPhysics(),
              child: boardContent,
            );
          }

          return SizedBox(
            height: boardHeight,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: _edit
                  ? null
                  : (details) {
                      _swipeDragDx = 0.0;
                    },
              onHorizontalDragUpdate: _edit
                  ? null
                  : (details) {
                      _swipeDragDx += details.delta.dx;
                    },
              onHorizontalDragEnd: _edit
                  ? null
                  : (details) {
                      final v = details.primaryVelocity ?? 0;
                      final dx = _swipeDragDx;
                      if (v < -200 || dx < -60) {
                        if (_page < pages - 1) {
                          setState(() => _page++);
                        }
                      } else if (v > 200 || dx > 60) {
                        if (_page > 0) {
                          setState(() => _page--);
                        }
                      }
                    },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: _edit
                    ? BoxDecoration(
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.3,
                          ),
                        ),
                      )
                    : null,
                child: boardContent,
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildDropIndicator(
    TerminalAccessoryLayout currentLayout,
    double cw,
  ) {
    final theme = Theme.of(context);
    final o = currentLayout.items.firstWhere(
      (i) => i.id == _draggingId,
      orElse: () => AccessoryItem(id: '', l: ''),
    );
    if (o.id.isEmpty) return [];

    final validBg = theme.colorScheme.primary.withValues(alpha: 0.2);
    final validBorder = theme.colorScheme.primary;
    final invalidBg = theme.colorScheme.error.withValues(alpha: 0.2);
    final invalidBorder = theme.colorScheme.error;

    return [
      Positioned(
        left: _dragTargetC! * cw,
        top: _dragTargetR! * kAccessoryCellHeight,
        width: o.w * cw,
        height: o.h * kAccessoryCellHeight,
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: _dragTargetValid ? validBg : invalidBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _dragTargetValid ? validBorder : invalidBorder,
              width: 1.5,
            ),
          ),
        ),
      ),
    ];
  }

  Widget _buildSystemKey(
    AccessoryItem item,
    double cw,
    TerminalAccessoryLayout currentLayout,
    int columns,
  ) {
    final theme = Theme.of(context);
    final q = getEffectivePos(item, currentLayout.rows, columns: columns);
    final left = q.c * cw;
    final top = q.r * kAccessoryCellHeight;
    final isIme = item.t == 'i';
    final isKeyboardActive = widget.isKeyboardActive ?? false;

    final normalBg = theme.colorScheme.surfaceContainerHigh;
    final normalFg = theme.colorScheme.onSurface;
    final activeBg = theme.colorScheme.primary;
    final activeFg = theme.colorScheme.onPrimary;

    return Positioned(
      key: isIme
          ? const Key('terminal_accessory_keyboard_button')
          : const Key('terminal_accessory_more_button'),
      left: left,
      top: top,
      width: cw,
      height: kAccessoryCellHeight,
      child: _AccessoryKeyFeedback(
        onTap: () {
          if (_edit) return;
          if (isIme) {
            widget.onToggleKeyboard?.call();
          } else {
            setState(() => _isExpanded = !_isExpanded);
          }
        },
        builder: (context, isPressed) {
          final isHighlighted = isIme ? isKeyboardActive : _isExpanded;
          final baseBg = isHighlighted ? activeBg : normalBg;
          final effectiveBg = isPressed
              ? Color.lerp(baseBg, theme.colorScheme.primary, 0.35)!
              : baseBg;
          final fg = isHighlighted ? activeFg : normalFg;
          final animDuration =
              MediaQuery.maybeDisableAnimationsOf(context) ?? false
              ? Duration.zero
              : const Duration(milliseconds: 120);

          if (isIme) {
            return Tooltip(
              message: context.l10n.terminalToggleKeyboard,
              child: Semantics(
                button: true,
                label: context.l10n.terminalToggleKeyboard,
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: AnimatedContainer(
                    duration: animDuration,
                    curve: Curves.easeOutCubic,
                    decoration: BoxDecoration(
                      color: effectiveBg,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: isPressed
                          ? const []
                          : const [
                              BoxShadow(
                                color: Color(0x66000000),
                                offset: Offset(0, 1),
                                blurRadius: 0,
                              ),
                            ],
                    ),
                    alignment: Alignment.center,
                    child: Text('⌨', style: TextStyle(fontSize: 16, color: fg)),
                  ),
                ),
              ),
            );
          }

          return Tooltip(
            message: context.l10n.navMore,
            child: Semantics(
              button: true,
              label:
                  '${context.l10n.navMore}, ${context.l10n.terminalGridCurrentPage} ${_page + 1}/${currentLayout.pages}',
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: AnimatedContainer(
                  duration: animDuration,
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    color: effectiveBg,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: isPressed
                        ? const []
                        : const [
                            BoxShadow(
                              color: Color(0x66000000),
                              offset: Offset(0, 1),
                              blurRadius: 0,
                            ),
                          ],
                  ),
                  alignment: Alignment.center,
                  child: currentLayout.pages > 1
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.more_horiz, size: 14, color: fg),
                            Text(
                              '${_page + 1}/${currentLayout.pages}',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: isHighlighted
                                    ? activeFg
                                    : const Color(0xFF8FB4FF),
                                height: 1.0,
                              ),
                            ),
                          ],
                        )
                      : Icon(Icons.more_horiz, size: 18, color: fg),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildItemWidget(
    AccessoryItem o,
    double cw,
    TerminalAccessoryLayout currentLayout,
    int columns,
  ) {
    if (o.t == 'i' || o.t == 'more') return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isSelected = _edit && _sel == o.id;
    final isDragging = _edit && _draggingId == o.id;

    double left = o.c * cw;
    double top = o.r * kAccessoryCellHeight;

    final width = o.w * cw;
    final height = o.h * kAccessoryCellHeight;

    if (o.t == 'g') {
      return Positioned(
        key: Key('terminal_accessory_positioned_${o.id}'),
        left: left,
        top: top,
        width: width,
        height: height,
        child: KeyedSubtree(
          key: const Key('terminal_accessory_key_ARROWS'),
          child: _AccessoryItemTransform(
            key: ValueKey('trans_${o.id}'),
            itemId: o.id,
            dragOffset: isDragging ? (_dragOffset ?? Offset.zero) : Offset.zero,
            isDragging: isDragging,
            settleStartOffset: _settlingId == o.id ? _settleStartOffset : null,
            settleGeneration: _settlingId == o.id ? _settleGeneration : 0,
            onSettleComplete: () {
              if (_settlingId == o.id) {
                _settlingId = null;
                _settleStartOffset = null;
              }
            },
            child: Opacity(
              opacity: isDragging ? 0.85 : 1.0,
              child: _buildArrowGroup(
                o,
                cw,
                isSelected,
                currentLayout,
                columns,
              ),
            ),
          ),
        ),
      );
    }

    // Decouple display label from actual modifiers: check o.action.type and o.action.key!
    final isModifier = o.action.type == 'modifier';
    final modKey = o.action.key.toUpperCase();

    final isLocked =
        (modKey == 'CTRL' && widget.ctrlState == ModifierLockState.locked) ||
        (modKey == 'ALT' && widget.altState == ModifierLockState.locked) ||
        (modKey == 'SHIFT' && widget.shiftState == ModifierLockState.locked) ||
        (modKey == 'FN' && widget.fnState == ModifierLockState.locked);

    final isOneShot =
        (modKey == 'CTRL' && widget.ctrlState == ModifierLockState.oneShot) ||
        (modKey == 'ALT' && widget.altState == ModifierLockState.oneShot) ||
        (modKey == 'SHIFT' && widget.shiftState == ModifierLockState.oneShot) ||
        (modKey == 'FN' && widget.fnState == ModifierLockState.oneShot);

    final isHeld =
        (modKey == 'CTRL' && widget.isCtrlHeld) ||
        (modKey == 'ALT' && widget.isAltHeld) ||
        (modKey == 'SHIFT' && widget.isShiftHeld) ||
        (modKey == 'FN' && widget.isFnHeld);

    final isAct =
        _mods.contains(modKey) ||
        isLocked ||
        isOneShot ||
        isHeld ||
        (modKey == 'CTRL' && widget.isCtrlActive) ||
        (modKey == 'ALT' && widget.isAltActive);

    final isArrowSingle =
        o.arrow == 1 || const ['↑', '↓', '←', '→'].contains(o.action.key);
    final displayLabel = formatKeyLabel(o.l);
    final isPaste =
        o.action.type == 'paste' || o.action.key.toUpperCase() == 'PASTE';
    final isUnsupported = !o.action.supported;

    Color buttonColor;
    Color textColor;
    Border? modBorder;
    bool showLock = false;
    bool showOneShotDot = false;

    if (isUnsupported) {
      buttonColor = isDark
          ? const Color(0xFF22262E)
          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);
      textColor = isDark ? const Color(0xFF666E7F) : theme.colorScheme.outline;
    } else if (isModifier) {
      if (isLocked) {
        buttonColor = theme.colorScheme.primary;
        textColor = theme.colorScheme.onPrimary;
        modBorder = Border.all(
          color: theme.colorScheme.onPrimary.withValues(alpha: 0.7),
          width: 1.5,
        );
        showLock = true;
      } else if (isHeld) {
        buttonColor = theme.colorScheme.primary;
        textColor = theme.colorScheme.onPrimary;
      } else if (isOneShot) {
        buttonColor = theme.colorScheme.primaryContainer;
        textColor = theme.colorScheme.onPrimaryContainer;
        modBorder = Border.all(color: theme.colorScheme.primary, width: 1.5);
        showOneShotDot = true;
      } else {
        buttonColor = isAct
            ? theme.colorScheme.primary
            : theme.colorScheme.surfaceContainerHigh;
        textColor = isAct
            ? theme.colorScheme.onPrimary
            : theme.colorScheme.onSurface;
      }
    } else if (isArrowSingle) {
      if (currentLayout.directionSeedColor != null) {
        final scheme = ColorScheme.fromSeed(
          seedColor: Color(currentLayout.directionSeedColor!),
          brightness: theme.brightness,
        );
        buttonColor = scheme.secondaryContainer;
        textColor = scheme.onSecondaryContainer;
      } else {
        buttonColor = theme.colorScheme.surfaceContainerHigh;
        textColor = theme.colorScheme.onSurface;
      }
    } else {
      buttonColor = isAct
          ? theme.colorScheme.primary
          : theme.colorScheme.surfaceContainerHigh;
      textColor = isAct
          ? theme.colorScheme.onPrimary
          : theme.colorScheme.onSurface;
    }

    final animDuration = MediaQuery.maybeDisableAnimationsOf(context) ?? false
        ? Duration.zero
        : const Duration(milliseconds: 120);

    final keyContainer = Padding(
      padding: const EdgeInsets.all(2),
      child: AnimatedContainer(
        duration: animDuration,
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: buttonColor,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isHeld
              ? const []
              : const [
                  BoxShadow(
                    color: Color(0x66000000),
                    offset: Offset(0, 1),
                    blurRadius: 0,
                  ),
                ],
          border: _edit
              ? (isSelected
                    ? Border.all(color: theme.colorScheme.primary, width: 2)
                    : Border.all(
                        color: theme.colorScheme.outlineVariant,
                        style: BorderStyle.solid,
                        width: 1,
                      ))
              : (isModifier ? modBorder : null),
        ),
        alignment: Alignment.center,
        child: isPaste
            ? Icon(Icons.content_paste, size: 16, color: textColor)
            : Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      displayLabel,
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: fontSizeForLabel(displayLabel),
                        fontWeight: FontWeight.w600,
                        color: textColor,
                        decoration: isUnsupported
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (showLock)
                    Positioned(
                      top: 2,
                      right: 2,
                      child: Icon(Icons.lock, size: 9, color: textColor),
                    )
                  else if (showOneShotDot)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: textColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );

    Widget itemInteractive;
    if (_edit) {
      itemInteractive = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() {
            _sel = o.id;
            _st = 'key';
            _syncKeyProperties();
          });
        },
        onPanStart: (d) {
          setState(() {
            _draggingId = o.id;
            _dragOffset = Offset.zero;
            _isDragMoving = false;
            _sel = o.id;
            _st = 'key';
            _syncKeyProperties();
            _dragTargetC = o.c;
            _dragTargetR = o.r;
            _dragTargetValid = true;
            _settlingId = null;
            _settleStartOffset = null;
          });
        },
        onPanUpdate: (d) {
          setState(() {
            _dragOffset = (_dragOffset ?? Offset.zero) + d.delta;
            if (_dragOffset!.distance >= 6) {
              _isDragMoving = true;
            }
            final newL = o.c * cw + _dragOffset!.dx;
            final newT = o.r * kAccessoryCellHeight + _dragOffset!.dy;

            // Cross-page dragging trigger
            if (newL < -16 && _page > 0) {
              _page--;
              _dragOffset = Offset(cw * (columns - o.w), _dragOffset!.dy);
            } else if (newL > columns * cw + 16 &&
                _page < currentLayout.pages - 1) {
              _page++;
              _dragOffset = Offset(-cw * o.w, _dragOffset!.dy);
            }

            _dragTargetC = ((newL / cw).round()).clamp(0, columns - o.w);
            _dragTargetR = ((newT / kAccessoryCellHeight).round()).clamp(
              0,
              currentLayout.rows - o.h,
            );

            final collision = checkCollision(
              currentLayout.items,
              o,
              _dragTargetC!,
              _dragTargetR!,
              o.w,
              o.h,
              _page,
              currentLayout.rows,
              columns: columns,
            );
            if (!collision) {
              _dragTargetValid = true;
            } else {
              final p = currentLayout.items
                  .where(
                    (item) =>
                        item != o &&
                        item.t != 'i' &&
                        item.t != 'more' &&
                        item.p == _page &&
                        _dragTargetC! < item.c + item.w &&
                        _dragTargetC! + o.w > item.c &&
                        _dragTargetR! < item.r + item.h &&
                        _dragTargetR! + o.h > item.r,
                  )
                  .firstOrNull;
              _dragTargetValid =
                  (p != null &&
                  canSwapAccessoryItems(
                    currentLayout.items,
                    o,
                    p,
                    currentLayout.rows,
                    columns: columns,
                  ));
            }
          });
        },
        onPanEnd: (d) {
          if (_isDragMoving &&
              _dragOffset != null &&
              _dragTargetC != null &&
              _dragTargetR != null) {
            final targetC = _dragTargetC!;
            final targetR = _dragTargetR!;
            final oldC = o.c;
            final oldR = o.r;
            final oldLeft = oldC * cw;
            final oldTop = oldR * kAccessoryCellHeight;
            final dragOffsetSnapshot = _dragOffset!;

            if (!checkCollision(
              currentLayout.items,
              o,
              targetC,
              targetR,
              o.w,
              o.h,
              _page,
              currentLayout.rows,
              columns: columns,
            )) {
              _mutateDraft(() {
                o.p = _page;
                o.c = targetC;
                o.r = targetR;
              });
            } else {
              final p = currentLayout.items
                  .where(
                    (item) =>
                        item != o &&
                        item.t != 'i' &&
                        item.t != 'more' &&
                        item.p == _page &&
                        targetC < item.c + item.w &&
                        targetC + o.w > item.c &&
                        targetR < item.r + item.h &&
                        targetR + o.h > item.r,
                  )
                  .firstOrNull;
              if (p != null &&
                  canSwapAccessoryItems(
                    currentLayout.items,
                    o,
                    p,
                    currentLayout.rows,
                    columns: columns,
                  )) {
                _mutateDraft(() {
                  o.p = _page;
                  final prevC = o.c, prevR = o.r;
                  o.c = p.c;
                  o.r = p.r;
                  p.c = prevC;
                  p.r = prevR;
                });
              } else {
                _page = o.p;
              }
            }

            final newLeft = o.c * cw;
            final newTop = o.r * kAccessoryCellHeight;
            final startOffset = Offset(
              oldLeft + dragOffsetSnapshot.dx - newLeft,
              oldTop + dragOffsetSnapshot.dy - newTop,
            );

            setState(() {
              _draggingId = null;
              _dragOffset = null;
              _isDragMoving = false;
              _dragTargetC = null;
              _dragTargetR = null;
              _settlingId = o.id;
              _settleStartOffset = startOffset;
              _settleGeneration++;
            });
          } else {
            _page = o.p;
            setState(() {
              _draggingId = null;
              _dragOffset = null;
              _isDragMoving = false;
              _dragTargetC = null;
              _dragTargetR = null;
            });
          }
        },
        child: keyContainer,
      );
    } else if (isArrowSingle) {
      final scheme = currentLayout.directionSeedColor != null
          ? ColorScheme.fromSeed(
              seedColor: Color(currentLayout.directionSeedColor!),
              brightness: theme.brightness,
            )
          : null;
      final itemPage = o.p;
      itemInteractive = _ArrowKeyCell(
        label: displayLabel,
        scheme: scheme,
        theme: theme,
        isEdit: _edit,
        canRepeat: () => !_edit && _page == itemPage && _canRepeat(),
        onPressed: () {
          if (!_edit && _page == itemPage) {
            _press(o);
          }
        },
      );
    } else if (isModifier) {
      itemInteractive = _ModifierKeyButton(
        label: modKey,
        state: modKey == 'CTRL'
            ? widget.ctrlState
            : (modKey == 'ALT'
                  ? widget.altState
                  : (modKey == 'SHIFT'
                        ? widget.shiftState
                        : (modKey == 'FN' ? widget.fnState : null))),
        onTap: widget.inputEnabled ? () => _press(o) : null,
        onLongPress: widget.inputEnabled
            ? (modKey == 'CTRL'
                  ? widget.onLockCtrl
                  : (modKey == 'ALT'
                        ? widget.onLockAlt
                        : (modKey == 'SHIFT'
                              ? widget.onLockShift
                              : (modKey == 'FN' ? widget.onLockFn : null))))
            : null,
        onModifierDown: widget.inputEnabled ? widget.onModifierDown : null,
        onModifierUp: widget.inputEnabled ? widget.onModifierUp : null,
        onModifierCancel: widget.onModifierCancel,
        isHeld: isHeld,
        isActive: isAct,
        isOwnerMounted: () => mounted,
        child: keyContainer,
      );
    } else {
      itemInteractive = _AccessoryKeyFeedback(
        onTap: () => _press(o),
        builder: (context, isPressed) {
          final effectiveBg = isPressed
              ? Color.lerp(buttonColor, theme.colorScheme.primary, 0.25)!
              : buttonColor;
          return Padding(
            padding: const EdgeInsets.all(2),
            child: AnimatedContainer(
              duration: animDuration,
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                color: effectiveBg,
                borderRadius: BorderRadius.circular(8),
                boxShadow: isPressed
                    ? const []
                    : const [
                        BoxShadow(
                          color: Color(0x66000000),
                          offset: Offset(0, 1),
                          blurRadius: 0,
                        ),
                      ],
              ),
              alignment: Alignment.center,
              child: isPaste
                  ? Icon(Icons.content_paste, size: 16, color: textColor)
                  : Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(
                            displayLabel,
                            style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: fontSizeForLabel(displayLabel),
                              fontWeight: FontWeight.w600,
                              color: textColor,
                              decoration: isUnsupported
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
            ),
          );
        },
      );
    }

    final keyName =
        (isModifier ||
            const [
              'ESC',
              'TAB',
              'CTRL',
              'ALT',
              'SHIFT',
              'PASTE',
              'FN',
            ].contains(o.action.key.toUpperCase()))
        ? o.action.key.toUpperCase()
        : o.l;

    return Positioned(
      key: Key('terminal_accessory_positioned_${o.id}'),
      left: left,
      top: top,
      width: width,
      height: height,
      child: KeyedSubtree(
        key: Key('terminal_accessory_key_$keyName'),
        child: _AccessoryItemTransform(
          key: ValueKey('trans_${o.id}'),
          itemId: o.id,
          dragOffset: isDragging ? (_dragOffset ?? Offset.zero) : Offset.zero,
          isDragging: isDragging,
          settleStartOffset: _settlingId == o.id ? _settleStartOffset : null,
          settleGeneration: _settlingId == o.id ? _settleGeneration : 0,
          onSettleComplete: () {
            if (_settlingId == o.id) {
              _settlingId = null;
              _settleStartOffset = null;
            }
          },
          child: Opacity(
            opacity: isDragging ? 0.85 : 1.0,
            child: itemInteractive,
          ),
        ),
      ),
    );
  }

  Widget _buildArrowGroup(
    AccessoryItem o,
    double cw,
    bool isSelected,
    TerminalAccessoryLayout currentLayout,
    int columns,
  ) {
    final theme = Theme.of(context);
    final scheme = currentLayout.directionSeedColor != null
        ? ColorScheme.fromSeed(
            seedColor: Color(currentLayout.directionSeedColor!),
            brightness: theme.brightness,
          )
        : null;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (_edit) {
          setState(() {
            _sel = o.id;
            _st = 'key';
          });
        }
      },
      onPanStart: !_edit
          ? null
          : (d) {
              setState(() {
                _draggingId = o.id;
                _dragOffset = Offset.zero;
                _isDragMoving = false;
                _sel = o.id;
                _st = 'key';
                _dragTargetC = o.c;
                _dragTargetR = o.r;
                _dragTargetValid = true;
                _settlingId = null;
                _settleStartOffset = null;
              });
            },
      onPanUpdate: !_edit
          ? null
          : (d) {
              setState(() {
                _dragOffset = (_dragOffset ?? Offset.zero) + d.delta;
                if (_dragOffset!.distance >= 6) {
                  _isDragMoving = true;
                }
                final newL = o.c * cw + _dragOffset!.dx;
                final newT = o.r * kAccessoryCellHeight + _dragOffset!.dy;
                _dragTargetC = ((newL / cw).round()).clamp(0, columns - 3);
                _dragTargetR = ((newT / kAccessoryCellHeight).round()).clamp(
                  0,
                  currentLayout.rows - 2,
                );
                _dragTargetValid = !checkCollision(
                  currentLayout.items,
                  o,
                  _dragTargetC!,
                  _dragTargetR!,
                  3,
                  2,
                  _page,
                  currentLayout.rows,
                  columns: columns,
                );
              });
            },
      onPanEnd: !_edit
          ? null
          : (d) {
              if (_isDragMoving &&
                  _dragOffset != null &&
                  _dragTargetC != null &&
                  _dragTargetR != null) {
                final targetC = _dragTargetC!;
                final targetR = _dragTargetR!;
                final oldLeft = o.c * cw;
                final oldTop = o.r * kAccessoryCellHeight;
                final dragOffsetSnapshot = _dragOffset!;

                if (!checkCollision(
                  currentLayout.items,
                  o,
                  targetC,
                  targetR,
                  3,
                  2,
                  _page,
                  currentLayout.rows,
                  columns: columns,
                )) {
                  _mutateDraft(() {
                    o.c = targetC;
                    o.r = targetR;
                  });
                }

                final newLeft = o.c * cw;
                final newTop = o.r * kAccessoryCellHeight;
                final startOffset = Offset(
                  oldLeft + dragOffsetSnapshot.dx - newLeft,
                  oldTop + dragOffsetSnapshot.dy - newTop,
                );

                setState(() {
                  _draggingId = null;
                  _dragOffset = null;
                  _isDragMoving = false;
                  _dragTargetC = null;
                  _dragTargetR = null;
                  _settlingId = o.id;
                  _settleStartOffset = startOffset;
                  _settleGeneration++;
                });
              } else {
                setState(() {
                  _draggingId = null;
                  _dragOffset = null;
                  _isDragMoving = false;
                  _dragTargetC = null;
                  _dragTargetR = null;
                });
              }
            },
      child: Container(
        key: const Key('terminal_direction_pad'),
        decoration: _edit
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: isSelected
                    ? Border.all(color: theme.colorScheme.primary, width: 2)
                    : Border.all(
                        color: theme.colorScheme.outlineVariant,
                        width: 1,
                      ),
              )
            : null,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(
            children: kArrowOffsets.map((arr) {
              final label = arr[0] as String;
              final x = arr[1] as int;
              final y = arr[2] as int;

              return Positioned(
                left: x * cw,
                top: y * kAccessoryCellHeight,
                width: cw,
                height: kAccessoryCellHeight,
                child: _ArrowKeyCell(
                  label: label,
                  containerKey: Key('terminal_accessory_key_$label'),
                  scheme: scheme,
                  theme: theme,
                  isEdit: _edit,
                  canRepeat: () => !_edit && _page == o.p && _canRepeat(),
                  onPressed: () {
                    if (!_edit && _page == o.p) {
                      _press(
                        AccessoryItem(
                          id: 'temp',
                          l: label,
                          s: label,
                          action: TerminalAccessoryAction(
                            type: 'key',
                            key: label,
                          ),
                        ),
                      );
                    }
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // Quick More / Expanded Categories
  // ===========================================================================

  Widget _buildExpandedPanel(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final panelBg = scheme.surfaceContainerHigh;
    final borderCol = scheme.outlineVariant;

    final categories = [
      ('Nav', context.l10n.terminalCategoryNav),
      ('Edit', context.l10n.terminalCategoryEdit),
      ('Sym', context.l10n.terminalCategorySym),
      ('Fn', 'Fn'),
    ];

    // Page count strictly from projected layout
    final width = MediaQuery.sizeOf(context).width;
    final boardWidth = width - 8;
    final minCellW = _computeMinCellWidth(context, _masterLayout.items);
    final columns = _calculateColumns(boardWidth, minCellW);
    final pages = _getProjectedLayout(columns).pages;

    return Container(
      decoration: BoxDecoration(
        color: panelBg,
        border: Border(bottom: BorderSide(color: borderCol, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (pages > 1) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Text(
                    context.l10n.terminalGridCurrentPage,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 6),
                  ...List.generate(pages, (p) {
                    final isCurrent = p == _page;
                    return Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: GestureDetector(
                        onTap: () => setState(() => _page = p),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? scheme.primary
                                : scheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${p + 1}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isCurrent
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isCurrent
                                  ? scheme.onPrimary
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 6),
          ],
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  side: BorderSide(color: scheme.primary),
                ),
                onPressed: () {
                  final boardWidth = MediaQuery.of(context).size.width - 8;
                  final minW = _computeMinCellWidth(
                    context,
                    _masterLayout.items,
                  );
                  _enterEditMode(_calculateColumns(boardWidth, minW));
                },
                icon: Icon(Icons.tune, size: 14, color: scheme.primary),
                label: Text(
                  context.l10n.terminalGridEditLayout,
                  softWrap: true,
                  style: TextStyle(fontSize: 12, color: scheme.primary),
                ),
              ),
              if (widget.onClearModifiers != null)
                OutlinedButton.icon(
                  key: const Key('terminal_clear_modifiers_button'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    side: BorderSide(color: scheme.outlineVariant),
                  ),
                  onPressed: () {
                    widget.onClearModifiers?.call();
                    setState(() {});
                  },
                  icon: Icon(
                    Icons.clear_all,
                    size: 14,
                    color: scheme.onSurfaceVariant,
                  ),
                  label: Text(
                    context.l10n.terminalClearAllModifiers,
                    softWrap: true,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              Tooltip(
                key: const Key('terminal_accessory_help_button'),
                message: context.l10n.terminalModifierHelp,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: Icon(
                    Icons.help_outline,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _isExpanded = false),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: Icon(
                    Icons.close,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Category Pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: categories.map((entry) {
                final key = entry.$1;
                final localizedLabel = entry.$2;
                final isSelected = _expandedCategory == key;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _AccessoryKeyFeedback(
                    onTap: () => setState(() => _expandedCategory = key),
                    builder: (context, isPressed) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? scheme.primary.withValues(alpha: 0.15)
                              : (isPressed
                                    ? scheme.surfaceContainerHighest
                                    : Colors.transparent),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? scheme.primary
                                : scheme.outlineVariant,
                          ),
                        ),
                        child: Text(
                          localizedLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _buildExpandedCategoryKeys(context, _expandedCategory),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildExpandedCategoryKeys(BuildContext context, String cat) {
    if (cat == 'Nav') {
      return ['HOME', 'END', 'PGUP', 'PGDN'].map((k) {
        return _buildQuickKey(k, () => _handleQuickKey(k));
      }).toList();
    }
    if (cat == 'Edit') {
      return [
        'Ctrl+C',
        'Ctrl+D',
        'Ctrl+A',
        'Ctrl+E',
        'Ctrl+U',
        'Ctrl+W',
        'Ctrl+Z',
        'INSERT',
        'DELETE',
        'BACKSPACE',
        'ENTER',
      ].map((k) {
        return _buildQuickKey(k, () => _handleQuickKey(k));
      }).toList();
    }
    if (cat == 'Sym') {
      return ['/', '-', '_', '|', '~', '.', ':', '='].map((k) {
        return _buildQuickKey(k, () => _handleQuickKey(k));
      }).toList();
    }
    if (cat == 'Fn') {
      return [
        _buildQuickModifierKey('FN'),
        ...List.generate(
          12,
          (i) => 'F${i + 1}',
        ).map((k) => _buildQuickKey(k, () => _handleQuickKey(k))),
      ];
    }
    return [];
  }

  Widget _buildQuickKey(String label, VoidCallback onTap) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 6, bottom: 2),
      child: _AccessoryKeyFeedback(
        onTap: onTap,
        builder: (context, isPressed) {
          final bgColor = isPressed
              ? Color.lerp(
                  scheme.surfaceContainerHighest,
                  scheme.primary,
                  0.25,
                )!
              : scheme.surfaceContainerHighest;
          final animDuration =
              MediaQuery.maybeDisableAnimationsOf(context) ?? false
              ? Duration.zero
              : const Duration(milliseconds: 120);
          return AnimatedContainer(
            key: Key('terminal_accessory_key_$label'),
            duration: animDuration,
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isPressed ? scheme.primary : scheme.outlineVariant,
              ),
              boxShadow: isPressed
                  ? const []
                  : const [
                      BoxShadow(
                        color: Color(0x33000000),
                        offset: Offset(0, 1),
                        blurRadius: 0,
                      ),
                    ],
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'JetBrains Mono',
                fontWeight: FontWeight.bold,
                color: isPressed ? scheme.primary : scheme.onSurface,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickModifierKey(String modifier) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final upper = modifier.toUpperCase();
    final state = upper == 'FN' ? widget.fnState : null;
    final isLocked = state == ModifierLockState.locked;
    final isOneShot = state == ModifierLockState.oneShot;
    final isHeld = upper == 'FN' ? widget.isFnHeld : false;
    final isAct = isLocked || isOneShot || isHeld || _mods.contains(modifier);

    Color buttonColor;
    Color textColor;
    Border? border;
    if (isLocked) {
      buttonColor = scheme.primary;
      textColor = scheme.onPrimary;
      border = Border.all(
        color: scheme.onPrimary.withValues(alpha: 0.7),
        width: 1.5,
      );
    } else if (isHeld) {
      buttonColor = scheme.primary;
      textColor = scheme.onPrimary;
      border = Border.all(color: scheme.primary);
    } else if (isOneShot) {
      buttonColor = scheme.primaryContainer;
      textColor = scheme.onPrimaryContainer;
      border = Border.all(color: scheme.primary, width: 1.5);
    } else {
      buttonColor = isAct ? scheme.primary : scheme.surfaceContainerHighest;
      textColor = isAct ? scheme.onPrimary : scheme.onSurface;
      border = Border.all(
        color: isAct ? scheme.primary : scheme.outlineVariant,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(right: 6, bottom: 2),
      child: _ModifierKeyButton(
        label: modifier,
        state: state,
        onTap: widget.inputEnabled
            ? () {
                if (upper == 'FN') widget.onToggleFn?.call();
              }
            : null,
        onLongPress: widget.inputEnabled && upper == 'FN'
            ? widget.onLockFn
            : null,
        onModifierDown: widget.inputEnabled ? widget.onModifierDown : null,
        onModifierUp: widget.inputEnabled ? widget.onModifierUp : null,
        onModifierCancel: widget.onModifierCancel,
        isHeld: isHeld,
        isActive: isAct,
        isOwnerMounted: () => mounted,
        child: AnimatedContainer(
          key: Key('terminal_accessory_key_$upper'),
          duration: MediaQuery.maybeDisableAnimationsOf(context) ?? false
              ? Duration.zero
              : const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: buttonColor,
            borderRadius: BorderRadius.circular(6),
            border: border,
            boxShadow: isHeld
                ? const []
                : const [
                    BoxShadow(
                      color: Color(0x33000000),
                      offset: Offset(0, 1),
                      blurRadius: 0,
                    ),
                  ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                modifier,
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'JetBrains Mono',
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              if (isLocked) ...[
                const SizedBox(width: 3),
                Icon(Icons.lock, size: 10, color: textColor),
              ] else if (isOneShot) ...[
                const SizedBox(width: 3),
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: textColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _handleQuickKey(String key) {
    final item = AccessoryItem(id: 'quick-$key', l: key, s: key);
    _press(item);
  }

  // ===========================================================================
  // Edit Sheet (Draft Management)
  // ===========================================================================

  Widget _buildEditSheet(BuildContext context) {
    final mediaQuery = MediaQuery.maybeOf(context);
    final screenHeight = mediaQuery?.size.height ?? 800.0;
    final viewInsetsBottom = mediaQuery?.viewInsets.bottom ?? 0.0;
    final safeArea = mediaQuery?.padding ?? EdgeInsets.zero;
    final baseBarHeight = TerminalAccessoryBar.calculateBaseHeight(
      _draftLayout.rows,
    );
    const spacing = 16.0;
    final availableHeight =
        screenHeight -
        viewInsetsBottom -
        safeArea.top -
        safeArea.bottom -
        baseBarHeight -
        spacing;
    final safeHeight = availableHeight.clamp(0.0, 320.0);

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      constraints: BoxConstraints(maxHeight: safeHeight),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(top: BorderSide(color: scheme.outlineVariant, width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Actions Row: Cancel, Undo, Save
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                TextButton(
                  onPressed: _isSaving ? null : _cancelEdit,
                  child: Text(
                    context.l10n.cancel,
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: context.l10n.terminalGridUndo,
                      onPressed: (_undoStack.isNotEmpty && !_isSaving)
                          ? _undo
                          : null,
                      icon: Icon(
                        Icons.undo,
                        size: 18,
                        color: (_undoStack.isNotEmpty && !_isSaving)
                            ? scheme.primary
                            : scheme.outline,
                      ),
                    ),
                    const SizedBox(width: 4),
                    FilledButton(
                      key: const Key('terminal_grid_save_button'),
                      style: FilledButton.styleFrom(
                        backgroundColor: scheme.primary,
                        foregroundColor: scheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                      ),
                      onPressed: _isSaving ? null : _saveEdit,
                      child: _isSaving
                          ? SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: scheme.onPrimary,
                              ),
                            )
                          : Text(
                              context.l10n.terminalGridSave,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Segments Row
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
            child: Container(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.all(2),
              child: Row(
                children: [
                  _buildSegmentButton('add', context.l10n.terminalGridAddTab),
                  _buildSegmentButton('key', context.l10n.terminalGridKeyTab),
                  _buildSegmentButton('set', context.l10n.terminalGridSetTab),
                ],
              ),
            ),
          ),
          // Pager Row (wrapped in horizontal scroll to prevent overflow)
          Container(
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Text(
                    context.l10n.terminalGridCurrentPage,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildSmallButton('‹', () {
                    if (_page > 0) {
                      setState(() => _page--);
                    }
                  }),
                  Container(
                    constraints: const BoxConstraints(minWidth: 36),
                    alignment: Alignment.center,
                    child: Text(
                      '${_page + 1} / ${_draftLayout.pages}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  _buildSmallButton('›', () {
                    if (_page < _draftLayout.pages - 1) {
                      setState(() => _page++);
                    }
                  }),
                  const SizedBox(width: 12),
                  _buildSmallButton(context.l10n.terminalGridAddPage, () {
                    _mutateDraft(() {
                      final newPages = _draftLayout.pages + 1;
                      _draftLayout = _draftLayout.copyWith(pages: newPages);
                      _page = newPages - 1;
                    });
                  }),
                  const SizedBox(width: 6),
                  _buildSmallButton(
                    context.l10n.terminalGridDeletePage,
                    _deleteCurrentPage,
                    isDanger: true,
                  ),
                ],
              ),
            ),
          ),
          // Body of Sheet
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: _buildSheetBody(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentButton(String key, String text) {
    final scheme = Theme.of(context).colorScheme;
    final isOn = _st == key;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() {
            _st = key;
          });
        },
        child: Container(
          decoration: BoxDecoration(
            color: isOn
                ? scheme.primary.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(vertical: 6),
          alignment: Alignment.center,
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isOn ? FontWeight.w600 : FontWeight.normal,
              color: isOn ? scheme.primary : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSmallButton(
    String text,
    VoidCallback onPressed, {
    bool isDanger = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: isDanger ? scheme.error : scheme.onSurface,
            fontWeight: isDanger ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildSheetBody(BuildContext context) {
    switch (_st) {
      case 'add':
        return _buildTabAdd(context);
      case 'key':
        return _buildTabKey(context);
      case 'set':
        return _buildTabSet(context);
      default:
        return const SizedBox.shrink();
    }
  }

  // ---------------------------------------------------------------------------
  // Tab 1: 添加 (Add Keys with Search)
  // ---------------------------------------------------------------------------

  Widget _buildTabAdd(BuildContext context) {
    final categoryList = [
      ('common', context.l10n.terminalCategoryCommon),
      ('ctrl', 'Ctrl+'),
      ('alt', 'Alt+'),
      ('fkeys', 'F1-F12'),
      ('nav', context.l10n.terminalCategoryNav),
      ('sym', context.l10n.terminalCategorySym),
      ('modifiers', context.l10n.terminalCategoryModifiers),
      ('custom', context.l10n.terminalCategoryCustom),
    ];

    List<String> itemsToDisplay;
    if (_searchQuery.isNotEmpty) {
      final allPresets = kPresetSets.values
          .expand((list) => list)
          .toSet()
          .toList();
      itemsToDisplay = allPresets
          .where((k) => k.toLowerCase().contains(_searchQuery))
          .toList();
    } else {
      itemsToDisplay = kPresetSets[_cat] ?? [];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Preset Search Bar
        TextField(
          controller: _searchCtrl,
          autofocus: false,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          decoration: InputDecoration(
            isDense: true,
            hintText: context.l10n.terminalSearchPresets,
            hintStyle: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            prefixIcon: Icon(
              Icons.search,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 6,
            ),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
          onChanged: (val) {
            setState(() {
              _searchQuery = val.trim().toLowerCase();
            });
          },
        ),
        const SizedBox(height: 8),

        // Category Pills (shown when not searching)
        if (_searchQuery.isEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: categoryList.map((entry) {
                final k = entry.$1;
                final localizedName = entry.$2;
                final isOn = _cat == k;
                final theme = Theme.of(context);
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => setState(() => _cat = k),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isOn
                            ? theme.colorScheme.primary.withValues(alpha: 0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isOn
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outlineVariant,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 3,
                      ),
                      child: Text(
                        localizedName,
                        style: TextStyle(
                          fontSize: 12,
                          color: isOn
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                          fontWeight: isOn
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        const SizedBox(height: 8),

        if (_searchQuery.isNotEmpty || _cat != 'custom') ...[
          _buildPresetGrid(itemsToDisplay),
        ] else ...[
          _buildCustomSection(context),
        ],
      ],
    );
  }

  Widget _buildPresetGrid(List<String> list) {
    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            context.l10n.terminalSearchNoMatch,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    const perPage = 12;
    final pageCount = (list.length / perPage).ceil();

    return SizedBox(
      height: 140,
      child: PageView.builder(
        itemCount: pageCount,
        itemBuilder: (context, pageIndex) {
          final start = pageIndex * perPage;
          final subList = list.sublist(
            start,
            math.min(start + perPage, list.length),
          );

          return GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 2.1,
            ),
            itemCount: subList.length,
            itemBuilder: (context, index) {
              final label = subList[index];
              return GestureDetector(
                onTap: () {
                  final isMod = kModifierNames.contains(label);
                  _placeItem(
                    AccessoryItem(
                      id: 'temp',
                      l: label,
                      s: label,
                      m: isMod,
                      kind: (label.length > 1 && label.contains('+'))
                          ? 'combo'
                          : 'key',
                    ),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildCustomSection(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${context.l10n.terminalGridCustomCombo}：${context.l10n.terminalGridCustomComboHint}',
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 12,
          children: ['Ctrl', 'Alt', 'Shift'].map((m) {
            final checked = _customModCheckboxes[m] ?? false;
            return GestureDetector(
              onTap: () => setState(() => _customModCheckboxes[m] = !checked),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(
                    value: checked,
                    visualDensity: VisualDensity.compact,
                    onChanged: (v) =>
                        setState(() => _customModCheckboxes[m] = v ?? false),
                  ),
                  Text(
                    m,
                    style: TextStyle(fontSize: 12, color: scheme.onSurface),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: _customKeyCtrl,
                autofocus: false,
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 13,
                  color: scheme.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: context.l10n.terminalGridKeyHint,
                  hintStyle: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 7,
                  ),
                  filled: true,
                  fillColor: scheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: scheme.outlineVariant),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: scheme.outlineVariant),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: scheme.primary),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              flex: 2,
              child: TextField(
                controller: _customLabelCtrl,
                autofocus: false,
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 13,
                  color: scheme.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: context.l10n.terminalGridDisplayNameOptional,
                  hintStyle: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 7,
                  ),
                  filled: true,
                  fillColor: scheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: scheme.outlineVariant),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: scheme.outlineVariant),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: scheme.primary),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
              ),
              onPressed: () {
                var k = _customKeyCtrl.text.trim();
                if (k.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(context.l10n.terminalGridPleaseEnterKey),
                    ),
                  );
                  return;
                }
                k = k.length == 1
                    ? k.toUpperCase()
                    : k[0].toUpperCase() + k.substring(1);
                final ms = _customModCheckboxes.entries
                    .where((e) => e.value)
                    .map((e) => e.key.toUpperCase())
                    .toList();
                final s = [...ms, k].join('+');
                final l = _customLabelCtrl.text.trim().isNotEmpty
                    ? _customLabelCtrl.text.trim()
                    : s;
                _placeItem(
                  AccessoryItem(
                    id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                    l: l,
                    s: s,
                    kind: ms.isNotEmpty ? 'combo' : 'key',
                    action: TerminalAccessoryAction(
                      type: 'key',
                      key: k,
                      modifiers: ms,
                    ),
                  ),
                );
              },
              child: Text(
                context.l10n.terminalGridAddTab,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Text Macro section
        Text(
          '${context.l10n.terminalGridTextMacro}：${context.l10n.terminalGridTextMacroSubtitle}',
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              flex: 1,
              child: TextField(
                controller: _macroLabelCtrl,
                autofocus: false,
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 13,
                  color: scheme.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: context.l10n.terminalGridDisplayName,
                  hintStyle: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 7,
                  ),
                  filled: true,
                  fillColor: scheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: scheme.outlineVariant),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: scheme.outlineVariant),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: scheme.primary),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              flex: 2,
              child: TextField(
                controller: _macroTextCtrl,
                autofocus: false,
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 13,
                  color: scheme.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: context.l10n.terminalGridMacroTextHint,
                  hintStyle: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 7,
                  ),
                  filled: true,
                  fillColor: scheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: scheme.outlineVariant),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: scheme.outlineVariant),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: scheme.primary),
                  ),
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Checkbox(
                  value: _macroEnterCheckbox,
                  visualDensity: VisualDensity.compact,
                  onChanged: (v) =>
                      setState(() => _macroEnterCheckbox = v ?? false),
                ),
                Text(
                  context.l10n.terminalGridMacroAppendEnter,
                  style: TextStyle(fontSize: 12, color: scheme.onSurface),
                ),
              ],
            ),
            const SizedBox(width: 6),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
              ),
              onPressed: () {
                final t = _macroTextCtrl.text;
                if (t.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(context.l10n.terminalGridPleaseEnterText),
                    ),
                  );
                  return;
                }
                final l = _macroLabelCtrl.text.trim().isNotEmpty
                    ? _macroLabelCtrl.text.trim()
                    : (t.length > 4 ? t.substring(0, 4) : t);
                _placeItem(
                  AccessoryItem(
                    id: 'macro_${DateTime.now().millisecondsSinceEpoch}',
                    l: l,
                    s: t,
                    kind: 'text',
                    action: TerminalAccessoryAction(
                      type: 'text',
                      text: t,
                      appendEnter: _macroEnterCheckbox,
                    ),
                  ),
                );
              },
              child: Text(
                context.l10n.terminalGridAddTab,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 2: 按键 (Key Properties with Editable Action)
  // ---------------------------------------------------------------------------

  Widget _buildTabKey(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final o = _draftLayout.items.where((i) => i.id == _sel).firstOrNull;

    if (o == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            context.l10n.terminalGridSelectKeyHint,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: scheme.onSurfaceVariant,
              height: 1.6,
            ),
          ),
        ),
      );
    }

    if (o.t == 'g') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPropertyRow(
            title: context.l10n.terminalGridInvertedT,
            subtitle: context.l10n.terminalGridInvertedTSubtitle,
            trailing: _buildSmallButton(
              context.l10n.terminalGridSplitArrows,
              _toggleArrows,
            ),
          ),
          // Move to Page
          _buildPropertyRow(
            title: context.l10n.terminalGridCurrentPage,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildStepperButton('‹', () {
                  if (o.p > 0) {
                    final s = findFreeSpot(
                      _draftLayout.items,
                      o.w,
                      o.h,
                      o.p - 1,
                      _draftLayout.rows,
                      columns: _draftLayout.columns,
                    );
                    if (s != null) {
                      _mutateDraft(() {
                        o.p--;
                        o.c = s[0];
                        o.r = s[1];
                        _page = o.p;
                      });
                    }
                  }
                }),
                Container(
                  constraints: const BoxConstraints(minWidth: 32),
                  alignment: Alignment.center,
                  child: Text(
                    '${o.p + 1}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                _buildStepperButton('›', () {
                  if (o.p < _draftLayout.pages - 1) {
                    final s = findFreeSpot(
                      _draftLayout.items,
                      o.w,
                      o.h,
                      o.p + 1,
                      _draftLayout.rows,
                      columns: _draftLayout.columns,
                    );
                    if (s != null) {
                      _mutateDraft(() {
                        o.p++;
                        o.c = s[0];
                        o.r = s[1];
                        _page = o.p;
                      });
                    }
                  }
                }),
              ],
            ),
          ),
          const SizedBox(height: 10),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.errorContainer,
              foregroundColor: scheme.onErrorContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(vertical: 9),
            ),
            onPressed: () {
              _mutateDraft(() {
                _draftLayout.items.remove(o);
                _sel = null;
              });
            },
            child: Text(
              context.l10n.terminalGridDeleteArrows,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Display Name (Label)
        _buildPropertyRow(
          title: context.l10n.terminalGridDisplayName,
          trailing: SizedBox(
            width: 140,
            child: TextField(
              controller: _labelCtrl,
              autofocus: false,
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 13,
                color: scheme.onSurface,
              ),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 7,
                ),
                filled: true,
                fillColor: scheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: scheme.outlineVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: scheme.outlineVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: scheme.primary),
                ),
              ),
              onChanged: (val) {
                _mutateDraft(() {
                  o.l = val.isNotEmpty ? val : ' ';
                });
              },
            ),
          ),
        ),

        // Action Editing Section
        if (o.action.type == 'key') ...[
          _buildPropertyRow(
            title: context.l10n.terminalGridActionKey,
            trailing: SizedBox(
              width: 140,
              child: TextField(
                controller: _actionKeyCtrl,
                autofocus: false,
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 13,
                  color: scheme.onSurface,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 7,
                  ),
                  filled: true,
                  fillColor: scheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: scheme.outlineVariant),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: scheme.outlineVariant),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: scheme.primary),
                  ),
                ),
                onChanged: (val) {
                  final k = val.trim();
                  if (k.isNotEmpty) {
                    _mutateDraft(() {
                      final activeMods = _actionModCheckboxes.entries
                          .where((e) => e.value)
                          .map((e) => e.key)
                          .toList();
                      final newAction = TerminalAccessoryAction(
                        type: 'key',
                        key: k,
                        modifiers: activeMods,
                      );
                      final updated = o.copyWith(
                        action: newAction,
                        s: [...activeMods, k].join('+'),
                      );
                      final idx = _draftLayout.items.indexOf(o);
                      _draftLayout.items[idx] = updated;
                    });
                  }
                },
              ),
            ),
          ),
          _buildPropertyRow(
            title: context.l10n.terminalGridActionModifiers,
            trailing: Wrap(
              spacing: 6,
              children: ['CTRL', 'ALT', 'SHIFT'].map((m) {
                final checked = _actionModCheckboxes[m] ?? false;
                return GestureDetector(
                  onTap: () {
                    setState(() => _actionModCheckboxes[m] = !checked);
                    _mutateDraft(() {
                      final activeMods = _actionModCheckboxes.entries
                          .where((e) => e.value)
                          .map((e) => e.key)
                          .toList();
                      final newAction = TerminalAccessoryAction(
                        type: 'key',
                        key: o.action.key,
                        modifiers: activeMods,
                      );
                      final updated = o.copyWith(
                        action: newAction,
                        s: [...activeMods, o.action.key].join('+'),
                      );
                      final idx = _draftLayout.items.indexOf(o);
                      _draftLayout.items[idx] = updated;
                    });
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: checked,
                        visualDensity: VisualDensity.compact,
                        onChanged: (v) {
                          setState(() => _actionModCheckboxes[m] = v ?? false);
                          _mutateDraft(() {
                            final activeMods = _actionModCheckboxes.entries
                                .where((e) => e.value)
                                .map((e) => e.key)
                                .toList();
                            final newAction = TerminalAccessoryAction(
                              type: 'key',
                              key: o.action.key,
                              modifiers: activeMods,
                            );
                            final updated = o.copyWith(
                              action: newAction,
                              s: [...activeMods, o.action.key].join('+'),
                            );
                            final idx = _draftLayout.items.indexOf(o);
                            _draftLayout.items[idx] = updated;
                          });
                        },
                      ),
                      Text(
                        m,
                        style: TextStyle(fontSize: 11, color: scheme.onSurface),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ] else if (o.action.type == 'text') ...[
          _buildPropertyRow(
            title: context.l10n.terminalGridActionText,
            trailing: SizedBox(
              width: 140,
              child: TextField(
                controller: _actionTextCtrl,
                autofocus: false,
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 13,
                  color: scheme.onSurface,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 7,
                  ),
                  filled: true,
                  fillColor: scheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: scheme.outlineVariant),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: scheme.outlineVariant),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: scheme.primary),
                  ),
                ),
                onChanged: (val) {
                  _mutateDraft(() {
                    final newAction = TerminalAccessoryAction(
                      type: 'text',
                      text: val,
                      appendEnter: _actionAppendEnterCheckbox,
                    );
                    final updated = o.copyWith(action: newAction, s: val);
                    final idx = _draftLayout.items.indexOf(o);
                    _draftLayout.items[idx] = updated;
                  });
                },
              ),
            ),
          ),
          _buildPropertyRow(
            title: context.l10n.terminalGridMacroAppendEnter,
            trailing: Switch(
              value: _actionAppendEnterCheckbox,
              activeTrackColor: scheme.primary,
              onChanged: (v) {
                setState(() => _actionAppendEnterCheckbox = v);
                _mutateDraft(() {
                  final newAction = TerminalAccessoryAction(
                    type: 'text',
                    text: o.action.text,
                    appendEnter: v,
                  );
                  final updated = o.copyWith(action: newAction);
                  final idx = _draftLayout.items.indexOf(o);
                  _draftLayout.items[idx] = updated;
                });
              },
            ),
          ),
        ],

        // Width stepper
        _buildPropertyRow(
          title: context.l10n.terminalGridWidth,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStepperButton('−', () {
                if (o.w > 1) {
                  _mutateDraft(() => o.w--);
                }
              }),
              Container(
                constraints: const BoxConstraints(minWidth: 28),
                alignment: Alignment.center,
                child: Text(
                  '${o.w}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              _buildStepperButton('＋', () {
                if (o.w < 3 && o.c + o.w + 1 <= _draftLayout.columns) {
                  if (!checkCollision(
                    _draftLayout.items,
                    o,
                    o.c,
                    o.r,
                    o.w + 1,
                    o.h,
                    o.p,
                    _draftLayout.rows,
                    columns: _draftLayout.columns,
                  )) {
                    _mutateDraft(() => o.w++);
                  }
                }
              }),
            ],
          ),
        ),

        // Move to Page
        _buildPropertyRow(
          title: context.l10n.terminalGridCurrentPage,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStepperButton('‹', () {
                if (o.p > 0) {
                  final s = findFreeSpot(
                    _draftLayout.items,
                    o.w,
                    o.h,
                    o.p - 1,
                    _draftLayout.rows,
                    columns: _draftLayout.columns,
                  );
                  if (s != null) {
                    _mutateDraft(() {
                      o.p--;
                      o.c = s[0];
                      o.r = s[1];
                      _page = o.p;
                    });
                  }
                }
              }),
              Container(
                constraints: const BoxConstraints(minWidth: 32),
                alignment: Alignment.center,
                child: Text(
                  '${o.p + 1}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              _buildStepperButton('›', () {
                if (o.p < _draftLayout.pages - 1) {
                  final s = findFreeSpot(
                    _draftLayout.items,
                    o.w,
                    o.h,
                    o.p + 1,
                    _draftLayout.rows,
                    columns: _draftLayout.columns,
                  );
                  if (s != null) {
                    _mutateDraft(() {
                      o.p++;
                      o.c = s[0];
                      o.r = s[1];
                      _page = o.p;
                    });
                  }
                }
              }),
            ],
          ),
        ),
        const SizedBox(height: 10),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: scheme.errorContainer,
            foregroundColor: scheme.onErrorContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(vertical: 9),
          ),
          onPressed: () {
            _mutateDraft(() {
              _draftLayout.items.remove(o);
              _sel = null;
            });
          },
          child: Text(
            context.l10n.terminalGridDeleteKey,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 3: 设置 (Settings)
  // ---------------------------------------------------------------------------

  Widget _buildTabSet(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasArrowGroup = _draftLayout.items.any((i) => i.t == 'g');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Rows Stepper
        _buildPropertyRow(
          title: context.l10n.terminalGridRows,
          subtitle: context.l10n.terminalGridRowsSubtitle,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStepperButton('−', () => _setRows(_draftLayout.rows - 1)),
              Container(
                constraints: const BoxConstraints(minWidth: 28),
                alignment: Alignment.center,
                child: Text(
                  '${_draftLayout.rows}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              _buildStepperButton('＋', () => _setRows(_draftLayout.rows + 1)),
            ],
          ),
        ),
        // Toggle Arrows Switch
        _buildPropertyRow(
          title: context.l10n.terminalGridInvertedT,
          subtitle: context.l10n.terminalGridInvertedTSubtitle,
          trailing: Switch(
            value: hasArrowGroup,
            activeTrackColor: scheme.primary,
            onChanged: (val) => _toggleArrows(),
          ),
        ),
        // Direction key color
        _buildPropertyRow(
          title: context.l10n.terminalDirectionKeyColor,
          subtitle: _draftLayout.directionSeedColor != null
              ? null
              : context.l10n.terminalDirectionKeyColorDefault,
          trailing: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            ),
            onPressed: () async {
              final result = await DirectionKeyColorDialog.show(
                context,
                initialColorValue: _draftLayout.directionSeedColor,
              );
              if (result != null && mounted) {
                _mutateDraft(() {
                  _draftLayout = _draftLayout.copyWith(
                    directionSeedColor: result.colorValue,
                    clearDirectionSeedColor: result.resetToTheme,
                  );
                });
              }
            },
            icon: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: _draftLayout.directionSeedColor != null
                    ? Color(_draftLayout.directionSeedColor!)
                    : Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
            label: Text(
              _draftLayout.directionSeedColor != null
                  ? '#${(_draftLayout.directionSeedColor! & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}'
                  : context.l10n.terminalDirectionKeyColorDefault,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ),
        // Reset button
        _buildPropertyRow(
          title: context.l10n.terminalGridReset,
          trailing: _buildSmallButton(
            context.l10n.terminalGridCorruptedReset,
            _resetToDefault,
            isDanger: true,
          ),
        ),
      ],
    );
  }

  Widget _buildPropertyRow({
    required String title,
    String? subtitle,
    required Widget trailing,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scheme = Theme.of(context).colorScheme;
        final isNarrow = constraints.maxWidth < 280;
        final titleColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                color: scheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ],
          ],
        );

        if (isNarrow) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleColumn,
                const SizedBox(height: 6),
                Align(alignment: Alignment.centerRight, child: trailing),
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: titleColumn),
              const SizedBox(width: 8),
              trailing,
            ],
          ),
        );
      },
    );
  }

  Widget _buildStepperButton(String text, VoidCallback onPressed) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(15),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(
            fontSize: 16,
            color: scheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
