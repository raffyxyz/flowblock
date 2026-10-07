import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Large accent progress ring for the timer screen. The time text is provided
/// by [child] so the ring stays purely presentational.
class CircularTimerRing extends StatelessWidget {
  const CircularTimerRing({
    super.key,
    required this.progress,
    required this.child,
    this.diameter = 248,
  });

  /// Fraction of time remaining (1.0 = full, 0.0 = finished).
  final double progress;
  final Widget child;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    final FlowColors colors = context.colors;
    return SizedBox(
      width: diameter,
      height: diameter,
      child: CustomPaint(
        painter: _RingPainter(
          progress: progress.clamp(0.0, 1.0),
          trackColor: colors.line,
          accentColor: colors.accent,
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.trackColor,
    required this.accentColor,
  });

  final double progress;
  final Color trackColor;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    const double stroke = 12;
    final double radius =
        (math.min(size.width, size.height) - stroke) / 2;
    final Offset center = Offset(size.width / 2, size.height / 2);
    final Paint base = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, base);
    final Paint arc = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      progress * 2 * math.pi,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.accentColor != accentColor;
  }
}
