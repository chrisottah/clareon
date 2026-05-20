import 'package:flutter/material.dart';

class RecordingTimer extends StatelessWidget {
  final String duration;
  final bool isPaused;

  const RecordingTimer({
    super.key,
    required this.duration,
    required this.isPaused,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Pulsing dot
        if (!isPaused)
          _PulsingDot()
        else
          Container(
            width: 12, height: 12,
            decoration: const BoxDecoration(
              color: Color(0xFFF59E0B),
              shape: BoxShape.circle,
            ),
          ),
        const SizedBox(height: 16),
        Text(
          duration,
          style: const TextStyle(
            fontSize: 56,
            fontWeight: FontWeight.w200,
            letterSpacing: 4,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isPaused ? 'PAUSED' : 'RECORDING',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 3,
            color: isPaused
                ? const Color(0xFFF59E0B)
                : const Color(0xFFEF4444),
          ),
        ),
      ],
    );
  }
}

class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 12, height: 12,
        decoration: const BoxDecoration(
          color: Color(0xFFEF4444),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
