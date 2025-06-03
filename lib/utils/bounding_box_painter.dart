import 'package:flutter/material.dart';

class BoundingBoxPainter extends CustomPainter {
  final List<Map<String, dynamic>> objects;
  final double imageWidth;
  final double imageHeight;

  BoundingBoxPainter(this.objects, this.imageWidth, this.imageHeight);

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.red.withOpacity(0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3;

    for (var obj in objects) {
      final poly = obj['boundingPoly']['normalizedVertices'] as List;
      if (poly.length < 4) continue;

      // Convert normalized vertices to actual pixel positions
      final points =
          poly
              .map(
                (v) => Offset(
                  (v['x'] ?? 0.0) * size.width,
                  (v['y'] ?? 0.0) * size.height,
                ),
              )
              .toList();

      final path =
          Path()
            ..moveTo(points[0].dx, points[0].dy)
            ..lineTo(points[1].dx, points[1].dy)
            ..lineTo(points[2].dx, points[2].dy)
            ..lineTo(points[3].dx, points[3].dy)
            ..close();

      canvas.drawPath(path, paint);

      // Draw label and confidence
      final label = obj['name'];
      final confidence = (obj['score'] * 100).toStringAsFixed(1);
      final brightness =
          obj['brightness'] != null
              ? obj['brightness'].toStringAsFixed(0)
              : 'N/A';
      final textSpan = TextSpan(
        text: '$label ($confidence%)\nBRIGHTNESS: $brightness',
        style: TextStyle(
          color: Colors.red.shade900,
          fontSize: 16,
          backgroundColor: Colors.white.withOpacity(0.7),
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
        maxLines: 2,
      )..layout();
      // Draw label at the top-left corner of the bounding box
      textPainter.paint(canvas, points[0]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
