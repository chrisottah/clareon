// lib/features/auth/presentation/widgets/animated_orb.dart
import 'package:flutter/material.dart';

class AnimatedOrb extends StatefulWidget {
  final double size;
  const AnimatedOrb({super.key, this.size = 80});

  @override
  State<AnimatedOrb> createState() => _AnimatedOrbState();
}

class _AnimatedOrbState extends State<AnimatedOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;
  late final Animation<double> _ring;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    _ring = Tween<double>(begin: 0.3, end: 0.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => SizedBox(
        width: s * 1.5,
        height: s * 1.5,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: s * 1.5,
              height: s * 1.5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF2563EB).withOpacity(_ring.value * 0.5),
                  width: 1.5,
                ),
              ),
            ),
            Container(
              width: s * 1.15,
              height: s * 1.15,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF2563EB).withOpacity(_ring.value * 0.3),
                  width: 1,
                ),
              ),
            ),
            Transform.scale(
              scale: _pulse.value,
              child: Container(
                width: s,
                height: s,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [
                      Color(0xFF3B82F6),
                      Color(0xFF2563EB),
                      Color(0xFF1D4ED8),
                    ],
                    stops: [0.0, 0.6, 1.0],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withOpacity(0.35),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(Icons.mic, color: Colors.white, size: s * 0.42),
              ),
            ),
          ],
        ),
      ),
    );
  }
}