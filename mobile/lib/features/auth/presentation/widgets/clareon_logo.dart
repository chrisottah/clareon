// lib/features/auth/presentation/widgets/clareon_logo.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ClareonLogo extends StatelessWidget {
  const ClareonLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      'Clareon',
      style: GoogleFonts.outfit(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).textTheme.headlineLarge?.color,
        letterSpacing: -0.5,
      ),
    );
  }
}