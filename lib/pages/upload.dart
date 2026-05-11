import 'dart:ui';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/app_session_service.dart';
import '../services/document_format_screening_service.dart';
import '../services/sipora_api_service.dart';

class UploadPage extends StatefulWidget {
  const UploadPage({super.key});

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  final SiporaApiService _apiService = SiporaApiService();
  final DocumentFormatScreeningService _formatScreeningService =
      DocumentFormatScreeningService();

  // ═══ File Utama ═══
  String? _namaFileUtama;
  Uint8List? _bytesFileUtama;
  int _ukuranFileUtama = 0;
  bool _hasFileUtama = false;
  bool _isScreeningFormat = false;
  DocumentFormatScreeningResult? _screeningResult;
  String? _screeningError;

  // ═══ File Turnitin ═══
  String? _namaFileTurnitin;
  int _ukuranFileTurnitin = 0;
  bool _hasFileTurnitin = false;

  // ═══ Controllers ═══
  final _judulController = TextEditingController();
  final _abstrakController = TextEditingController();
  final _penulisController = TextEditingController();
  final _kataKunciController = TextEditingController();
  final _skorController = TextEditingController();

  // ═══ Dropdowns ═══
  String? _selectedTipe;
  String? _selectedTahun;
  String? _selectedJurusan;
  String? _selectedProdi;
  String? _selectedDivisi;
  String? _selectedTema;
  bool _isLookupLoading = true;
  String? _lookupError;

  late AnimationController _glowController;
  late AnimationController _loadingSpinnerController;

  final List<String> _penulisList = [];
  final List<String> _kataKunciList = [];

  double _getWidth(double percentage) {
    return MediaQuery.of(context).size.width * percentage;
  }

  double _getFontSize(double baseSize) {
    return baseSize *
        (MediaQuery.of(context).size.width / 400).clamp(0.65, 1.1);
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // ═══ Data Lists ═══
  List<String> _tipeDokumen = const [];
  List<String> _tahunList = const [];
  List<String> _jurusanList = const [];
  List<String> _prodiList = const [];
  List<String> _divisiList = const [];
  List<String> _temaList = const [];

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _loadingSpinnerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _judulController.addListener(_onFormFieldChanged);
    _abstrakController.addListener(_onFormFieldChanged);
    _penulisController.addListener(_onFormFieldChanged);
    _kataKunciController.addListener(_onFormFieldChanged);
    _skorController.addListener(_onFormFieldChanged);
    _loadLookupOptions();
  }

