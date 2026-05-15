import 'dart:math' as math;
import 'package:flutter/material.dart';

class JoystickWidget extends StatefulWidget {
  const JoystickWidget({
    super.key,
    required this.size,
    required this.onChanged,
    this.onStart,
    this.onEnd,
    this.returnToCenter = true,
    this.baseColor = const Color(0xFF1B1E24),
    this.accentColor = const Color(0xFF27B4F6),
  });

  final double size;
  final ValueChanged<Offset> onChanged;
  final VoidCallback? onStart;
  final VoidCallback? onEnd;
  final bool returnToCenter;
  final Color baseColor;
  final Color accentColor;

  @override
  State<JoystickWidget> createState() => _JoystickWidgetState();
}

class _JoystickWidgetState extends State<JoystickWidget> {
  Offset _value = Offset.zero;

  double get _radius => widget.size / 2;

  void _updateValue(Offset localPosition) {
    final dx = localPosition.dx - _radius;
    final dy = localPosition.dy - _radius;
    final offset = Offset(dx, dy);
    final distance = offset.distance;
    final maxDistance = _radius * 0.85;

    final clamped = distance > maxDistance
        ? offset * (maxDistance / distance)
        : offset;

    setState(() {
      _value = clamped;
    });

    widget.onChanged(Offset(
      (_value.dx / maxDistance).clamp(-1.0, 1.0),
      (_value.dy / maxDistance).clamp(-1.0, 1.0),
    ));
  }

  void _reset() {
    if (!widget.returnToCenter) {
      return;
    }
    setState(() {
      _value = Offset.zero;
    });
    widget.onChanged(Offset.zero);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (details) {
        widget.onStart?.call();
        _updateValue(details.localPosition);
      },
      onPanUpdate: (details) => _updateValue(details.localPosition),
      onPanEnd: (_) {
        widget.onEnd?.call();
        _reset();
      },
      child: CustomPaint(
        size: Size(widget.size, widget.size),
        painter: _JoystickPainter(
          knobOffset: _value,
          baseColor: widget.baseColor,
          accentColor: widget.accentColor,
        ),
      ),
    );
  }
}

class _JoystickPainter extends CustomPainter {
  _JoystickPainter({
    required this.knobOffset,
    required this.baseColor,
    required this.accentColor,
  });

  final Offset knobOffset;
  final Color baseColor;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final basePaint = Paint()
      ..color = baseColor
      ..style = PaintingStyle.fill;

    final ringPaint = Paint()
      ..color = accentColor.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final crossPaint = Paint()
      ..color = accentColor.withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawCircle(center, radius, basePaint);
    canvas.drawCircle(center, radius * 0.9, ringPaint);

    canvas.drawLine(
      Offset(center.dx - radius * 0.6, center.dy),
      Offset(center.dx + radius * 0.6, center.dy),
      crossPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - radius * 0.6),
      Offset(center.dx, center.dy + radius * 0.6),
      crossPaint,
    );

    final knobRadius = radius * 0.28;
    final knobCenter = center + knobOffset;
    final knobPaint = Paint()..color = accentColor;
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    canvas.drawCircle(knobCenter + const Offset(2, 3), knobRadius, shadowPaint);
    canvas.drawCircle(knobCenter, knobRadius, knobPaint);

    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final highlightRect = Rect.fromCircle(
      center: knobCenter - Offset(knobRadius * 0.15, knobRadius * 0.2),
      radius: knobRadius * 0.6,
    );
    canvas.drawArc(highlightRect, -math.pi / 2.2, math.pi / 2.4, false,
        highlightPaint);
  }

  @override
  bool shouldRepaint(covariant _JoystickPainter oldDelegate) {
    return knobOffset != oldDelegate.knobOffset ||
        baseColor != oldDelegate.baseColor ||
        accentColor != oldDelegate.accentColor;
  }
}
