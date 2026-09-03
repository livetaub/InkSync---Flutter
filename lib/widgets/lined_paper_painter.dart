import 'package:flutter/material.dart';

class LinedPaperPainter extends CustomPainter {
  final Color lineColor;

  LinedPaperPainter({required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.0;

    const double lineSpacing = 24.0;
    
    // Draw horizontal lines
    for (double i = lineSpacing; i < size.height; i += lineSpacing) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
