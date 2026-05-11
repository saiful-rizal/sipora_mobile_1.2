import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

// Pastikan import ini sesuai dengan struktur folder proyek Anda
import '../pages/dashboard.dart';
import '../pages/upload.dart';
import '../pages/jelajahi.dart';
import '../pages/pencarian.dart';
import 'chat_panel.dart';
import 'floating_chatbot.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  static final GlobalKey<MainShellState> globalKey =
      GlobalKey<MainShellState>();

  @override
  State<MainShell> createState() => MainShellState();
}

class MainShellState extends State<MainShell> with TickerProviderStateMixin {
  int _currentIndex = 0;
  
  OverlayEntry? _chatOverlayEntry;
  late AnimationController _chatOverlayController;

  late Animation<Offset> _chatSlideAnim;
  late Animation<double> _chatFadeAnim;

  final List<Widget> _pages = [
    const DashboardPage(),
    const UploadPage(),
    const SearchPage(),
    const JelajahiPage(),
  ];

  @override
  void initState() {
    super.initState();
    _chatOverlayController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _chatSlideAnim = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _chatOverlayController,
            curve: Curves.easeOutCubic,
          ),
        );

    _chatFadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _chatOverlayController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _chatOverlayEntry?.remove();
    _chatOverlayController.dispose();
    super.dispose();
  }

  void openChat() {
    if (_chatOverlayEntry != null) return;
    
    _chatOverlayController.forward(from: 0.0);

    _chatOverlayEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            FadeTransition(
              opacity: _chatFadeAnim,
              child: Positioned.fill(
                child: GestureDetector(
                  onTap: _closeChat,
                  child: Container(color: Colors.black54),
                ),
              ),
            ),
            SlideTransition(
              position: _chatSlideAnim,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: ChatPanel(onClose: _closeChat),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(_chatOverlayEntry!);
  }

  void _closeChat() {
    _chatOverlayController.reverse().then((_) {
      _chatOverlayEntry?.remove();
      _chatOverlayEntry = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
    );

    return Scaffold(
      extendBody: false,
      resizeToAvoidBottomInset: true, 
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: _buildNavBar(),
      floatingActionButton: _buildFab(), // Langsung panggil method
      floatingActionButtonLocation:
          FloatingActionButtonLocation.centerDocked,
    );
  }

  // ✅ 1. LOGIKA FAB DIPINDAHKAN KE SINI (TANPA VALUELISTENABLE BUILDER)
  Widget _buildFab() {
    // Method build() otomatis dipanggil ulang saat keyboard muncul/hilang.
    // Jadi cukup cek apakah keyboard sedang terbuka atau tidak.
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    // Jika keyboard terbuka, kembalikan widget kosong (FAB hilang)
    if (isKeyboardOpen) {
      return const SizedBox.shrink();
    }

    // Jika keyboard tertutup, tampilkan FAB Chatbot
    return FloatingChatbotButton(onTap: openChat);
  }

  Widget _buildNavBar() {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    const contentHeight = 52.0;

    return SizedBox(
      height: contentHeight + bottomInset,
      child: CustomPaint(
        painter: _NotchPainter(bottomPadding: bottomInset),
        child: Column(
          children: [
            SizedBox(
              height: contentHeight,
              // ✅ 2. GUNAKAN EXPANDED AGAR LEBAR OTOMATIS MENYESUAIKAN TEKS
              child: Row(
                children: [
                  Expanded(child: _navItem(Icons.home_outlined, Icons.home_rounded, "Beranda", 0)),
                  Expanded(child: _navItem(Icons.cloud_upload_outlined, Icons.cloud_upload_rounded, "Upload", 1)),
                  const SizedBox(width: 60), // Jeda untuk FAB di tengah
                  Expanded(child: _navItem(Icons.explore_outlined, Icons.explore_rounded, "Jelajahi", 3)),
                  Expanded(child: _navItem(Icons.search_outlined, Icons.search_rounded, "Pencarian", 2)),
                ],
              ),
            ),
            SizedBox(height: bottomInset),
          ],
        ),
      ),
    );
  }

  // ✅ 3. HAPUS SIZEDBOX STATIS YANG MEMBUAT TEKS KEPOTONG
  Widget _navItem(IconData icon, IconData activeIcon, String label, int index) {
    final isActive = _currentIndex == index;

    return Semantics(
      button: true,
      label: label,
      selected: isActive,
      child: GestureDetector(
        onTap: () {
          setState(() => _currentIndex = index);
        },
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              size: 26,
              color: isActive ? Colors.white : Colors.white.withOpacity(0.45),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 10,
                height: 1,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive
                    ? Colors.white
                    : Colors.white.withOpacity(0.45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom Painter untuk Notch bawah (Tetap Sama)
class _NotchPainter extends CustomPainter {
  final double bottomPadding;
  const _NotchPainter({this.bottomPadding = 0});

  @override
  void paint(Canvas canvas, Size size) {
    const cornerR = 12.0;
    const fabR = 27.0;
    const gap = 6.0;
    const notchHalfW = fabR + gap;
    const notchD = 32.0;
    const cpOffset = 18.0;

    final cx = size.width / 2;
    final curveStartX = cx - notchHalfW - cpOffset;
    final curveEndX = cx + notchHalfW + cpOffset;

    final path = Path()
      ..moveTo(0, cornerR)
      ..quadraticBezierTo(0, 0, cornerR, 0)
      ..lineTo(curveStartX, 0)
      ..cubicTo(curveStartX + cpOffset, 0, cx - cpOffset, notchD, cx, notchD)
      ..cubicTo(cx + cpOffset, notchD, curveEndX - cpOffset, 0, curveEndX, 0)
      ..lineTo(size.width - cornerR, 0)
      ..quadraticBezierTo(size.width, 0, size.width, cornerR)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawShadow(
      path,
      const Color(0xFF1565C0).withOpacity(0.15),
      8,
      false,
    );

    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [Color(0xFF1565C0), Color(0xFF1E88E5), Color(0xFF42A5F5)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _NotchPainter old) =>
      old.bottomPadding != bottomPadding;
}