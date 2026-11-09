import 'package:flutter/material.dart';

/// The same opposed folio strokes used on daylex.it.
class DaylexMark extends StatelessWidget {
  const DaylexMark({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: Size.square(size),
      painter: _MarkPainter(Theme.of(context).colorScheme.onSurface),
    ),
  );
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 40, size.height / 40);
    final path = Path()
      ..moveTo(4, 4)
      ..lineTo(26, 4)
      ..lineTo(26, 10)
      ..lineTo(10, 10)
      ..lineTo(10, 30)
      ..lineTo(4, 30)
      ..close()
      ..moveTo(14, 14)
      ..lineTo(36, 14)
      ..lineTo(36, 36)
      ..lineTo(14, 36)
      ..lineTo(14, 30)
      ..lineTo(30, 30)
      ..lineTo(30, 20)
      ..lineTo(14, 20)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) => color != oldDelegate.color;
}
