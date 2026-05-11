import 'dart:math' as math;
import 'package:flutter/material.dart';

class FloatingChatbotButton extends StatefulWidget {
  final VoidCallback onTap;

  const FloatingChatbotButton({super.key, required this.onTap});

  @override
  State<FloatingChatbotButton> createState() => _FloatingChatbotButtonState();
}

class _FloatingChatbotButtonState extends State<FloatingChatbotButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ✅ 1. TAMBAHKAN GESTURE DETECTOR DI PALING LUAR
    return GestureDetector(
      onTap: widget.onTap, // ✅ 2. HUBUNGKAN KE FUNGSI openChat
      behavior:
          HitTestBehavior.opaque, // ✅ 3. PASTIKAN SELURUH AREA BISA DIKLIK
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value * 2 * math.pi;

          // Gerakan naik-turun halus via gelombang sinus
          final floatY = math.sin(t) * 4.5;

          // Scale sangat halus untuk kesan organik
          final scale = 1.0 + math.sin(t) * 0.018;

          // Shadow ikut bernapas
          final shadowBlur = 14.0 - math.sin(t) * 3.0;
          final shadowOffset = 6.0 - math.sin(t) * 2.0;

          return Transform.translate(
            offset: Offset(0, floatY),
            child: Transform.scale(
              scale: scale,
              child: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF42A5F5), Color(0xFF1565C0)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1565C0).withOpacity(0.35),
                      blurRadius: shadowBlur,
                      offset: Offset(0, shadowOffset),
                    ),
                  ],
                ),
                child: child,
              ),
            ),
          );
        },
        // Icon sebagai child agar tidak di-rebuild tiap frame
        child: const Icon(Icons.assistant, color: Colors.white, size: 26),
      ),
    );
  }
}
