import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/progress_models.dart';
import '../presentation/progress_theme.dart';

class SkillComparisonChart extends StatelessWidget {
  final Map<String, SkillProgress> skills;
  final double targetBand;

  const SkillComparisonChart({
    super.key,
    required this.skills,
    required this.targetBand,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 230,
      child: CustomPaint(
        painter: _SkillComparisonPainter(
          skills: skills,
          targetBand: targetBand,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _SkillComparisonPainter extends CustomPainter {
  final Map<String, SkillProgress> skills;
  final double targetBand;

  _SkillComparisonPainter({required this.skills, required this.targetBand});

  @override
  void paint(Canvas canvas, Size size) {
    const left = 34.0;
    const right = 14.0;
    const top = 18.0;
    const bottom = 34.0;

    final chartWidth = size.width - left - right;
    final chartHeight = size.height - top - bottom;

    final gridPaint = Paint()
      ..color = ProgressColors.border
      ..strokeWidth = 1;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (var band = 0; band <= 9; band += 3) {
      final y = top + chartHeight * (1 - band / 9);

      canvas.drawLine(
        Offset(left, y),
        Offset(size.width - right, y),
        gridPaint,
      );

      textPainter.text = TextSpan(
        text: '$band',
        style: const TextStyle(color: ProgressColors.muted, fontSize: 12),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(8, y - textPainter.height / 2));
    }

    final targetY = top + chartHeight * (1 - targetBand.clamp(0, 9) / 9);

    final targetPaint = Paint()
      ..color = ProgressColors.orange
      ..strokeWidth = 1.5;

    canvas.drawLine(
      Offset(left, targetY),
      Offset(size.width - right, targetY),
      targetPaint,
    );

    final items = skills.entries.toList();
    if (items.isEmpty) return;

    final slotWidth = chartWidth / items.length;
    final barWidth = math.min(42.0, slotWidth * .46);

    for (var index = 0; index < items.length; index++) {
      final entry = items[index];
      final value = entry.value.band.clamp(0, 9);
      final barHeight = chartHeight * value / 9;
      final x = left + slotWidth * index + (slotWidth - barWidth) / 2;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, top + chartHeight - barHeight, barWidth, barHeight),
        const Radius.circular(9),
      );

      final paint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [ProgressColors.blue, ProgressColors.cyan],
        ).createShader(rect.outerRect);

      canvas.drawRRect(rect, paint);

      textPainter.text = TextSpan(
        text: value.toStringAsFixed(1),
        style: const TextStyle(
          color: ProgressColors.text,
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          x + barWidth / 2 - textPainter.width / 2,
          top + chartHeight - barHeight - 17,
        ),
      );

      textPainter.text = TextSpan(
        text: entry.key.substring(0, 1),
        style: const TextStyle(
          color: ProgressColors.secondary,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          x + barWidth / 2 - textPainter.width / 2,
          size.height - bottom + 10,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SkillComparisonPainter oldDelegate) {
    return oldDelegate.skills != skills || oldDelegate.targetBand != targetBand;
  }
}

class BandTrendChart extends StatelessWidget {
  final List<SkillBandPoint> points;

  const BandTrendChart({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: CustomPaint(
        painter: _BandTrendPainter(points),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _BandTrendPainter extends CustomPainter {
  final List<SkillBandPoint> points;

  _BandTrendPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    const padding = EdgeInsets.fromLTRB(30, 16, 12, 24);
    final width = size.width - padding.left - padding.right;
    final height = size.height - padding.top - padding.bottom;

    final gridPaint = Paint()
      ..color = ProgressColors.border
      ..strokeWidth = 1;

    for (var index = 0; index <= 3; index++) {
      final y = padding.top + height / 3 * index;
      canvas.drawLine(
        Offset(padding.left, y),
        Offset(size.width - padding.right, y),
        gridPaint,
      );
    }

    if (points.isEmpty) return;

    final visible = points.length > 12
        ? points.sublist(points.length - 12)
        : points;

    final linePath = Path();
    final fillPath = Path();

    for (var index = 0; index < visible.length; index++) {
      final x = visible.length == 1
          ? padding.left + width / 2
          : padding.left + width * index / (visible.length - 1);
      final y =
          padding.top + height * (1 - visible[index].band.clamp(0, 9) / 9);

      if (index == 0) {
        linePath.moveTo(x, y);
        fillPath.moveTo(x, padding.top + height);
        fillPath.lineTo(x, y);
      } else {
        linePath.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    final lastX = visible.length == 1
        ? padding.left + width / 2
        : padding.left + width;
    fillPath
      ..lineTo(lastX, padding.top + height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          ProgressColors.cyan.withOpacity(.30),
          ProgressColors.cyan.withOpacity(.01),
        ],
      ).createShader(Rect.fromLTWH(padding.left, padding.top, width, height));

    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = ProgressColors.cyan
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(linePath, linePaint);
  }

  @override
  bool shouldRepaint(covariant _BandTrendPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}

class ReadinessRing extends StatelessWidget {
  final double value;
  final double size;

  const ReadinessRing({super.key, required this.value, this.size = 112});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ReadinessPainter(value),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${value.round()}%',
                style: const TextStyle(
                  color: ProgressColors.text,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Text(
                'Ready',
                style: TextStyle(color: ProgressColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReadinessPainter extends CustomPainter {
  final double value;

  _ReadinessPainter(this.value);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * .09;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );

    final background = Paint()
      ..color = ProgressColors.border
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke;

    final progress = Paint()
      ..shader = const SweepGradient(
        colors: [
          ProgressColors.blue,
          ProgressColors.cyan,
          ProgressColors.green,
        ],
      ).createShader(rect)
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawArc(rect, 0, math.pi * 2, false, background);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * (value.clamp(0, 100) / 100),
      false,
      progress,
    );
  }

  @override
  bool shouldRepaint(covariant _ReadinessPainter oldDelegate) {
    return oldDelegate.value != value;
  }
}
