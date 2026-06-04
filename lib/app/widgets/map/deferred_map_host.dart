import 'dart:async';

import 'package:flutter/material.dart';

/// Delays [MapWidget] mount until layout size is stable (avoids Mapbox 64×64 init).
class DeferredMapHost extends StatefulWidget {
  const DeferredMapHost({
    super.key,
    required this.builder,
    this.onMountChanged,
    this.minWidth = 200,
    this.minHeight = 200,
    this.placeholderColor = const Color(0xFF0C0D10),
  });

  final Widget Function(BuildContext context) builder;
  /// Called when MapWidget is mounted / unmounted (stop ticker before native map disappears)
  final ValueChanged<bool>? onMountChanged;
  final double minWidth;
  final double minHeight;
  final Color placeholderColor;

  @override
  State<DeferredMapHost> createState() => _DeferredMapHostState();
}

class _DeferredMapHostState extends State<DeferredMapHost> {
  static const _stableFrames = 3;
  static const _mountDelay = Duration(milliseconds: 250);

  bool _mountMap = false;
  bool _layoutCallbackScheduled = false;
  Size? _trackedSize;
  int _sameSizeFrames = 0;
  Timer? _mountTimer;
  BoxConstraints? _lastConstraints;

  @override
  void dispose() {
    _mountTimer?.cancel();
    super.dispose();
  }

  bool _isValid(BoxConstraints c) {
    return c.maxWidth.isFinite &&
        c.maxHeight.isFinite &&
        c.maxWidth >= widget.minWidth &&
        c.maxHeight >= widget.minHeight;
  }

  void _scheduleLayoutCheck(BoxConstraints constraints) {
    _lastConstraints = constraints;
    if (_layoutCallbackScheduled) return;
    _layoutCallbackScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _layoutCallbackScheduled = false;
      if (!mounted || _lastConstraints == null) return;
      _evaluateConstraints(_lastConstraints!);
    });
  }

  void _setMounted(bool value) {
    if (_mountMap == value) return;
    _mountMap = value;
    widget.onMountChanged?.call(value);
    if (mounted) setState(() {});
  }

  void _evaluateConstraints(BoxConstraints constraints) {
    if (!_isValid(constraints)) {
      _sameSizeFrames = 0;
      _trackedSize = null;
      _mountTimer?.cancel();
      _mountTimer = null;
      if (_mountMap) _setMounted(false);
      return;
    }

    final size = Size(constraints.maxWidth, constraints.maxHeight);
    if (_trackedSize != null &&
        (size.width - _trackedSize!.width).abs() < 1 &&
        (size.height - _trackedSize!.height).abs() < 1) {
      _sameSizeFrames++;
    } else {
      _trackedSize = size;
      _sameSizeFrames = 1;
      // Don't unmount map on minor size changes — prevents 64×64 init + channel-error
      if (!_mountMap) {
        _mountTimer?.cancel();
        _mountTimer = null;
      }
    }

    if (_mountMap || _mountTimer != null) return;
    if (_sameSizeFrames < _stableFrames) return;

    _mountTimer = Timer(_mountDelay, () {
      _mountTimer = null;
      if (!mounted || _trackedSize == null || _sameSizeFrames < _stableFrames) {
        return;
      }
      _setMounted(true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _scheduleLayoutCheck(constraints);

        if (!_mountMap || !_isValid(constraints)) {
          return ColoredBox(color: widget.placeholderColor);
        }

        // Enforce explicit size before creating native MapView
        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: widget.builder(context),
        );
      },
    );
  }
}
