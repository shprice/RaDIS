import 'package:flutter/material.dart';

class LevelMeter extends StatefulWidget {
  final Stream<double> levelStream;
  final double width;
  final double height;
  final bool horizontal;
  final double? threshold; // 0.0–1.0, draws an amber line at this level

  const LevelMeter({
    super.key,
    required this.levelStream,
    this.width = 16,
    this.height = 80,
    this.horizontal = false,
    this.threshold,
  });

  @override
  State<LevelMeter> createState() => _LevelMeterState();
}

class _LevelMeterState extends State<LevelMeter> {
  double _level = 0;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<double>(
      stream: widget.levelStream,
      builder: (context, snapshot) {
        _level = snapshot.data ?? 0;
        return CustomPaint(
          size: Size(widget.width, widget.height),
          painter: _LevelMeterPainter(_level, widget.horizontal, widget.threshold),
        );
      },
    );
  }
}

class _LevelMeterPainter extends CustomPainter {
  final double level; // 0.0 - 1.0
  final bool horizontal;
  final double? threshold;

  _LevelMeterPainter(this.level, this.horizontal, this.threshold);

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFF1A1A1A);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    if (level > 0) {
      final segments = horizontal
          ? (size.width * level).clamp(0, size.width)
          : (size.height * level).clamp(0, size.height);

      Color barColor;
      if (level < 0.6) {
        barColor = const Color(0xFF4CAF50);
      } else if (level < 0.85) {
        barColor = const Color(0xFFFFB300);
      } else {
        barColor = const Color(0xFFFF1744);
      }

      final paint = Paint()..color = barColor;

      if (horizontal) {
        canvas.drawRect(
          Rect.fromLTWH(0, 0, segments.toDouble(), size.height),
          paint,
        );
      } else {
        final top = size.height - segments.toDouble();
        canvas.drawRect(
          Rect.fromLTWH(0, top, size.width, segments.toDouble()),
          paint,
        );
      }
    }

    // Draw threshold line if provided
    if (threshold != null) {
      final threshPaint = Paint()
        ..color = const Color(0xFFFFB300)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      if (horizontal) {
        final x = size.width * threshold!;
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), threshPaint);
      } else {
        final y = size.height - threshold! * size.height;
        canvas.drawLine(Offset(0, y), Offset(size.width, y), threshPaint);
      }
    }

    // Draw border
    final borderPaint = Paint()
      ..color = const Color(0xFF333333)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(_LevelMeterPainter old) =>
      old.level != level || old.threshold != threshold;
}
