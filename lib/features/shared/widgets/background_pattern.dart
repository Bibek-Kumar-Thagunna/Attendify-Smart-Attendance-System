import 'package:flutter/material.dart';

class BackgroundPattern extends StatelessWidget {
  final Widget child;

  const BackgroundPattern({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Solid background color
        Container(color: Theme.of(context).scaffoldBackgroundColor),
        // Dot pattern
        Positioned.fill(
          child: CustomPaint(
            painter: DotGridPainter(
              color: Colors.white.withValues(alpha: 0.05),
              spacing: 30,
            ),
          ),
        ),
        // Content
        child,
      ],
    );
  }
}

class DotGridPainter extends CustomPainter {
  final Color color;
  final double spacing;

  DotGridPainter({required this.color, required this.spacing});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
