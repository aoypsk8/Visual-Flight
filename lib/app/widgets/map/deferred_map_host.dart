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
    /// Mount map on first valid layout (search tab full-screen — no 250ms wait).
    this.immediate = false,
  });

  final Widget Function(BuildContext context) builder;
  /// Called when MapWidget is mounted / unmounted (stop ticker before native map disappears)
  final ValueChanged<bool>? onMountChanged;
  final double minWidth;
  final double minHeight;
  final Color placeholderColor;
  final bool immediate;

  @override
  State<DeferredMapHost> createState() => _DeferredMapHostState();
}

class _DeferredMapHostState extends State<DeferredMapHost> {
  static const _stableFrames = 3;
  static const _mountDelay = Duration(milliseconds: 250);

  bool _mountMap = false;
  bool _layoutCallbackScheduled = false;
  bool _mountReported = false;
  Size? _trackedSize;
  int _sameSizeFrames = 0;
  Timer? _mountTimer;
  BoxConstraints? _lastConstraints;

  @override
  void dispose() {
    _mountTimer?.cancel();
    if (_mountReported) {
      widget.onMountChanged?.call(false);
    }
    super.dispose();
  }

  void _reportMount(bool mounted) {
    if (_mountReported == mounted) return;
    _mountReported = mounted;
    widget.onMountChanged?.call(mounted);
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
    _reportMount(value);
    if (mounted) setState(() {});
  }

  void _evaluateConstraints(BoxConstraints constraints) {
    if (widget.immediate) return;

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
        final valid = _isValid(constraints);
        final showMap = widget.immediate ? valid : _mountMap && valid;

        if (widget.immediate) {
          _reportMount(showMap);
        } else {
          _scheduleLayoutCheck(constraints);
        }

        if (!showMap) {
          return ColoredBox(color: widget.placeholderColor);
        }

        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: widget.builder(context),
        );
      },
    );
  }
}
