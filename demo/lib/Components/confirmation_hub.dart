import 'dart:async';

import 'package:flutter/material.dart';

enum QuiltConfirmationTone { info, success, warning, error }

class QuiltConfirmation {
  QuiltConfirmation._();

  static final _QuiltConfirmationController _controller =
      _QuiltConfirmationController();

  static void show(
    BuildContext context,
    String message, {
    QuiltConfirmationTone tone = QuiltConfirmationTone.info,
  }) {
    _controller.show(message, tone);
  }

  static void success(BuildContext context, String message) {
    successMessage(message);
  }

  static void successMessage(String message) {
    _controller.show(message, QuiltConfirmationTone.success);
  }

  static void error(BuildContext context, String message) {
    show(context, message, tone: QuiltConfirmationTone.error);
  }

  static void warning(BuildContext context, String message) {
    show(context, message, tone: QuiltConfirmationTone.warning);
  }
}

class QuiltConfirmationHost extends StatefulWidget {
  const QuiltConfirmationHost({required this.child, super.key});

  final Widget child;

  @override
  State<QuiltConfirmationHost> createState() => _QuiltConfirmationHostState();
}

class _QuiltConfirmationHostState extends State<QuiltConfirmationHost> {
  final List<_QuiltConfirmationMessage> _messages = [];
  Timer? _dismissTimer;
  QuiltConfirmationTone _tone = QuiltConfirmationTone.info;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    QuiltConfirmation._controller.addListener(_handleConfirmation);
  }

  void _handleConfirmation() {
    final event = QuiltConfirmation._controller.takeLatest();
    if (event == null) return;

    final wasVisible = _visible;
    final previousTone = _tone;
    setState(() {
      _visible = true;
      _tone = event.tone;
      if (event.tone == QuiltConfirmationTone.error ||
          event.tone == QuiltConfirmationTone.warning) {
        _messages
          ..clear()
          ..add(event);
      } else {
        if (!wasVisible ||
            previousTone == QuiltConfirmationTone.error ||
            previousTone == QuiltConfirmationTone.warning) {
          _messages.clear();
        }
        _messages.removeWhere((message) => message.text == event.text);
        _messages.add(event);
        if (_messages.length > 4) {
          _messages.removeRange(0, _messages.length - 4);
        }
      }
    });

    _dismissTimer?.cancel();
    _dismissTimer = Timer(_displayDuration, _dismiss);
  }

  Duration get _displayDuration {
    if (_tone == QuiltConfirmationTone.error ||
        _tone == QuiltConfirmationTone.warning) {
      return const Duration(seconds: 4);
    }
    return Duration(milliseconds: _messages.length > 1 ? 3200 : 2200);
  }

  void _dismiss() {
    if (!mounted) return;
    setState(() => _visible = false);
  }

  @override
  void dispose() {
    QuiltConfirmation._controller.removeListener(_handleConfirmation);
    _dismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          left: 16,
          right: 16,
          bottom: 10,
          child: SafeArea(
            top: false,
            child: IgnorePointer(
              ignoring: !_visible,
              child: AnimatedSlide(
                offset: _visible ? Offset.zero : const Offset(0, 1.25),
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  opacity: _visible ? 1 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: _ConfirmationReceipt(
                    messages: _messages,
                    tone: _tone,
                    onDismiss: _dismiss,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ConfirmationReceipt extends StatelessWidget {
  const _ConfirmationReceipt({
    required this.messages,
    required this.tone,
    required this.onDismiss,
  });

  final List<_QuiltConfirmationMessage> messages;
  final QuiltConfirmationTone tone;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _accentColor(theme);
    final count = messages.length;
    final bodyText = messages.map((message) => message.text).join(' / ');

    return Material(
      elevation: 18,
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.28),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: Icon(_icon, color: accent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (count > 1)
                    Text(
                      '$count updates complete',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  Text(
                    bodyText,
                    maxLines: count > 1 ? 2 : 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.92),
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onDismiss,
              visualDensity: VisualDensity.compact,
              icon: Icon(
                Icons.close,
                color: Colors.white.withValues(alpha: 0.72),
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData get _icon {
    return switch (tone) {
      QuiltConfirmationTone.success => Icons.check_circle_outline,
      QuiltConfirmationTone.warning => Icons.warning_amber_rounded,
      QuiltConfirmationTone.error => Icons.error_outline,
      QuiltConfirmationTone.info => Icons.info_outline,
    };
  }

  Color _accentColor(ThemeData theme) {
    return switch (tone) {
      QuiltConfirmationTone.success => const Color(0xFF22C55E),
      QuiltConfirmationTone.warning => const Color(0xFFF59E0B),
      QuiltConfirmationTone.error => theme.colorScheme.error,
      QuiltConfirmationTone.info => theme.colorScheme.primary,
    };
  }
}

class _QuiltConfirmationController extends ChangeNotifier {
  _QuiltConfirmationMessage? _latest;

  void show(String text, QuiltConfirmationTone tone) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _latest = _QuiltConfirmationMessage(text: trimmed, tone: tone);
    notifyListeners();
  }

  _QuiltConfirmationMessage? takeLatest() {
    final event = _latest;
    _latest = null;
    return event;
  }
}

class _QuiltConfirmationMessage {
  const _QuiltConfirmationMessage({required this.text, required this.tone});

  final String text;
  final QuiltConfirmationTone tone;
}
