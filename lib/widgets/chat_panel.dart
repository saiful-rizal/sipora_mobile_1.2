import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/gemini_service.dart';

class ChatMessage {
  final String content;
  final bool isUser;
  final DateTime time;

  ChatMessage({required this.content, required this.isUser, DateTime? time})
    : time = time ?? DateTime.now();

  Map<String, String> toMap() => {
    'role': isUser ? 'user' : 'assistant',
    'content': content,
  };
}

class ChatPanel extends StatefulWidget {
  final VoidCallback onClose;

  const ChatPanel({super.key, required this.onClose});

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final GeminiService _ai = GeminiService();

  final List<ChatMessage> _messages = [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _loading) return;

    if (!_ai.isReady) {
      setState(() => _error = 'API Key belum diset di file .env');
      return;
    }

    setState(() {
      _messages.add(ChatMessage(content: text, isUser: true));
      _loading = true;
      _error = null;
    });
    _ctrl.clear();
    _toBottom();

    try {
      final history = _messages
          .sublist(0, _messages.length - 1)
          .map((m) => m.toMap())
          .toList();

      final reply = await _ai.sendMessage(message: text, history: history);

      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(content: reply, isUser: false));
          _loading = false;
        });
        _toBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  void _sendSuggestion(String text) {
    _ctrl.text = text;
    _send();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Warna background putih bersih
      body: Column(
        children: [
          _header(),
          if (_error != null) _errorBanner(),
          Expanded(child: _messages.isEmpty ? _empty() : _chatList()),
          _input(bottom),
        ],
      ),
    );
  }

  // --- HEADER ---
  Widget _header() {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      padding: EdgeInsets.only(
        left: 8,
        right: 18,
        top: topPadding + 8,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: widget.onClose,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9), // Abu-abu sangat terang
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Color(0xFF1565C0),
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DocuBot',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF0F172A), // Hitam elegan
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF22C55E), // Hijau online cerah
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Online · Gemini 2.0 Flash',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF64748B), // Abu-abu sedang
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF), // Biru sangat terang
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Color(0xFF1565C0),
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  // --- ERROR BANNER ---
  Widget _errorBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2), // Merah sangat terang
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFEF4444),
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error!,
              style: GoogleFonts.outfit(
                color: const Color(0xFF991B1B), // Merah gelap
                fontSize: 12,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _error = null),
            child: const Icon(Icons.close, color: Color(0xFFEF4444), size: 16),
          ),
        ],
      ),
    );
  }

  // --- EMPTY STATE ---
  Widget _empty() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ✅ IKON OTAK/GEAR SUDAH DIHAPUS DISINI
            const SizedBox(
              height: 16,
            ), // Jarak sedikit dikurangi agar tidak terlalu kosong
            Text(
              'Halo! Saya DocuBot 👋',
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Asisten AI gratis untuk membantumu.\nTanyakan apa saja!',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: const Color(0xFF94A3B8),
                height: 1.6,
              ),
            ),
            const SizedBox(height: 32),
            _chip('Apa yang bisa kamu lakukan?', Icons.flash_on_rounded),
            const SizedBox(height: 12),
            _chip('Cara upload dokumen PDF', Icons.description_rounded),
            const SizedBox(height: 12),
            _chip('Jelaskan fitur analisis', Icons.analytics_rounded),
          ],
        ),
      ),
    );
  }

  // --- SUGGESTION CHIPS ---
  Widget _chip(String text, IconData icon) {
    return InkWell(
      onTap: () => _sendSuggestion(text),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: const Color(0xFF1565C0)),
            const SizedBox(width: 10),
            Text(
              text,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: const Color(0xFF475569),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- CHAT LIST ---
  Widget _chatList() {
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: _messages.length + (_loading ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == _messages.length) return _typing();
        return _bubble(_messages[i]);
      },
    );
  }

  // --- CHAT BUBBLES ---
  Widget _bubble(ChatMessage msg) {
    final isUser = msg.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 8, bottom: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Color(0xFF1565C0),
                size: 16,
              ),
            ),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                // User: Gradient Biru | Bot: Putih dengan border halus
                gradient: isUser
                    ? const LinearGradient(
                        colors: [Color(0xFF1565C0), Color(0xFF1E88E5)],
                      )
                    : null,
                color: isUser ? null : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                border: !isUser
                    ? Border.all(color: const Color(0xFFE2E8F0))
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isUser ? 0.08 : 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                msg.content,
                style: GoogleFonts.outfit(
                  fontSize: 13.5,
                  color: isUser ? Colors.white : const Color(0xFF334155),
                  height: 1.55,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- TYPING INDICATOR ---
  Widget _typing() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Color(0xFF1565C0),
              size: 16,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const _DotsLight(), // Menggunakan Dots versi Light
          ),
        ],
      ),
    );
  }

  // --- INPUT AREA ---
  Widget _input(double bottomInset) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 14, 16, bottomInset + 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, -2), // Shadow ke atas
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(
                    0xFFF1F5F9,
                  ), // Abu-abu sangat terang untuk background input
                  borderRadius: BorderRadius.circular(26),
                ),
                child: TextField(
                  controller: _ctrl,
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF0F172A),
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Ketik pesan...',
                    hintStyle: GoogleFonts.outfit(
                      color: const Color(0xFF94A3B8),
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    isDense: true,
                  ),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                gradient: _loading
                    ? LinearGradient(
                        colors: [Colors.grey.shade300, Colors.grey.shade200],
                      )
                    : const LinearGradient(
                        colors: [Color(0xFF1565C0), Color(0xFF1E88E5)],
                      ),
                borderRadius: BorderRadius.circular(26),
                boxShadow: !_loading
                    ? [
                        BoxShadow(
                          color: const Color(0xFF1565C0).withOpacity(0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _loading ? null : _send,
                  borderRadius: BorderRadius.circular(26),
                  child: Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    child: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── TYPING DOTS VERSI LIGHT MODE ───
class _DotsLight extends StatefulWidget {
  const _DotsLight();

  @override
  State<_DotsLight> createState() => _DotsLightState();
}

class _DotsLightState extends State<_DotsLight>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _ctrl,
          builder: (_, _) {
            final offset = (i * 0.2) % 1.0;
            final val = ((_ctrl.value - offset) % 1.0).clamp(0.0, 1.0);
            final y = (val < 0.5) ? val * 2 : (1 - val) * 2;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              child: Transform.translate(
                offset: Offset(0, -y * 4),
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    // Warna abu-abu solid yang ikut bernapas
                    color: const Color(0xFF94A3B8).withOpacity(0.4 + y * 0.6),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
