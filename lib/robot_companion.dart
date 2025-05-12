import 'dart:async';
import 'dart:math' show Random;
import 'package:flutter/material.dart';

class RobotCompanion extends StatefulWidget {
  final bool isListening;
  final bool isSpeaking;
  const RobotCompanion({
    required this.isListening,
    required this.isSpeaking,
    super.key,
  });

  @override
  _RobotCompanionState createState() => _RobotCompanionState();
}

class _RobotCompanionState extends State<RobotCompanion>
    with SingleTickerProviderStateMixin {
  double _amplitude = 0.0;
  Timer? _amplitudeTimer;
  late AnimationController _eyeController;
  late Animation<double> _eyeAnimation;

  @override
  void initState() {
    super.initState();
    // Eye pulse animation for speaking
    _eyeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _eyeAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _eyeController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(covariant RobotCompanion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSpeaking && !oldWidget.isSpeaking) {
      _eyeController.repeat(reverse: true); // Start pulsing
      _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
        setState(() => _amplitude = Random().nextDouble());
      });
    } else if (!widget.isSpeaking && oldWidget.isSpeaking) {
      _eyeController.stop();
      _amplitudeTimer?.cancel();
      setState(() => _amplitude = 0.0);
    }
  }

  @override
  void dispose() {
    _amplitudeTimer?.cancel();
    _eyeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEyesOpen = widget.isListening || widget.isSpeaking;
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        // Robot base
        Image.asset(
          'assets/robot_base.png',
          //width: 662,
          //height: 890,
          fit: BoxFit.contain,
        ),
        // Eyes
        Positioned(
          bottom: 410, // Adjust based on your PNG's eye position
          child: AnimatedBuilder(
            animation: _eyeAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: widget.isSpeaking ? _eyeAnimation.value : 1.0,
                child: Image.asset(
                  isEyesOpen
                      ? 'assets/eyes_opened.png'
                      : 'assets/eyes_closed.png',
                  width: 562,
                  height: 60,
                  fit: BoxFit.contain,
                ),
              );
            },
          ),
        ),
        // Mouth bars
        Positioned(
          bottom: 200, // Adjust to your PNG's mouth position
          child: CustomPaint(
            size: const Size(100, 40), // Mouth size—tweak as needed
            painter: RobotMouthPainter(widget.isSpeaking ? _amplitude : 0.0),
          ),
        ),
      ],
    );
  }
}

class RobotMouthPainter extends CustomPainter {
  final double amplitude;
  RobotMouthPainter(this.amplitude);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.green;
    const barCount = 3;
    final barHeight = size.height / barCount;
    for (var i = 0; i < barCount; i++) {
      final width = size.width * (amplitude * (1 - i * 0.2));
      canvas.drawRect(
        Rect.fromLTWH(0, i * barHeight, width, barHeight * 0.8),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
