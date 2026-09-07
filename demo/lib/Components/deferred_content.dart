import 'dart:async';

import 'package:flutter/material.dart';

class DeferredContent extends StatefulWidget {
  const DeferredContent({
    required this.active,
    required this.child,
    this.placeholder,
    this.delay = const Duration(milliseconds: 360),
    super.key,
  });

  final bool active;
  final Widget child;
  final Widget? placeholder;
  final Duration delay;

  @override
  State<DeferredContent> createState() => _DeferredContentState();
}

class DeferredTabContent extends StatelessWidget {
  const DeferredTabContent({
    required this.tabIndex,
    required this.child,
    this.placeholder,
    this.delay = const Duration(milliseconds: 180),
    super.key,
  });

  final int tabIndex;
  final Widget child;
  final Widget? placeholder;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final controller = DefaultTabController.maybeOf(context);
    if (controller == null) {
      return DeferredContent(
        active: true,
        delay: delay,
        placeholder: placeholder,
        child: child,
      );
    }

    return AnimatedBuilder(
      animation: controller.animation ?? controller,
      child: child,
      builder: (context, child) {
        final animationValue =
            controller.animation?.value ?? controller.index.toDouble();
        final isTarget = controller.index == tabIndex;
        final isNearTarget = (animationValue - tabIndex).abs() < 0.5;
        return DeferredContent(
          active: isTarget || isNearTarget,
          delay: delay,
          placeholder: placeholder,
          child: child!,
        );
      },
    );
  }
}

class _DeferredContentState extends State<DeferredContent>
    with AutomaticKeepAliveClientMixin {
  bool _builtChild = false;
  Timer? _timer;
  int _scheduleGeneration = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (widget.active && widget.delay == Duration.zero) {
      _builtChild = true;
    } else if (widget.active) {
      _scheduleBuild();
    }
  }

  @override
  void didUpdateWidget(covariant DeferredContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.active && !_builtChild) {
      _cancelPendingBuild();
      return;
    }
    if (widget.active && !_builtChild && widget.delay == Duration.zero) {
      _cancelPendingBuild();
      _builtChild = true;
      return;
    }
    if (widget.active && !_builtChild && _timer == null) {
      _scheduleBuild();
    }
  }

  void _scheduleBuild() {
    _timer?.cancel();
    final generation = ++_scheduleGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !widget.active ||
          _builtChild ||
          generation != _scheduleGeneration) {
        return;
      }
      _timer = Timer(widget.delay, () {
        _timer = null;
        if (!mounted || !widget.active || generation != _scheduleGeneration) {
          return;
        }
        setState(() => _builtChild = true);
      });
    });
  }

  void _cancelPendingBuild() {
    _scheduleGeneration++;
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_builtChild) return widget.child;
    return widget.placeholder ?? const _DeferredContentPlaceholder();
  }
}

class _DeferredContentPlaceholder extends StatelessWidget {
  const _DeferredContentPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}
