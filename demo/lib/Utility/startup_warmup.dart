import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';

import 'AppColors.dart';
import 'app_decorations.dart';

class QuiltShaderWarmUp extends ShaderWarmUp {
  const QuiltShaderWarmUp();

  @override
  ui.Size get size => const ui.Size(420, 720);

  @override
  Future<void> warmUpOnCanvas(ui.Canvas canvas) async {
    _drawScreenBackground(canvas);
    _drawCards(canvas);
    _drawControls(canvas);
    _drawClippedImages(canvas);
    _drawText(canvas);
  }

  void _drawScreenBackground(ui.Canvas canvas) {
    const rect = Rect.fromLTWH(0, 0, 420, 720);
    final paint = Paint()
      ..shader = AppDecorations.defaultScreenGradient.createShader(rect);
    canvas.drawRect(rect, paint);
  }

  void _drawCards(ui.Canvas canvas) {
    final shadowPaint = Paint()
      ..color = AppColors.shadow.withValues(alpha: 0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
    final cardPaint = Paint()..color = AppColors.surface;
    final outlinePaint = Paint()
      ..color = AppColors.inputBorder.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (var i = 0; i < 4; i++) {
      final top = 42.0 + (i * 112);
      final shadow = RRect.fromRectAndRadius(
        Rect.fromLTWH(30, top + 8, 360, 88),
        const Radius.circular(18),
      );
      final card = RRect.fromRectAndRadius(
        Rect.fromLTWH(28, top, 364, 92),
        const Radius.circular(18),
      );
      canvas.drawRRect(shadow, shadowPaint);
      canvas.drawRRect(card, cardPaint);
      canvas.drawRRect(card, outlinePaint);
    }
  }

  void _drawControls(ui.Canvas canvas) {
    final primaryPaint = Paint()..color = AppColors.accent;
    final mutedPaint = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.14);
    final inputPaint = Paint()..color = AppColors.inputFill;
    final outlinePaint = Paint()
      ..color = AppColors.inputBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(52, 540, 148, 46),
        const Radius.circular(12),
      ),
      primaryPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(218, 540, 148, 46),
        const Radius.circular(12),
      ),
      mutedPaint,
    );

    for (var i = 0; i < 3; i++) {
      final rect = Rect.fromLTWH(52, 604 + (i * 38), 314, 28);
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(10));
      canvas.drawRRect(rrect, inputPaint);
      canvas.drawRRect(rrect, outlinePaint);
    }
  }

  void _drawClippedImages(ui.Canvas canvas) {
    final clip = RRect.fromRectAndRadius(
      const Rect.fromLTWH(52, 165, 316, 145),
      const Radius.circular(14),
    );
    canvas.save();
    canvas.clipRRect(clip);
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF6366F1), Color(0xFF22C55E), Color(0xFFF97316)],
      ).createShader(clip.outerRect);
    canvas.drawRect(clip.outerRect, paint);
    canvas.restore();

    canvas.save();
    canvas.clipPath(Path()..addOval(const Rect.fromLTWH(56, 60, 64, 64)));
    canvas.drawRect(
      const Rect.fromLTWH(56, 60, 64, 64),
      Paint()..color = AppColors.accent.withValues(alpha: 0.22),
    );
    canvas.restore();
  }

  void _drawText(ui.Canvas canvas) {
    final styles = [
      const TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: AppColors.title,
      ),
      const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.title,
      ),
      const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.subtitle,
      ),
    ];

    for (var i = 0; i < styles.length; i++) {
      final paragraphBuilder =
          ui.ParagraphBuilder(
              ui.ParagraphStyle(textDirection: TextDirection.ltr),
            )
            ..pushStyle(styles[i].getTextStyle())
            ..addText('Quilt Club Events');
      final paragraph = paragraphBuilder.build()
        ..layout(const ui.ParagraphConstraints(width: 280));
      canvas.drawParagraph(paragraph, Offset(52, 350 + (i * 36)));
    }
  }
}
