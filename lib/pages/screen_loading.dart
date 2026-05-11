import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app/routes/app_routes.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with TickerProviderStateMixin {
  double _progress = 0.0;

  late AnimationController _entryCtrl;
  late AnimationController _loopCtrl;
  late AnimationController _shimCtrl;

  late Animation<double> _logoFade;
  late Animation<double> _logoScale;
  late Animation<double> _textFade;
  late Animation<double> _textSlide;
  late Animation<double> _barFade;

  @override
  void initState() {
    super.initState();

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _logoFade = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.0, 0.50, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryCtrl,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOutBack),
      ),
    );
    _textFade = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.35, 0.75, curve: Curves.easeOut),
    );
    _textSlide = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _entryCtrl,
        curve: const Interval(0.35, 0.78, curve: Curves.easeOutCubic),
      ),
    );
    _barFade = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.62, 1.0, curve: Curves.easeOut),
    );

    _loopCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);

    _shimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _entryCtrl.forward();
    Future.delayed(const Duration(milliseconds: 700), _startLoading);
  }

  void _startLoading() async {
    for (int i = 0; i <= 100; i++) {
      await Future.delayed(const Duration(milliseconds: 26));
      if (mounted) setState(() => _progress = i / 100);
    }
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 400));

    // UBAH: Arahkan ke LoginPage (bukan MainPage)
    Get.offAllNamed(AppRoutes.login);
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _loopCtrl.dispose();
    _shimCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFFFFFFF),
                  Color(0xFFE3F2FD),
                  Color(0xFF1565C0),
                  Color(0xFF0D47A1),
                ],
                stops: [0.0, 0.25, 0.6, 1.0],
              ),
            ),
          ),
          Positioned(
            top: -size.height * 0.1,
            left: -size.width * 0.2,
            right: -size.width * 0.2,
            child: AnimatedBuilder(
              animation: _loopCtrl,
              builder: (_, _) => Container(
                height: size.height * 0.6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.lightBlue.shade200.withOpacity(
                        0.20 + _loopCtrl.value * 0.05,
                      ),
                      Colors.transparent,
                    ],
                    radius: 0.6,
                  ),
                ),
              ),
            ),
          ),
          ..._buildBackgroundDecorations(size),
          SafeArea(
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: size.width * 0.1),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildLogo(size),
                    SizedBox(height: size.height * 0.05),
                    _buildText(),
                    SizedBox(height: size.height * 0.06),
                    _buildBar(size),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _barFade,
              builder: (_, _) => Opacity(
                opacity: _barFade.value,
                child: Text(
                  '© 2026 Politeknik Negeri Jember',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: Colors.blue.shade900.withOpacity(0.7),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildBackgroundDecorations(Size size) {
    return [
      Positioned(
        bottom: -size.width * 0.25,
        right: -size.width * 0.2,
        child: Container(
          width: size.width * 0.85,
          height: size.width * 0.85,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
          ),
        ),
      ),
      Positioned(
        bottom: -size.width * 0.38,
        right: -size.width * 0.33,
        child: Container(
          width: size.width * 1.1,
          height: size.width * 1.1,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
          ),
        ),
      ),
    ];
  }

  Widget _buildLogo(Size size) {
    return AnimatedBuilder(
      animation: Listenable.merge([_logoFade, _logoScale, _loopCtrl]),
      builder: (_, _) {
        final glow = _loopCtrl.value;

        return FadeTransition(
          opacity: _logoFade,
          child: Transform.scale(
            scale: _logoScale.value,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 170 + glow * 10,
                  height: 170 + glow * 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withOpacity(0.25 + glow * 0.05),
                        Colors.white.withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
                AnimatedBuilder(
                  animation: _loopCtrl,
                  builder: (_, _) => Transform.rotate(
                    angle: _loopCtrl.value * math.pi * 0.2,
                    child: CustomPaint(
                      painter: _ArcRingPainter(
                        color: Colors.white.withOpacity(0.6),
                        radius: 70,
                        strokeWidth: 1.5,
                        dashCount: 16,
                        gapRatio: 0.42,
                      ),
                      size: const Size(160, 160),
                    ),
                  ),
                ),
                AnimatedBuilder(
                  animation: _loopCtrl,
                  builder: (_, _) => Transform.rotate(
                    angle: -_loopCtrl.value * math.pi * 0.1,
                    child: CustomPaint(
                      painter: _ArcRingPainter(
                        color: Colors.white.withOpacity(0.3),
                        radius: 82,
                        strokeWidth: 1.0,
                        dashCount: 24,
                        gapRatio: 0.55,
                      ),
                      size: const Size(180, 180),
                    ),
                  ),
                ),
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0D47A1).withOpacity(0.25),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                        spreadRadius: 0,
                      ),
                      BoxShadow(
                        color: Colors.white.withOpacity(0.8),
                        blurRadius: 0,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Image.asset(
                      'assets/logo-polije.png',
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.school,
                        size: 50,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildText() {
    return AnimatedBuilder(
      animation: Listenable.merge([_textFade, _textSlide]),
      builder: (_, child) => Transform.translate(
        offset: Offset(0, _textSlide.value),
        child: Opacity(opacity: _textFade.value, child: child),
      ),
      child: Column(
        children: [
          Text(
            'SIPORA',
            style: GoogleFonts.outfit(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 6,
              height: 1,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 25,
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.0),
                      Colors.white.withOpacity(0.8),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'POLITEKNIK NEGERI JEMBER',
                style: GoogleFonts.outfit(
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                  letterSpacing: 2.5,
                  shadows: [
                    Shadow(color: Colors.black.withOpacity(0.2), blurRadius: 5),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 25,
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.8),
                      Colors.white.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.4),
                width: 1,
              ),
            ),
            child: Text(
              'Sistem Informasi Repository Assets',
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBar(Size size) {
    final barWidth = size.width * 0.55;

    return AnimatedBuilder(
      animation: Listenable.merge([_barFade, _shimCtrl]),
      builder: (_, _) => Opacity(
        opacity: _barFade.value,
        child: Column(
          children: [
            SizedBox(
              width: barWidth + 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _progress < 1.0 ? 'Memuat aplikasi...' : 'Selesai ✓',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.3,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${(_progress * 100).toInt()}%',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.5,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: barWidth + 20,
              height: 7,
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    height: 7,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 60),
                    width: (_progress * (barWidth + 20)).clamp(
                      0.0,
                      barWidth + 20,
                    ),
                    height: 7,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.5),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: (_progress * (barWidth + 20)).clamp(
                        0.0,
                        barWidth + 20,
                      ),
                      height: 7,
                      child: Transform.translate(
                        offset: Offset(
                          _shimCtrl.value * (barWidth + 50) - 20,
                          0,
                        ),
                        child: Container(
                          width: 25,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.blue.shade900.withOpacity(0.0),
                                Colors.blue.shade900.withOpacity(0.2),
                                Colors.blue.shade900.withOpacity(0.0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArcRingPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double strokeWidth;
  final int dashCount;
  final double gapRatio;

  const _ArcRingPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
    required this.dashCount,
    required this.gapRatio,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final step = math.pi * 2 / dashCount;
    for (int i = 0; i < dashCount; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        i * step,
        step * (1.0 - gapRatio),
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ArcRingPainter old) =>
      old.color != color || old.radius != radius;
}