  void _onFormFieldChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadLookupOptions() async {
    if (mounted) {
      setState(() {
        _isLookupLoading = true;
        _lookupError = null;
      });
    }

    try {
      final lookup = await _apiService.fetchLookupOptions();
      if (!mounted) return;

      setState(() {
        _tipeDokumen = _normalizeLookupList(lookup['tipe_dokumen']);
        _tahunList = _normalizeLookupList(lookup['tahun']);
        _jurusanList = _normalizeLookupList(lookup['jurusan']);
        _prodiList = _normalizeLookupList(lookup['prodi']);
        _divisiList = _normalizeLookupList(lookup['divisi']);
        _temaList = _normalizeLookupList(lookup['tema']);

        if (_selectedTipe != null && !_tipeDokumen.contains(_selectedTipe)) {
          _selectedTipe = null;
        }
        if (_selectedTahun != null && !_tahunList.contains(_selectedTahun)) {
          _selectedTahun = null;
        }
        if (_selectedJurusan != null &&
            !_jurusanList.contains(_selectedJurusan)) {
          _selectedJurusan = null;
        }
        if (_selectedProdi != null && !_prodiList.contains(_selectedProdi)) {
          _selectedProdi = null;
        }
        if (_selectedDivisi != null && !_divisiList.contains(_selectedDivisi)) {
          _selectedDivisi = null;
        }
        if (_selectedTema != null && !_temaList.contains(_selectedTema)) {
          _selectedTema = null;
        }

        _isLookupLoading = false;
        if (_tipeDokumen.isEmpty ||
            _tahunList.isEmpty ||
            _jurusanList.isEmpty ||
            _prodiList.isEmpty ||
            _divisiList.isEmpty ||
            _temaList.isEmpty) {
          _lookupError =
              'Data dropdown dari database belum lengkap. Periksa tabel master.';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLookupLoading = false;
        _lookupError = 'Gagal mengambil data dropdown dari database.';
      });
    }
  }

  List<String> _normalizeLookupList(dynamic raw) {
    final source = (raw as List?) ?? const [];
    final cleaned = source
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    return cleaned;
  }

  @override
  void dispose() {
    _glowController.dispose();
    _loadingSpinnerController.dispose();
    _judulController.removeListener(_onFormFieldChanged);
    _judulController.dispose();
    _abstrakController.removeListener(_onFormFieldChanged);
    _abstrakController.dispose();
    _penulisController.removeListener(_onFormFieldChanged);
    _penulisController.dispose();
    _kataKunciController.removeListener(_onFormFieldChanged);
    _kataKunciController.dispose();
    _skorController.removeListener(_onFormFieldChanged);
    _skorController.dispose();
    super.dispose();
  }

  // ═══ File Pickers ═══
  Future<void> _pickFileUtama() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['docx', 'pdf'],
      withData: true,
    );
    if (result != null) {
      final f = result.files.single;
      if (f.size > 10 * 1024 * 1024) {
        _showSnackBar('File melebihi batas 10MB!');
        return;
      }
      setState(() {
        _namaFileUtama = f.name;
        _bytesFileUtama = f.bytes;
        _ukuranFileUtama = f.size;
        _hasFileUtama = true;
        _isScreeningFormat = false;
        _screeningResult = null;
        _screeningError = null;
      });

      await _runFormatScreeningIfNeeded();
    }
  }

  Future<void> _onTipeDokumenChanged(String? val) async {
    setState(() => _selectedTipe = val);
    await _runFormatScreeningIfNeeded();
  }

  bool _isScreeningSupportedFile(String? fileName) {
    if (fileName == null) return false;
    return _formatScreeningService.isSupportedForScreening(fileName);
  }

  Future<void> _runFormatScreeningIfNeeded() async {
    if (!_hasFileUtama || _namaFileUtama == null) {
      return;
    }

    if (!_isScreeningSupportedFile(_namaFileUtama)) {
      if (!mounted) return;
      setState(() {
        _isScreeningFormat = false;
        _screeningResult = null;
        _screeningError = 'Screening otomatis hanya mendukung DOCX atau PDF.';
      });
      return;
    }

    if (_bytesFileUtama == null) {
      if (!mounted) return;
      setState(() {
        _isScreeningFormat = false;
        _screeningResult = null;
        _screeningError =
            'Tidak dapat membaca isi file. Pilih ulang file agar bisa discreening.';
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _isScreeningFormat = true;
      _screeningResult = null;
      _screeningError = null;
    });

    try {
      final result = await _formatScreeningService.screenDocument(
        bytes: _bytesFileUtama!,
        fileName: _namaFileUtama!,
        tipeDokumen: _selectedTipe?.trim() ?? '',
      );

      if (!mounted) return;
      setState(() {
        _isScreeningFormat = false;
        _screeningResult = result;
        _screeningError = null;
        if (_isTurnitinLocked) {
          _clearTurnitinInputs();
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isScreeningFormat = false;
        _screeningResult = null;
        _screeningError =
            'Screening format gagal diproses. Pastikan file DOCX tidak rusak.';
        _clearTurnitinInputs();
      });
    }
  }

  bool get _isTurnitinLocked {
    final result = _screeningResult;
    if (_isScreeningFormat) {
      return true;
    }

    if (!_isScreeningSupportedFile(_namaFileUtama)) {
      return false;
    }

    if (_screeningError != null) {
      return true;
    }

    if (result == null) {
      return true;
    }

    return !result.canAnalyze || !result.passed;
  }

  void _clearTurnitinInputs() {
    _namaFileTurnitin = null;
    _ukuranFileTurnitin = 0;
    _hasFileTurnitin = false;
    _skorController.clear();
  }

  bool _isCheckPassed(String check) {
    final lower = check.toLowerCase();
    return !RegExp(r'\b(kurang|belum|tidak|gagal|error)\b').hasMatch(lower);
  }

  List<String> _buildScreeningRecommendations(DocumentFormatScreeningResult r) {
    final failedChecks = r.checks.where((c) => !_isCheckPassed(c)).toList();
    if (failedChecks.isEmpty) {
      return const <String>[
        'Dokumen sudah memenuhi aturan screening. Lanjutkan ke tahap pengisian metadata dan unggah.',
      ];
    }

    final recommendations = <String>[];
    for (final check in failedChecks) {
      final lower = check.toLowerCase();
      if (lower.contains('heading')) {
        recommendations.add(
          'Tambahkan heading/bab utama sesuai struktur dokumen agar bagian penting mudah terdeteksi.',
        );
      } else if (lower.contains('paragraf') || lower.contains('rapi')) {
        recommendations.add(
          'Rapikan paragraf isi dengan format konsisten dan hindari baris terlalu pendek agar lolos indikator kerapian.',
        );
      } else if (lower.contains('bagian wajib') ||
          lower.contains('pendahuluan') ||
          lower.contains('abstrak') ||
          lower.contains('bab')) {
        recommendations.add(
          'Lengkapi bagian wajib dokumen (mis. abstrak, pendahuluan, atau susunan BAB) sesuai jenis dokumen.',
        );
      } else {
        recommendations.add(
          'Periksa ulang format pada poin yang ditandai revisi, lalu unggah ulang file untuk screening terbaru.',
        );
      }
    }

    return recommendations.toSet().toList();
  }

  Future<void> _pickFileTurnitin() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null) {
      final f = result.files.single;
      if (f.size > 5 * 1024 * 1024) {
        _showSnackBar('File melebihi batas 5MB!');
        return;
      }
      setState(() {
        _namaFileTurnitin = f.name;
        _ukuranFileTurnitin = f.size;
        _hasFileTurnitin = true;
      });
    }
  }

  void _removeFileUtama() => setState(() {
    _namaFileUtama = null;
    _bytesFileUtama = null;
    _ukuranFileUtama = 0;
    _hasFileUtama = false;
    _isScreeningFormat = false;
    _screeningResult = null;
    _screeningError = null;
  });

  void _removeFileTurnitin() => setState(() {
    _namaFileTurnitin = null;
    _ukuranFileTurnitin = 0;
    _hasFileTurnitin = false;
  });

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ═══ Submit ═══
  Future<void> _submitForm() async {
    if (!_hasFileUtama) {
      _showSnackBar('Silakan pilih file utama terlebih dahulu!');
      return;
    }
    if (_isLookupLoading) {
      _showSnackBar('Data dropdown dari database masih dimuat.');
      return;
    }
    if (_lookupError != null) {
      _showSnackBar(_lookupError!);
      return;
    }
    if (_formKey.currentState!.validate()) {
      if (_selectedTahun == null ||
          _selectedJurusan == null ||
          _selectedProdi == null ||
          _selectedDivisi == null ||
          _selectedTema == null) {
        _showSnackBar('Semua pilihan dropdown wajib diisi.');
        return;
      }

      if (_isScreeningSupportedFile(_namaFileUtama)) {
        if (_isScreeningFormat) {
          _showSnackBar('Screening format sedang berjalan, tunggu sebentar.');
          return;
        }

        if (_screeningError != null) {
          _showSnackBar(_screeningError!);
          return;
        }

        if (_screeningResult == null || !_screeningResult!.passed) {
          _showSnackBar(
            'Format dokumen belum sesuai. Perbaiki format lalu upload ulang.',
          );
          return;
        }
      }

      setState(() => _isLoading = true);
      _loadingSpinnerController.repeat();

      try {
        await _apiService.uploadDocument(
          judul: _judulController.text.trim(),
          abstrak: _abstrakController.text.trim(),
          filePath: _namaFileUtama ?? '',
          fileBytes: _bytesFileUtama!,
          tahun: _selectedTahun!,
          jurusan: _selectedJurusan!,
          prodi: _selectedProdi!,
          divisi: _selectedDivisi!,
          tema: _selectedTema!,
          tipeDokumen: _selectedTipe ?? '',
          penulis: _penulisList,
          kataKunci: _kataKunciList,
          turnitin: int.tryParse(_skorController.text.trim()) ?? 0,
          turnitinFile: _namaFileTurnitin,
          uploaderId: AppSessionService.currentUserId ?? 1,
          uploaderEmail: AppSessionService.currentEmail,
        );

        if (mounted) {
          _loadingSpinnerController.stop();
          setState(() => _isLoading = false);
          _showSuccessDialog();
        }
      } catch (e) {
        if (mounted) {
          _loadingSpinnerController.stop();
          setState(() => _isLoading = false);
          _showSnackBar(e.toString().replaceFirst('Exception: ', ''));
        }
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutBack,
              builder: (context, value, child) => Transform.scale(
                scale: value,
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.green.shade50,
                  ),
                  child: Icon(
                    Icons.check_circle,
                    color: Colors.green.shade600,
                    size: 42,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Upload Berhasil!',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: const Color(0xFF1E3A5F),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Dokumen Anda sedang dalam proses review.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _resetForm();
            },
            child: Text(
              'OK',
              style: GoogleFonts.outfit(
                color: const Color(0xFF1565C0),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _resetForm() {
    setState(() {
      _namaFileUtama = null;
      _bytesFileUtama = null;
      _ukuranFileUtama = 0;
      _hasFileUtama = false;
      _namaFileTurnitin = null;
      _ukuranFileTurnitin = 0;
      _hasFileTurnitin = false;
      _isScreeningFormat = false;
      _screeningResult = null;
      _screeningError = null;
      _judulController.clear();
      _abstrakController.clear();
      _penulisController.clear();
      _kataKunciController.clear();
      _skorController.clear();
      _selectedTipe = null;
      _selectedTahun = null;
      _selectedJurusan = null;
      _selectedProdi = null;
      _selectedDivisi = null;
      _selectedTema = null;
      _penulisList.clear();
      _kataKunciList.clear();
    });
  }

  void _showAddDialog({
    required String title,
    required Function(String) onAdd,
  }) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          title,
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          style: GoogleFonts.outfit(fontSize: 14),
          decoration: InputDecoration(
            hintText: "Masukkan $title",
            filled: true,
            fillColor: const Color(0xFFFAFBFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF1565C0)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              "Batal",
              style: GoogleFonts.outfit(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              if (controller.text.isNotEmpty) {
                onAdd(controller.text);
                Navigator.pop(ctx);
              }
            },
            child: Text(
              "Simpan",
              style: GoogleFonts.outfit(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SafeArea(
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(
                context,
              ).copyWith(scrollbars: false),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: EdgeInsets.all(_getWidth(0.04)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPageHeader(),
                      SizedBox(height: _getWidth(0.05)),
                      _buildCardUploadUtama(),
                      SizedBox(height: _getWidth(0.04)),
                      _buildCardUploadTurnitin(),
                      SizedBox(height: _getWidth(0.04)),
                      _buildFormSectionCard(),
                      SizedBox(height: _getWidth(0.05)),
                      _buildSubmitButton(),
                      SizedBox(height: _getWidth(0.04)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════
  //  PAGE HEADER
  // ══════════════════════════════════════════════════════════
  Widget _buildPageHeader() {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(_getWidth(0.02)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_getWidth(0.02)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            Icons.upload_file_rounded,
            color: const Color(0xFF1565C0),
            size: _getFontSize(26),
          ),
        ),
        SizedBox(width: _getWidth(0.03)),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Upload Dokumen",
              style: TextStyle(
                fontSize: _getFontSize(18),
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E3A5F),
              ),
            ),
            Text(
              "Lengkapi data di bawah ini",
              style: TextStyle(
                fontSize: _getFontSize(12),
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════
  //  CARD UPLOAD FILE UTAMA
  // ══════════════════════════════════════════════════════════
  Widget _buildCardUploadUtama() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(_getWidth(0.04)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label row
            Row(
              children: [
                Icon(
                  Icons.upload_file,
                  size: _getFontSize(20),
                  color: const Color(0xFF1E3A5F),
                ),
                SizedBox(width: _getWidth(0.015)),
                Text(
                  "Upload File Utama",
                  style: TextStyle(
                    fontSize: _getFontSize(15),
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E3A5F),
                  ),
                ),
                Text(
                  " *",
                  style: TextStyle(
                    fontSize: _getFontSize(15),
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFF44336),
                  ),
                ),
              ],
            ),
            SizedBox(height: _getWidth(0.02)),

            // Dashed upload area — semua content center
            CustomPaint(
              painter: _DashedBorderPainter(),
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: _getWidth(0.04),
                    horizontal: _getWidth(0.03),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Glow icon
                      AnimatedBuilder(
                        animation: _glowController,
                        builder: (ctx, child) {
                          return Container(
                            padding: EdgeInsets.all(_getWidth(0.025)),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _hasFileUtama
                                  ? Colors.green.shade50
                                  : Colors.blue.shade50.withOpacity(0.5),
                              boxShadow: [
                                BoxShadow(
                                  color: _hasFileUtama
                                      ? Colors.green.withOpacity(0.2)
                                      : const Color(0xFF1565C0).withOpacity(
                                          0.1 + (_glowController.value * 0.15),
                                        ),
                                  blurRadius: 12 + (_glowController.value * 8),
                                  spreadRadius: _glowController.value * 4,
                                ),
                              ],
                            ),
                            child: Icon(
                              _hasFileUtama
                                  ? Icons.check_circle_outline
                                  : Icons.cloud_upload_rounded,
                              size: _getFontSize(40),
                              color: _hasFileUtama
                                  ? Colors.green.shade600
                                  : const Color(0xFF1565C0),
                            ),
                          );
                        },
                      ),
                      SizedBox(height: _getWidth(0.025)),
                      Text(
                        "Klik untuk upload atau drag & drop file",
                        style: TextStyle(
                          fontSize: _getFontSize(13),
                          color: const Color(0xFF333333),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: _getWidth(0.005)),
                      Text(
                        "DOCX, PDF (Maksimal 10MB)",
                        style: TextStyle(
                          fontSize: _getFontSize(11),
                          color: const Color(0xFF888888),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: _getWidth(0.025)),

                      // Tombol Pilih File
                      ElevatedButton(
                        onPressed: _pickFileUtama,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2196F3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                          padding: EdgeInsets.symmetric(
                            horizontal: _getWidth(0.06),
                            vertical: _getWidth(0.02),
                          ),
                        ),
                        child: Text(
                          "Pilih File",
                          style: TextStyle(
                            fontSize: _getFontSize(13),
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      // File info row
                      if (_hasFileUtama) ...[
                        SizedBox(height: _getWidth(0.025)),
                        _buildFileInfoRow(
                          fileName: _namaFileUtama!,
                          fileSize: _ukuranFileUtama,
                          iconColor: const Color(0xFF757575),
                          onRemove: _removeFileUtama,
                        ),
                        SizedBox(height: _getWidth(0.02)),
                        _buildFormatScreeningPanel(),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  CARD UPLOAD TURNITIN
  // ══════════════════════════════════════════════════════════
  Widget _buildCardUploadTurnitin() {
    final isTurnitinLocked = _isTurnitinLocked;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(_getWidth(0.04)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label row
            Row(
              children: [
                Icon(
                  Icons.verified_user,
                  size: _getFontSize(20),
                  color: const Color(0xFF1E3A5F),
                ),
                SizedBox(width: _getWidth(0.015)),
                Text(
                  "Upload Turnitin (Opsional)",
                  style: TextStyle(
                    fontSize: _getFontSize(15),
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E3A5F),
                  ),
                ),
              ],
            ),
            SizedBox(height: _getWidth(0.02)),

            // Dashed upload area
            Opacity(
              opacity: isTurnitinLocked ? 0.45 : 1,
              child: IgnorePointer(
                ignoring: isTurnitinLocked,
                child: CustomPaint(
                  painter: _DashedBorderPainter(),
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: _getWidth(0.04),
                        horizontal: _getWidth(0.03),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.cloud_upload_outlined,
                            size: _getFontSize(40),
                            color: const Color(0xFF757575),
                          ),
                          SizedBox(height: _getWidth(0.025)),
                          Text(
                            "Upload laporan Turnitin (jika ada)",
                            style: TextStyle(
                              fontSize: _getFontSize(13),
                              color: const Color(0xFF333333),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: _getWidth(0.005)),
                          Text(
                            "PDF (Maksimal 5MB)",
                            style: TextStyle(
                              fontSize: _getFontSize(11),
                              color: const Color(0xFF888888),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: _getWidth(0.025)),
                          ElevatedButton(
                            onPressed: _pickFileTurnitin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2196F3),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 0,
                              padding: EdgeInsets.symmetric(
                                horizontal: _getWidth(0.06),
                                vertical: _getWidth(0.02),
                              ),
                            ),
                            child: Text(
                              "Pilih File Turnitin",
                              style: TextStyle(
                                fontSize: _getFontSize(13),
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),

                          // File info row
                          if (_hasFileTurnitin) ...[
                            SizedBox(height: _getWidth(0.025)),
                            _buildFileInfoRow(
                              fileName: _namaFileTurnitin!,
                              fileSize: _ukuranFileTurnitin,
                              iconColor: const Color(0xFF4CAF50),
                              onRemove: _removeFileTurnitin,
                            ),
                          ],

                          // Skor Turnitin Section
                          SizedBox(height: _getWidth(0.04)),
                          _buildSkorTurnitinSection(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (isTurnitinLocked) ...[
              SizedBox(height: _getWidth(0.02)),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(_getWidth(0.03)),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFFE0B2)),
                ),
                child: Text(
                  'Turnitin dinonaktifkan sampai dokumen lolos screening format.',
                  style: TextStyle(
                    fontSize: _getFontSize(11.5),
                    color: const Color(0xFF8A4B00),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  SKOR TURNITIN
  // ══════════════════════════════════════════════════════════
  Widget _buildSkorTurnitinSection() {
    final isTurnitinLocked = _isTurnitinLocked;
    return Container(
      padding: EdgeInsets.all(_getWidth(0.03)),
      decoration: BoxDecoration(
        color: isTurnitinLocked
            ? const Color(0xFFF2F2F2)
            : const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(_getWidth(0.02)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.verified_user,
                size: _getFontSize(20),
                color: isTurnitinLocked
                    ? const Color(0xFF9E9E9E)
                    : const Color(0xFF4CAF50),
              ),
              SizedBox(width: _getWidth(0.02)),
              Text(
                "Skor Turnitin",
                style: GoogleFonts.outfit(
                  fontSize: _getFontSize(14),
                  fontWeight: FontWeight.bold,
                  color: isTurnitinLocked
                      ? const Color(0xFF757575)
                      : const Color(0xFF2E7D32),
                ),
              ),
              SizedBox(width: _getWidth(0.01)),
              Text(
                "OPSIONAL",
                style: GoogleFonts.outfit(
                  fontSize: _getFontSize(12),
                  fontWeight: FontWeight.bold,
                  color: isTurnitinLocked
                      ? const Color(0xFF9E9E9E)
                      : const Color(0xFF757575),
                ),
              ),
            ],
          ),
          SizedBox(height: _getWidth(0.02)),
          Padding(
            padding: EdgeInsets.only(left: _getWidth(0.07)),
            child: Text(
              "Persentase Kemiripan",
              style: GoogleFonts.outfit(
                fontSize: _getFontSize(13),
                color: const Color(0xFF333333),
              ),
            ),
          ),
          SizedBox(height: _getWidth(0.01)),
          Padding(
            padding: EdgeInsets.only(left: _getWidth(0.07)),
            child: Row(
              children: [
                SizedBox(
                  width: _getWidth(0.2),
                  child: TextField(
                    controller: _skorController,
                    enabled: !isTurnitinLocked,
                    keyboardType: TextInputType.number,
                    maxLength: 3,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(fontSize: _getFontSize(13)),
                    decoration: InputDecoration(
                      hintText: '0',
                      counterText: '',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        vertical: _getWidth(0.02),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(_getWidth(0.015)),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(_getWidth(0.015)),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(_getWidth(0.015)),
                        borderSide: const BorderSide(color: Color(0xFF4CAF50)),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: _getWidth(0.02)),
                Text(
                  '%',
                  style: GoogleFonts.outfit(
                    fontSize: _getFontSize(13),
                    color: const Color(0xFF333333),
                  ),
                ),
                SizedBox(width: _getWidth(0.03)),
                Text(
                  '(0-100%)',
                  style: GoogleFonts.outfit(
                    fontSize: _getFontSize(12),
                    color: const Color(0xFF757575),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: _getWidth(0.015)),
          Padding(
            padding: EdgeInsets.only(left: _getWidth(0.07)),
            child: Text(
              "Masukkan skor presentase kemiripan dari Turnitin (0-100%). Kosongkan jika tidak ada.",
              style: GoogleFonts.outfit(
                fontSize: _getFontSize(11),
                color: isTurnitinLocked
                    ? const Color(0xFF9E9E9E)
                    : const Color(0xFF757575),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  FILE INFO ROW
  // ══════════════════════════════════════════════════════════
  Widget _buildFileInfoRow({
    required String fileName,
    required int fileSize,
    required Color iconColor,
    required VoidCallback onRemove,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: _getWidth(0.025),
        vertical: _getWidth(0.015),
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFC),
        borderRadius: BorderRadius.circular(_getWidth(0.015)),
        border: Border.all(color: Colors.grey.shade200, width: 0.5),
      ),
      child: Row(
        children: [
          Icon(
            Icons.insert_drive_file,
            size: _getFontSize(20),
            color: iconColor,
          ),
          SizedBox(width: _getWidth(0.015)),
          Expanded(
            child: Text(
              fileName,
              style: GoogleFonts.outfit(
                fontSize: _getFontSize(13),
                color: const Color(0xFF1E3A5F),
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          SizedBox(width: _getWidth(0.02)),
          Text(
            _formatSize(fileSize),
            style: GoogleFonts.outfit(
              fontSize: _getFontSize(12),
              color: Colors.grey.shade600,
            ),
          ),
          SizedBox(width: _getWidth(0.02)),
          GestureDetector(
            onTap: onRemove,
            child: Icon(
              Icons.close,
              size: _getFontSize(20),
              color: const Color(0xFFF44336),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatScreeningPanel() {
    final hasType = _selectedTipe != null;
    final hasFile = _hasFileUtama;
    final score = _screeningResult?.score.round() ?? 0;
    final baseColor = _screeningResult == null
        ? const Color(0xFFE3F2FD)
        : _screeningResult!.passed
        ? const Color(0xFFE8F5E9)
        : const Color(0xFFFFEBEE);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(_getWidth(0.03)),
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(_getWidth(0.02)),
        border: Border.all(
          color: _screeningResult == null
              ? const Color(0xFFBBDEFB)
              : _screeningResult!.passed
              ? const Color(0xFFA5D6A7)
              : const Color(0xFFEF9A9A),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Screening Otomatis',
                  style: GoogleFonts.outfit(
                    fontSize: _getFontSize(13),
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E3A5F),
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: _getWidth(0.025),
                  vertical: _getWidth(0.012),
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(_getWidth(0.016)),
                  border: Border.all(
                    color: _screeningResult == null
                        ? const Color(0xFFBBDEFB)
                        : _screeningResult!.passed
                        ? const Color(0xFFA5D6A7)
                        : const Color(0xFFEF9A9A),
                  ),
                ),
                child: Text(
                  '$score',
                  style: GoogleFonts.outfit(
                    fontSize: _getFontSize(16),
                    fontWeight: FontWeight.w800,
                    color: _screeningResult == null
                        ? const Color(0xFF1565C0)
                        : _screeningResult!.passed
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFFC62828),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: _getWidth(0.012)),
          if (!hasFile)
            Text(
              'Pilih file dokumen terlebih dahulu untuk memulai screening otomatis.',
              style: GoogleFonts.outfit(fontSize: _getFontSize(11)),
            ),
          if (hasFile && !hasType)
            Text(
              'Jenis dokumen belum dipilih. Screening berjalan dengan aturan umum dan akan diperbarui otomatis setelah jenis dipilih.',
              style: GoogleFonts.outfit(fontSize: _getFontSize(11)),
            ),
          if (hasFile && _isScreeningFormat) ...[
            Row(
              children: [
                SizedBox(
                  width: _getWidth(0.04),
                  height: _getWidth(0.04),
                  child: const CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: _getWidth(0.02)),
                Expanded(
                  child: Text(
                    'Sedang screening dokumen (YOLOv8 + OCR)...',
                    style: GoogleFonts.outfit(fontSize: _getFontSize(11)),
                  ),
                ),
              ],
            ),
          ],
          if (hasFile && _screeningError != null)
            Text(
              _screeningError!,
              style: GoogleFonts.outfit(
                fontSize: _getFontSize(11),
                color: const Color(0xFFC62828),
              ),
            ),
          if (hasFile && _screeningResult != null) ...[
            Container(
              padding: EdgeInsets.all(_getWidth(0.018)),
              decoration: BoxDecoration(
                color: _screeningResult!.passed
                    ? const Color(0xFFE8F5E9)
                    : const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(_getWidth(0.014)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _screeningResult!.passed
                        ? Icons.check_circle_rounded
                        : Icons.error_rounded,
                    color: _screeningResult!.passed
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFFC62828),
                    size: _getFontSize(18),
                  ),
                  SizedBox(width: _getWidth(0.015)),
                  Expanded(
                    child: Text(
                      _screeningResult!.summary,
                      style: GoogleFonts.outfit(
                        fontSize: _getFontSize(11),
                        color: _screeningResult!.passed
                            ? const Color(0xFF1B5E20)
                            : const Color(0xFFB71C1C),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: _getWidth(0.012)),
            Wrap(
              spacing: _getWidth(0.012),
              runSpacing: _getWidth(0.008),
              children: [
                _buildScreeningMetaChip('Engine: ${_screeningResult!.engine}'),
                _buildScreeningMetaChip('Skor: $score%'),
                _buildScreeningMetaChip(
                  'Halaman: ${_screeningResult!.totalPages}',
                ),
                _buildScreeningMetaChip(
                  'Paragraf: ${_screeningResult!.totalParagraphs}',
                ),
              ],
            ),
            SizedBox(height: _getWidth(0.012)),
            ..._screeningResult!.checks.map((check) {
              final passed = _isCheckPassed(check);
              return Container(
                margin: EdgeInsets.only(bottom: _getWidth(0.008)),
                padding: EdgeInsets.symmetric(
                  horizontal: _getWidth(0.018),
                  vertical: _getWidth(0.012),
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(_getWidth(0.012)),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Icon(
                      passed
                          ? Icons.check_circle_outline
                          : Icons.cancel_outlined,
                      size: _getFontSize(16),
                      color: passed
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFFC62828),
                    ),
                    SizedBox(width: _getWidth(0.015)),
                    Expanded(
                      child: Text(
                        check,
                        style: GoogleFonts.outfit(fontSize: _getFontSize(10.8)),
                      ),
                    ),
                    SizedBox(width: _getWidth(0.01)),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: _getWidth(0.016),
                        vertical: _getWidth(0.006),
                      ),
                      decoration: BoxDecoration(
                        color: passed
                            ? const Color(0xFFE8F5E9)
                            : const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(_getWidth(0.02)),
                      ),
                      child: Text(
                        passed ? 'OK' : 'REVISI',
                        style: GoogleFonts.outfit(
                          fontSize: _getFontSize(9.5),
                          fontWeight: FontWeight.w700,
                          color: passed
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFFC62828),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            Container(
              width: double.infinity,
              margin: EdgeInsets.only(top: _getWidth(0.006)),
              padding: EdgeInsets.all(_getWidth(0.018)),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F8FF),
                borderRadius: BorderRadius.circular(_getWidth(0.012)),
                border: Border.all(color: const Color(0xFFBBDEFB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rekomendasi AI',
                    style: GoogleFonts.outfit(
                      fontSize: _getFontSize(11.2),
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E3A5F),
                    ),
                  ),
                  SizedBox(height: _getWidth(0.008)),
                  ..._buildScreeningRecommendations(_screeningResult!).map(
                    (item) => Padding(
                      padding: EdgeInsets.only(bottom: _getWidth(0.006)),
                      child: Text(
                        '• $item',
                        style: GoogleFonts.outfit(
                          fontSize: _getFontSize(10.5),
                          color: const Color(0xFF455A64),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  CARD INFORMASI DOKUMEN
  // ══════════════════════════════════════════════════════════
  Widget _buildFormSectionCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(_getWidth(0.05)),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Informasi Dokumen",
                style: TextStyle(
                  fontSize: _getFontSize(16),
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E3A5F),
                ),
              ),
              SizedBox(height: _getWidth(0.04)),
              _buildInputField(
                "Judul Dokumen",
                _judulController,
                hint: "Masukkan judul lengkap dokumen",
              ),
              SizedBox(height: _getWidth(0.03)),
              _buildInputField(
                "Abstrak",
                _abstrakController,
                maxLines: 4,
                hint: "Masukkan Abstrak atau deskripsi singkat dokumen",
              ),
              SizedBox(height: _getWidth(0.03)),
              Row(
                children: [
                  Expanded(
                    child: _buildDropdown(
                      "Jenis Dokumen",
                      _selectedTipe,
                      _tipeDokumen,
                      _onTipeDokumenChanged,
                      requiredField: false,
                    ),
                  ),
                  SizedBox(width: _getWidth(0.03)),
                  Expanded(
                    child: _buildDropdown(
                      "Tahun",
                      _selectedTahun,
                      _tahunList,
                      (val) => setState(() => _selectedTahun = val),
                    ),
                  ),
                ],
              ),
              SizedBox(height: _getWidth(0.03)),
              Row(
                children: [
                  Expanded(
                    child: _buildDropdown(
                      "Divisi",
                      _selectedDivisi,
                      _divisiList,
                      (val) => setState(() => _selectedDivisi = val),
                    ),
                  ),
                  SizedBox(width: _getWidth(0.03)),
                  Expanded(
                    child: _buildDropdown(
                      "Tema",
                      _selectedTema,
                      _temaList,
                      (val) => setState(() => _selectedTema = val),
                    ),
                  ),
                ],
              ),
              SizedBox(height: _getWidth(0.03)),
              _buildDropdown(
                "Jurusan",
                _selectedJurusan,
                _jurusanList,
                (val) => setState(() => _selectedJurusan = val),
              ),
              SizedBox(height: _getWidth(0.02)),
              _buildDropdown(
                "Program Studi",
                _selectedProdi,
                _prodiList,
                (val) => setState(() => _selectedProdi = val),
              ),
              SizedBox(height: _getWidth(0.03)),
              _buildInputField(
                "Penulis",
                _penulisController,
                hint: "Nama penulis",
              ),
              if (_penulisList.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: _penulisList
                        .map(
                          (p) => Chip(
                            label: Text(
                              p,
                              style: TextStyle(fontSize: _getFontSize(11)),
                            ),
                            backgroundColor: Colors.blue.shade50,
                            labelStyle: TextStyle(color: Colors.blue.shade800),
                            deleteIcon: Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.blue.shade800,
                            ),
                            onDeleted: () =>
                                setState(() => _penulisList.remove(p)),
                          ),
                        )
                        .toList(),
                  ),
                ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _showAddDialog(
                    title: "Tambah Penulis",
                    onAdd: (val) => setState(() => _penulisList.add(val)),
                  ),
                  icon: Icon(
                    Icons.add_circle_outline,
                    size: _getFontSize(16),
                    color: const Color(0xFF1565C0),
                  ),
                  label: Text(
                    "Tambah Penulis",
                    style: TextStyle(
                      color: const Color(0xFF1565C0),
                      fontSize: _getFontSize(11),
                    ),
                  ),
                ),
              ),
              SizedBox(height: _getWidth(0.02)),
              Text(
                "Kata Kunci",
                style: TextStyle(
                  fontSize: _getFontSize(14),
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF333333),
                ),
              ),
              SizedBox(height: _getWidth(0.01)),
              _buildInputFieldNoLabel(
                _kataKunciController,
                hint: "Kata Kunci 1",
              ),
              if (_kataKunciList.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: _kataKunciList
                        .map(
                          (k) => Chip(
                            label: Text(
                              k,
                              style: TextStyle(fontSize: _getFontSize(11)),
                            ),
                            backgroundColor: Colors.orange.shade50,
                            labelStyle: TextStyle(
                              color: Colors.orange.shade800,
                            ),
                            deleteIcon: Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.orange.shade800,
                            ),
                            onDeleted: () =>
                                setState(() => _kataKunciList.remove(k)),
                          ),
                        )
                        .toList(),
                  ),
                ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _showAddDialog(
                    title: "Tambah Kata Kunci",
                    onAdd: (val) => setState(() => _kataKunciList.add(val)),
                  ),
                  icon: Icon(
                    Icons.add_circle_outline,
                    size: _getFontSize(16),
                    color: const Color(0xFF1565C0),
                  ),
                  label: Text(
                    "Tambah Kata Kunci",
                    style: TextStyle(
                      color: const Color(0xFF1565C0),
                      fontSize: _getFontSize(11),
                    ),
                  ),
                ),
              ),
              SizedBox(height: _getWidth(0.03)),
              _buildPerhatianBox(),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  PERHATIAN BOX
  // ══════════════════════════════════════════════════════════
  Widget _buildPerhatianBox() {
    return Container(
      padding: EdgeInsets.all(_getWidth(0.03)),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9C4),
        borderRadius: BorderRadius.circular(_getWidth(0.015)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: _getWidth(0.003)),
            child: Icon(
              Icons.warning_amber_rounded,
              size: _getFontSize(20),
              color: const Color(0xFFF44336),
            ),
          ),
          SizedBox(width: _getWidth(0.02)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Perhatian",
                  style: GoogleFonts.outfit(
                    fontSize: _getFontSize(14),
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFD32F2F),
                  ),
                ),
                SizedBox(height: _getWidth(0.01)),
                Text(
                  "• Pastikan dokumen tidak mengandung informasi yang bersifat rahasia\n"
                  "• Dokumen akan melalui proses review sebelum dipublikasikan\n"
                  "• Anda akan mendapat notifikasi status review melalui email",
                  style: GoogleFonts.outfit(
                    fontSize: _getFontSize(13),
                    color: Colors.black,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScreeningMetaChip(String text) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: _getWidth(0.018),
        vertical: _getWidth(0.008),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_getWidth(0.02)),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          fontSize: _getFontSize(10.2),
          fontWeight: FontWeight.w600,
          color: const Color(0xFF455A64),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  SUBMIT BUTTON
  // ══════════════════════════════════════════════════════════
  Widget _buildSubmitButton() {
    final canSubmit = _canSubmitDocument();
    return SizedBox(
      width: double.infinity,
      height: _getWidth(0.13),
      child: ElevatedButton(
        onPressed: (_isLoading || !canSubmit) ? null : _submitForm,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1565C0),
          disabledBackgroundColor: const Color(0xFF1565C0).withOpacity(0.7),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: _isLoading ? 0 : 4,
          shadowColor: const Color(0xFF1565C0).withOpacity(0.3),
        ),
        child: _isLoading
            ? AnimatedBuilder(
                animation: _loadingSpinnerController,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _loadingSpinnerController.value * 2 * math.pi,
                    child: child,
                  );
                },
                child: CustomPaint(
                  size: const Size(24, 24),
                  painter: _ModernSpinnerPainter(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.file_upload_outlined,
                    color: Colors.white,
                    size: _getFontSize(20),
                  ),
                  SizedBox(width: 8),
                  Text(
                    "Upload Dokumen",
                    style: TextStyle(
                      fontSize: _getFontSize(15),
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  bool _canSubmitDocument() {
    if (_isLoading || _isLookupLoading || _lookupError != null) {
      return false;
    }

    final hasRequiredText =
        _judulController.text.trim().isNotEmpty &&
        _abstrakController.text.trim().isNotEmpty;
    final hasRequiredDropdowns =
        _selectedTahun != null &&
        _selectedJurusan != null &&
        _selectedProdi != null &&
        _selectedDivisi != null &&
        _selectedTema != null;

    if (!hasRequiredText || !hasRequiredDropdowns || !_hasFileUtama) {
      return false;
    }

    if (_isScreeningSupportedFile(_namaFileUtama)) {
      if (_isScreeningFormat) return false;
      if (_screeningError != null) return false;
      if (_screeningResult == null) return false;
      if (!_screeningResult!.passed) return false;
    }

    return true;
  }

  // ══════════════════════════════════════════════════════════
  //  REUSABLE WIDGETS
  // ══════════════════════════════════════════════════════════

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: RichText(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: _getFontSize(13),
            color: const Color(0xFF1E3A5F),
          ),
          children: const [
            TextSpan(
              text: " *",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          style: TextStyle(fontSize: _getFontSize(13)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: _getFontSize(12),
              color: Colors.grey.shade400,
            ),
            filled: true,
            fillColor: const Color(0xFFFAFBFC),
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: Color(0xFF1565C0),
                width: 1.5,
              ),
            ),
            contentPadding: EdgeInsets.all(_getWidth(0.035)),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return '$label wajib diisi';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildInputFieldNoLabel(
    TextEditingController controller, {
    int maxLines = 1,
    String? hint,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(fontSize: _getFontSize(13)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: _getFontSize(12),
          color: Colors.grey.shade400,
        ),
        filled: true,
        fillColor: const Color(0xFFFAFBFC),
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF1565C0), width: 1.5),
        ),
        contentPadding: EdgeInsets.all(_getWidth(0.035)),
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    String? value,
    List<String> items,
    Function(String?) onChanged, {
    bool requiredField = true,
  }) {
    final isDisabled = _isLookupLoading || items.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFAFBFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200, width: 1),
          ),
          child: DropdownButtonFormField<String>(
            initialValue: value,
            isExpanded: true,
            hint: Text(
              _isLookupLoading
                  ? 'Memuat data database...'
                  : items.isEmpty
                  ? 'Data $label belum tersedia'
                  : 'Pilih',
              style: TextStyle(
                fontSize: _getFontSize(12),
                color: Colors.grey.shade400,
              ),
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                vertical: _getWidth(0.032),
                horizontal: _getWidth(0.035),
              ),
            ),
            icon: Icon(
              Icons.arrow_drop_down_rounded,
              color: Colors.grey.shade600,
              size: _getFontSize(24),
            ),
            dropdownColor: Colors.white,
            style: TextStyle(fontSize: _getFontSize(13), color: Colors.black87),
            items: items
                .map(
                  (String e) =>
                      DropdownMenuItem<String>(value: e, child: Text(e)),
                )
                .toList(),
            onChanged: isDisabled ? null : onChanged,
            borderRadius: BorderRadius.circular(14),
            validator: (value) {
              if (_isLookupLoading) return 'Data $label masih dimuat';
              if (items.isEmpty)
                return 'Data $label belum tersedia di database';
              if (requiredField && value == null) return 'Pilih $label';
              return null;
            },
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════
//  DASHED BORDER PAINTER
// ══════════════════════════════════════════════════════════
class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF90CAF9)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const dashWidth = 8.0;
    const dashSpace = 5.0;
    const cornerRadius = 12.0;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          const Radius.circular(cornerRadius),
        ),
      );

    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0.0;
      while (distance < metric.length) {
        final length = math.min(dashWidth, metric.length - distance);
        canvas.drawPath(metric.extractPath(distance, distance + length), paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) => false;
}

// ══════════════════════════════════════════════════════════
//  MODERN SPINNER PAINTER
// ══════════════════════════════════════════════════════════
class _ModernSpinnerPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  _ModernSpinnerPainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final gradient = SweepGradient(
      startAngle: 0.0,
      endAngle: 2 * math.pi,
      colors: [color.withOpacity(0.0), color.withOpacity(0.5), color],
      stops: const [0.0, 0.5, 1.0],
      transform: const GradientRotation(math.pi * 1.5),
    );
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0.0,
      2 * math.pi,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ModernSpinnerPainter oldDelegate) =>
      color != oldDelegate.color || strokeWidth != oldDelegate.strokeWidth;
}
