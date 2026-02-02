import 'dart:math';
import 'package:flutter/material.dart';

class TractorPainter extends CustomPainter {
  final Offset position;
  final double angle;
  final List<List<Offset>> strips;
  final double tractorBase;
  final double tractorHeight;

  TractorPainter({
    required this.position,
    required this.angle,
    required this.strips,
    required this.tractorBase,
    required this.tractorHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw Field
    final Paint fieldPaint = Paint()..color = Colors.brown.shade100;
    canvas.drawRect(Offset.zero & size, fieldPaint);

    // 2. Draw Trace Strips
    final Paint tracePaint = Paint()
      ..color = Colors.green.shade800.withOpacity(0.3)
      ..strokeWidth = tractorBase * 0.95
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.round;

    for (var strip in strips) {
      if (strip.isNotEmpty) {
        Path path = Path();
        path.moveTo(strip.first.dx, strip.first.dy);
        for (int i = 1; i < strip.length; i++) {
          path.lineTo(strip[i].dx, strip[i].dy);
        }
        canvas.drawPath(path, tracePaint);
      }
    }

    // 3. Draw Tractor
    canvas.save();
    canvas.translate(position.dx, position.dy);
    canvas.rotate(angle + pi / 2);

    final Path tractorPath = Path();
    tractorPath.moveTo(0, -tractorHeight / 2);
    tractorPath.lineTo(tractorBase / 2, tractorHeight / 2);
    tractorPath.lineTo(-tractorBase / 2, tractorHeight / 2);
    tractorPath.close();

    final Paint tractorPaint = Paint()..color = Colors.red;
    canvas.drawPath(tractorPath, tractorPaint);

    // Draw Back Bar
    canvas.drawLine(
        Offset(-tractorBase / 2, tractorHeight / 2),
        Offset(tractorBase / 2, tractorHeight / 2),
        Paint()..color = Colors.black..strokeWidth = 3);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant TractorPainter oldDelegate) => true;
}