import 'dart:math' as math;
import 'package:flutter/material.dart';

class DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF90CAF9)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const dashWidth = 8.0;
    const dashSpace = 5.0;
    const cornerRadius = 12.0;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          const Radius.circular(cornerRadius),
        ),
      );

    for (final metric in path.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        final len = math.min(dashWidth, metric.length - d);
        canvas.drawPath(metric.extractPath(d, d + len), paint);
        d += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant DashedBorderPainter old) => false;
}

class ModernSpinnerPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  ModernSpinnerPainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final gradient = SweepGradient(
      startAngle: 0.0,
      endAngle: 2 * math.pi,
      colors: [color.withOpacity(0), color.withOpacity(0.5), color],
      stops: const [0.0, 0.5, 1.0],
      transform: const GradientRotation(math.pi * 1.5),
    );
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0.0,
      2 * math.pi,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant ModernSpinnerPainter o) =>
      color != o.color || strokeWidth != o.strokeWidth;
}
