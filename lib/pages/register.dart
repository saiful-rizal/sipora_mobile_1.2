import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/sipora_api_service.dart';

// ═══════════════════════════════════════════════════════════
//  SIPORA — Register Page ·  Modern Smart Popup Edition
// ═══════════════════════════════════════════════════════════

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  bool _isChecked = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  final SiporaApiService _apiService = SiporaApiService();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _nimController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    _nimController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    // Smart Validation: Cek Syarat & Ketentuan
    if (!_isChecked) {
      _showModernErrorDialog(
        title: 'Syarat Belum Disetujui',
        message:
            'Anda harus membaca dan menyetujui\nSyarat & Ketentuan untuk melanjutkan.',
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      // Smart Validation: Cek Password Match
      if (_passwordController.text != _confirmController.text) {
        setState(() => _isLoading = false);
        _showModernErrorDialog(
          title: 'Password Tidak Cocok',
          message:
              'Pastikan kolom password dan konfirmasi\npassword isiannya sama.',
        );
        return;
      }

      try {
        await _apiService.register(
          namaLengkap: _nameController.text.trim(),
          nim: _nimController.text.trim(),
          email: _emailController.text.trim(),
          username: _usernameController.text.trim(),
          password: _passwordController.text,
        );

        if (mounted) {
          setState(() => _isLoading = false);
          _showSuccessDialog();
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          _showModernErrorDialog(
            title: 'Registrasi Gagal',
            message: e.toString().replaceFirst('Exception: ', ''),
          );
        }
      }
    }
  }

  // ── Helper untuk Menampilkan Modern Popup ───────────────────────
  void _showModernPopup({
    required Widget child,
    bool barrierDismissible = true,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 340),
            margin: const EdgeInsets.symmetric(horizontal: 20),
            child: Material(color: Colors.transparent, child: child),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutBack,
            ),
            child: child,
          ),
        );
      },
    );
  }

  // ── Dialog Sukses (Smart: Extract Name) ───────────────────────────
  void _showSuccessDialog() {
    String name = _nameController.text.split(' ').first;
    name = name[0].toUpperCase() + name.substring(1);

    _showModernPopup(
      barrierDismissible: false,
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1565C0).withOpacity(0.2),
              blurRadius: 50,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 600),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Colors.green.shade400, Colors.green.shade600],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.4),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 42,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              'Registrasi Berhasil!',
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0D2137),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Selamat datang, $name.\nAkun Anda telah berhasil dibuat.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF1565C0),
                      Color(0xFF1E88E5),
                      Color(0xFF42A5F5),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    Navigator.pop(context); // tutup dialog
                    Navigator.pop(context); // kembali ke login
                  },
                  child: Text(
                    'Login Sekarang',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
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

  // ── Dialog Error (Modern Style) ───────────────────────────────────
  void _showModernErrorDialog({
    required String title,
    required String message,
  }) {
    _showModernPopup(
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withOpacity(0.1),
              blurRadius: 50,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red.shade50,
              ),
              child: Center(
                child: Icon(
                  Icons.error_outline_rounded,
                  color: Colors.red.shade400,
                  size: 42,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0D2137),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF1565C0),
                      Color(0xFF1E88E5),
                      Color(0xFF42A5F5),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Mengerti',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
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

  // ── Build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1565C0),
                  Color(0xFF2196F3),
                  Color(0xFFE3F2FD),
                  Color(0xFFFFFFFF),
                ],
                stops: [0.0, 0.35, 0.72, 1.0],
              ),
            ),
          ),
          Positioned(
            top: -size.height * 0.12,
            left: 0,
            right: 0,
            child: Container(
              height: size.height * 0.55,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Colors.white.withOpacity(0.18), Colors.transparent],
                  radius: 0.55,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -size.width * 0.25,
            right: -size.width * 0.2,
            child: Container(
              width: size.width * 0.85,
              height: size.width * 0.85,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.12),
                  width: 1,
                ),
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
                border: Border.all(
                  color: Colors.white.withOpacity(0.07),
                  width: 1,
                ),
              ),
            ),
          ),
          Positioned(
            top: -size.width * 0.18,
            left: -size.width * 0.22,
            child: Container(
              width: size.width * 0.65,
              height: size.width * 0.65,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Colors.white.withOpacity(0.13), Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: CustomPaint(
              painter: _WavePainter(),
              size: Size(size.width, 160),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      _buildHeader(),
                      const SizedBox(height: 24),
                      _buildFormCard(),
                      const SizedBox(height: 20),
                      Text(
                        '© 2026 Politeknik Negeri Jember',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: const Color(0xFF1565C0).withOpacity(0.55),
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────
  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.6), width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0D47A1).withOpacity(0.2),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Image.asset('assets/logo-polije.png', fit: BoxFit.contain),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'SIPORA',
          style: GoogleFonts.outfit(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 7,
            height: 1,
            shadows: [
              Shadow(
                color: const Color(0xFF0D47A1).withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 24,
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.0),
                    Colors.white.withOpacity(0.5),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'POLITEKNIK NEGERI JEMBER',
              style: GoogleFonts.outfit(
                fontSize: 9,
                fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(0.75),
                letterSpacing: 2.8,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 24,
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.5),
                    Colors.white.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Form Card ─────────────────────────────────────────────
  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.97),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D47A1).withOpacity(0.15),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Buat Akun Baru',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0D2137),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Lengkapi data diri Anda di bawah ini 📋',
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 22),

            _fieldLabel('Nama Lengkap'),
            const SizedBox(height: 6),
            _buildField(
              controller: _nameController,
              hint: 'Masukkan nama lengkap',
              icon: Icons.person_outline_rounded,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Nama tidak boleh kosong';
                if (v.length < 3) return 'Nama minimal 3 karakter';
                return null;
              },
            ),
            const SizedBox(height: 16),

            _fieldLabel('NIM'),
            const SizedBox(height: 6),
            _buildField(
              controller: _nimController,
              hint: 'Contoh: E41240108',
              icon: Icons.badge_outlined,
              keyboardType: TextInputType.text,
              validator: (v) {
                if (v == null || v.isEmpty) return 'NIM tidak boleh kosong';
                if (!RegExp(r'^E\d+$').hasMatch(v)) {
                  return 'Format NIM salah (cth: E41240108)';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            _fieldLabel('Alamat Email'),
            const SizedBox(height: 6),
            _buildField(
              controller: _emailController,
              hint: 'contoh@polije.ac.id',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Email tidak boleh kosong';
                if (!v.contains('@')) return 'Format email tidak valid';
                return null;
              },
            ),
            const SizedBox(height: 16),

            _fieldLabel('Username'),
            const SizedBox(height: 6),
            _buildField(
              controller: _usernameController,
              hint: 'Masukkan username',
              icon: Icons.alternate_email_rounded,
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return 'Username tidak boleh kosong';
                }
                if (v.length < 4) return 'Username minimal 4 karakter';
                return null;
              },
            ),
            const SizedBox(height: 16),

            _fieldLabel('Password'),
            const SizedBox(height: 6),
            _buildField(
              controller: _passwordController,
              hint: 'Kombinasi huruf & angka',
              icon: Icons.lock_outline_rounded,
              obscure: _obscurePassword,
              onToggleObscure: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              // ✅ PERBAIKAN VALIDASI PASSWORD DI SINI
              validator: (v) {
                if (v == null || v.isEmpty) return 'Password wajib diisi';
                if (v.length < 6) return 'Password minimal 6 karakter';
                if (!RegExp(r'^(?=.*[a-zA-Z])(?=.*\d).+$').hasMatch(v)) {
                  return 'Password harus kombinasi huruf dan angka';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            _fieldLabel('Konfirmasi Password'),
            const SizedBox(height: 6),
            _buildField(
              controller: _confirmController,
              hint: 'Ulangi password',
              icon: Icons.lock_reset_rounded,
              obscure: _obscureConfirm,
              onToggleObscure: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Konfirmasi wajib diisi';
                return null; 
              },
            ),
            const SizedBox(height: 18),

            // Checkbox
            GestureDetector(
              onTap: () => setState(() => _isChecked = !_isChecked),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: Checkbox(
                      value: _isChecked,
                      onChanged: (v) => setState(() => _isChecked = v ?? false),
                      activeColor: const Color(0xFF1565C0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      side: BorderSide(color: Colors.grey.shade400, width: 1.5),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        text: 'Saya setuju dengan ',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                        children: [
                          TextSpan(
                            text: 'Syarat & Ketentuan',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: const Color(0xFF1565C0),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextSpan(
                            text: ' yang berlaku',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF1565C0),
                      Color(0xFF1E88E5),
                      Color(0xFF42A5F5),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1565C0).withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _isLoading ? null : _handleRegister,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          'DAFTAR',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            letterSpacing: 1.5,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 22),

            Row(
              children: [
                Expanded(
                  child: Divider(color: Colors.grey.shade200, thickness: 1),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'atau',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ),
                Expanded(
                  child: Divider(color: Colors.grey.shade200, thickness: 1),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            Center(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.pop(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 32,
                  ),
                  child: RichText(
                    text: TextSpan(
                      text: 'Sudah punya akun? ',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                      children: [
                        TextSpan(
                          text: 'Login',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: const Color(0xFF1565C0),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
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

  // ── Helpers ───────────────────────────────────────────────
  Widget _fieldLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 0),
    child: Text(
      label,
      style: GoogleFonts.outfit(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF1565C0),
        letterSpacing: 0.2,
      ),
    ),
  );

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    VoidCallback? onToggleObscure,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF0D2137)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.outfit(
          color: Colors.grey.shade400,
          fontSize: 13,
        ),
        prefixIcon: Icon(icon, color: Colors.grey.shade400, size: 20),
        suffixIcon: onToggleObscure != null
            ? IconButton(
                icon: Icon(
                  obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.grey.shade400,
                  size: 20,
                ),
                onPressed: onToggleObscure,
              )
            : null,
        filled: true,
        fillColor: const Color(0xFFF4F8FF),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: const Color(0xFF1565C0).withOpacity(0.1),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1565C0), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        errorStyle: GoogleFonts.outfit(fontSize: 11),
      ),
      validator: validator,
    );
  }
}

// ── Wave Painter ──────────────────────────────────────────
class _WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p1 = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.fill;
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height * 0.55)
        ..cubicTo(
          size.width * 0.25,
          size.height * 0.3,
          size.width * 0.55,
          size.height * 0.75,
          size.width,
          size.height * 0.45,
        )
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close(),
      p1,
    );
    final p2 = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.fill;
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height * 0.75)
        ..cubicTo(
          size.width * 0.3,
          size.height * 0.5,
          size.width * 0.65,
          size.height * 0.88,
          size.width,
          size.height * 0.65,
        )
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close(),
      p2,
    );
  }

  @override
  bool shouldRepaint(covariant _WavePainter _) => false;
}