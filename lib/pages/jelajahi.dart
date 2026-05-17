import 'package:flutter/material.dart';
import '../services/sipora_api_service.dart';
import 'dokumen_semua_page.dart';

// ─── Helper: gradient berdasarkan ekstensi file ───────────────────────────────

List<Color> _gradientForFile(String filePath) {
  final ext = filePath.trim().toLowerCase().split('.').last;
  if (ext == 'pdf') {
    // Merah
    return [const Color(0xFFC62828), const Color(0xFFEF5350)];
  }
  if (['doc', 'docx'].contains(ext)) {
    // Biru
    return [const Color(0xFF1565C0), const Color(0xFF42A5F5)];
  }
  // Abu-abu untuk file lain / belum ada file
  return [const Color(0xFF546E7A), const Color(0xFF90A4AE)];
}

// ─────────────────────────────────────────────────────────────────────────────

class JelajahiPage extends StatefulWidget {
  const JelajahiPage({super.key});

  @override
  State<JelajahiPage> createState() => _JelajahiPageState();
}

class _JelajahiPageState extends State<JelajahiPage>
    with TickerProviderStateMixin {
  int _selectedCategoryIndex = 0;
  String? _selectedYear;
  String? _selectedField;
  bool _isLoading = true;
  final SiporaApiService _apiService = SiporaApiService();

  late AnimationController _listAnimationController;

  double _getWidth(double percentage) =>
      MediaQuery.of(context).size.width * percentage;
  double _getFontSize(double baseSize) =>
      baseSize * (MediaQuery.of(context).size.width / 400).clamp(0.8, 1.1);

  List<Map<String, dynamic>> _documents = [];

  List<String> _yearList = List.generate(
    10,
    (index) => (DateTime.now().year - index).toString(),
  );

  List<String> _fieldList = [
    'Semua Bidang',
    'Teknologi Informasi',
    'Teknik',
    'Teknologi Pertanian',
    'Produksi Pertanian',
    'Peternakan',
    'Kesehatan',
    'Bahasa, Komunikasi, dan Pariwisata',
    'Bisnis',
  ];

  final List<Map<String, dynamic>> _categories = [
    {'icon': Icons.menu_book_rounded,    'label': 'Skripsi',     'count': '0'},
    {'icon': Icons.school_rounded,       'label': 'Tesis',       'count': '0'},
    {'icon': Icons.science_rounded,      'label': 'KTI',         'count': '0'},
    {'icon': Icons.assignment_rounded,   'label': 'Tugas Akhir', 'count': '0'},
    {'icon': Icons.work_outline_rounded, 'label': 'Lap. Magang', 'count': '0'},
    {'icon': Icons.article_rounded,      'label': 'Semua',       'count': '0'},
  ];

  List<Map<String, dynamic>> get _filteredDocuments {
    final selectedLabel =
        _categories[_selectedCategoryIndex]['label'] as String;
    if (selectedLabel == 'Semua') return _documents;
    return _documents
        .where(
          (doc) =>
              (doc['type']?.toString() ?? '').toLowerCase() ==
              selectedLabel.toLowerCase(),
        )
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _listAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final lookup = await _apiService.fetchLookupOptions();
      final years =
          (lookup['tahun'] as List?)?.map((e) => '$e').toList() ?? [];
      final jurusan =
          (lookup['jurusan'] as List?)?.map((e) => '$e').toList() ?? [];

      if (mounted) {
        setState(() {
          if (years.isNotEmpty) _yearList = years;
          if (jurusan.isNotEmpty) _fieldList = ['Semua Bidang', ...jurusan];
        });
      }
      await _loadDocuments();
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadDocuments() async {
    try {
      final docs = await _apiService.fetchBrowseDocuments(
        year: _selectedYear,
        jurusan: _selectedField == 'Semua Bidang' ? null : _selectedField,
      );

      final mappedDocs = docs.map((entry) {
        final item = Map<String, dynamic>.from(entry);
        final filePath =
            (item['file_url'] ?? item['file_path'] ?? '').toString();
        item['title']    = item['title']?.toString() ?? '-';
        item['author']   = item['author']?.toString() ?? 'Unknown';
        item['date']     = item['date']?.toString() ?? '-';
        item['downloads'] = (item['downloads'] as num?)?.toInt() ?? 0;
        item['type']     = item['type']?.toString() ?? 'Dokumen';
        item['status']   = item['status']?.toString() ??
            item['jurusan']?.toString() ?? '-';
        item['file_path']       = filePath;
        item['gradientColors']  = _gradientForFile(filePath); // ← dari ekstensi
        return item;
      }).toList();

      int countSkripsi   = 0;
      int countTesis     = 0;
      int countKti       = 0;
      int countTugasAkhir = 0;
      int countLapMagang = 0;

      for (final doc in mappedDocs) {
        final type = (doc['type']?.toString() ?? '').toLowerCase();
        if (type == 'skripsi')          countSkripsi++;
        else if (type == 'tesis')       countTesis++;
        else if (type == 'kti')         countKti++;
        else if (type == 'tugas akhir') countTugasAkhir++;
        else if (type == 'laporan magang') countLapMagang++;
      }

      if (!mounted) return;
      setState(() {
        _documents = mappedDocs;
        _categories[0]['count'] = '$countSkripsi';
        _categories[1]['count'] = '$countTesis';
        _categories[2]['count'] = '$countKti';
        _categories[3]['count'] = '$countTugasAkhir';
        _categories[4]['count'] = '$countLapMagang';
        _categories[5]['count'] = '${mappedDocs.length}';
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _listAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildPageHeader()),
                SliverToBoxAdapter(child: _buildCategoryFilters()),
                SliverToBoxAdapter(child: _buildActiveFilters()),
                SliverPadding(
                  padding: EdgeInsets.only(
                    left: _getWidth(0.04),
                    right: _getWidth(0.04),
                    bottom: 90.0,
                  ),
                  sliver: _isLoading
                      ? SliverToBoxAdapter(child: _buildLoadingState())
                      : _filteredDocuments.isEmpty
                          ? SliverToBoxAdapter(child: _buildEmptyState())
                          : SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) =>
                                    _buildAnimatedDocCard(index),
                                childCount: _filteredDocuments.length,
                              ),
                            ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Loading skeleton ───────────────────────────────────────────────────────

  Widget _buildLoadingState() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: _getWidth(0.1)),
      child: Column(
        children: List.generate(3, (i) => _buildSkeletonCard(i)),
      ),
    );
  }

  Widget _buildSkeletonCard(int index) {
    return Container(
      margin: EdgeInsets.only(bottom: _getWidth(0.03)),
      padding: EdgeInsets.all(_getWidth(0.04)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _shimmerBox(
                  width: _getWidth(0.12), height: _getWidth(0.12), radius: 12),
              SizedBox(width: _getWidth(0.03)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _shimmerBox(
                        width: double.infinity, height: 14, radius: 6),
                    const SizedBox(height: 8),
                    _shimmerBox(width: _getWidth(0.4), height: 12, radius: 6),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: _getWidth(0.03)),
          Row(
            children: [
              _shimmerBox(width: 70, height: 26, radius: 8),
              const SizedBox(width: 8),
              _shimmerBox(width: 90, height: 26, radius: 8),
            ],
          ),
        ],
      ),
    );
  }

  Widget _shimmerBox(
      {required double width,
      required double height,
      required double radius}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  // ── Animated card wrapper ──────────────────────────────────────────────────

  Widget _buildAnimatedDocCard(int index) {
    final docs = _filteredDocuments;
    final totalDocs = docs.isEmpty ? 1 : docs.length;

    return AnimatedBuilder(
      animation: _listAnimationController,
      builder: (context, child) {
        final animation = Tween<Offset>(
          begin: const Offset(0.0, 0.25),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: _listAnimationController,
            curve: Interval(
              (index / totalDocs) * 0.5,
              0.85,
              curve: Curves.easeOutCubic,
            ),
          ),
        );
        final fade = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: _listAnimationController,
            curve: Interval(
              (index / totalDocs) * 0.5,
              0.85,
              curve: Curves.easeOut,
            ),
          ),
        );
        return SlideTransition(
          position: animation,
          child: FadeTransition(opacity: fade, child: child),
        );
      },
      child: _buildDocumentCard(docs[index]),
    );
  }

  // ── Empty state ────────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: _getWidth(0.15)),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(_getWidth(0.06)),
              decoration: BoxDecoration(
                color: const Color(0xFF1565C0).withOpacity(0.07),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.folder_open_rounded,
                size: _getFontSize(44),
                color: const Color(0xFF1565C0).withOpacity(0.5),
              ),
            ),
            SizedBox(height: _getWidth(0.04)),
            Text(
              'Belum ada dokumen',
              style: TextStyle(
                fontSize: _getFontSize(14),
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E3A5F),
              ),
            ),
            SizedBox(height: _getWidth(0.01)),
            Text(
              'Coba ubah filter pencarian',
              style: TextStyle(
                fontSize: _getFontSize(11),
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Page header ────────────────────────────────────────────────────────────

  Widget _buildPageHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        _getWidth(0.04),
        _getWidth(0.02),
        _getWidth(0.04),
        _getWidth(0.02),
      ),
      child: Row(
        children: [
          Text(
            "Jelajahi Dokumen",
            style: TextStyle(
              fontSize: _getFontSize(20),
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1E3A5F),
            ),
          ),
          const Spacer(),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_getWidth(0.02)),
            child: InkWell(
              borderRadius: BorderRadius.circular(_getWidth(0.02)),
              onTap: _showFilterPopup,
              child: Padding(
                padding: EdgeInsets.all(_getWidth(0.02)),
                child: Icon(
                  Icons.tune_rounded,
                  color: Colors.grey.shade700,
                  size: _getFontSize(24),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Filter popup ───────────────────────────────────────────────────────────

  Future<void> _showFilterPopup() async {
    String? tempYear = _selectedYear;
    String? tempField = _selectedField ?? 'Semua Bidang';
    int tempCategoryIndex = _selectedCategoryIndex;

    final applied = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Filter Dialog',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, animation, secondaryAnimation) {
        return StatefulBuilder(
          builder: (context, modalSetState) {
            return Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: _getWidth(0.9),
                  constraints: BoxConstraints(
                    maxWidth: 420,
                    maxHeight: _getWidth(1.9),
                  ),
                  margin:
                      EdgeInsets.symmetric(horizontal: _getWidth(0.05)),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 40,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Handle bar
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      Flexible(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(
                            _getWidth(0.05),
                            _getWidth(0.04),
                            _getWidth(0.05),
                            _getWidth(0.06),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1565C0)
                                          .withOpacity(0.1),
                                      borderRadius:
                                          BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.tune_rounded,
                                      color: Color(0xFF1565C0),
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Filter Dokumen',
                                    style: TextStyle(
                                      fontSize: _getFontSize(16),
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF1E3A5F),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: _getWidth(0.04)),
                              _buildPopupLabel('Tahun'),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String?>(
                                value: tempYear,
                                isExpanded: true,
                                decoration: _popupInputDecoration(),
                                items: [
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('Semua Tahun'),
                                  ),
                                  ..._yearList.map(
                                    (year) => DropdownMenuItem<String?>(
                                      value: year,
                                      child: Text(year),
                                    ),
                                  ),
                                ],
                                onChanged: (val) =>
                                    modalSetState(() => tempYear = val),
                              ),
                              SizedBox(height: _getWidth(0.03)),
                              _buildPopupLabel('Bidang Ilmu'),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                value: tempField,
                                isExpanded: true,
                                decoration: _popupInputDecoration(),
                                items: _fieldList
                                    .map(
                                      (field) => DropdownMenuItem<String>(
                                        value: field,
                                        child: Text(field),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) =>
                                    modalSetState(() => tempField = val),
                              ),
                              SizedBox(height: _getWidth(0.03)),
                              _buildPopupLabel('Kategori'),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: List.generate(
                                    _categories.length, (index) {
                                  final selected =
                                      tempCategoryIndex == index;
                                  final label = _categories[index]
                                      ['label'] as String;
                                  return GestureDetector(
                                    onTap: () => modalSetState(
                                        () => tempCategoryIndex = index),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                          milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? const Color(0xFF1565C0)
                                            : Colors.grey.shade50,
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        border: Border.all(
                                          color: selected
                                              ? const Color(0xFF1565C0)
                                              : Colors.grey.shade200,
                                          width: 1.5,
                                        ),
                                        boxShadow: selected
                                            ? [
                                                BoxShadow(
                                                  color: const Color(
                                                          0xFF1565C0)
                                                      .withOpacity(0.3),
                                                  blurRadius: 8,
                                                  offset:
                                                      const Offset(0, 3),
                                                )
                                              ]
                                            : [],
                                      ),
                                      child: Text(
                                        label,
                                        style: TextStyle(
                                          fontSize: _getFontSize(11),
                                          fontWeight: FontWeight.w600,
                                          color: selected
                                              ? Colors.white
                                              : Colors.grey.shade700,
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                              SizedBox(height: _getWidth(0.05)),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () {
                                        modalSetState(() {
                                          tempYear = null;
                                          tempField = 'Semua Bidang';
                                          tempCategoryIndex = 2;
                                        });
                                      },
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor:
                                            Colors.grey.shade700,
                                        side: BorderSide(
                                            color: Colors.grey.shade300),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 14),
                                      ),
                                      child: const Text('Reset'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    flex: 2,
                                    child: ElevatedButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF1565C0),
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shadowColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 14),
                                      ),
                                      child: const Text(
                                        'Terapkan Filter',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
              parent: animation, curve: Curves.easeOut),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.08),
              end: Offset.zero,
            ).animate(CurvedAnimation(
                parent: animation, curve: Curves.easeOutCubic)),
            child: child,
          ),
        );
      },
    );

    if (applied != true || !mounted) return;

    setState(() {
      _selectedYear = tempYear;
      _selectedField = tempField;
      _selectedCategoryIndex = tempCategoryIndex;
      _isLoading = true;
    });
    await _loadDocuments();
  }

  InputDecoration _popupInputDecoration() {
    return InputDecoration(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      filled: true,
      fillColor: Colors.grey.shade50,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide:
            BorderSide(color: Color(0xFF1565C0), width: 1.5),
      ),
    );
  }

  Widget _buildPopupLabel(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: _getFontSize(12),
        fontWeight: FontWeight.w700,
        color: const Color(0xFF1E3A5F),
        letterSpacing: 0.2,
      ),
    );
  }

  // ── Active filter chips ────────────────────────────────────────────────────

  Widget _buildActiveFilters() {
    final activeFilters = <String>[
      if (_selectedYear != null) 'Tahun: $_selectedYear',
      if ((_selectedField ?? '').isNotEmpty &&
          _selectedField != 'Semua Bidang')
        'Bidang: $_selectedField',
      if (_selectedCategoryIndex != 2)
        'Kategori: ${_categories[_selectedCategoryIndex]['label']}',
    ];

    if (activeFilters.isEmpty) {
      return SizedBox(height: _getWidth(0.01));
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        _getWidth(0.04),
        0,
        _getWidth(0.04),
        _getWidth(0.02),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: activeFilters
            .map(
              (label) => Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF1565C0).withOpacity(0.12),
                      const Color(0xFF42A5F5).withOpacity(0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: const Color(0xFF1565C0).withOpacity(0.25),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.filter_list_rounded,
                      size: 11,
                      color: Color(0xFF1565C0),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: _getFontSize(10),
                        color: const Color(0xFF1565C0),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  // ── Category filter row ────────────────────────────────────────────────────

  Widget _buildCategoryFilters() {
    return Container(
      margin: EdgeInsets.only(
        top: _getWidth(0.015),
        bottom: _getWidth(0.02),
      ),
      height: _getWidth(0.24),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: _getWidth(0.04)),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final isSelected = _selectedCategoryIndex == index;
          return GestureDetector(
            onTap: () =>
                setState(() => _selectedCategoryIndex = index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              width: _getWidth(0.25),
              margin: EdgeInsets.only(right: _getWidth(0.025)),
              padding: EdgeInsets.symmetric(
                vertical: _getWidth(0.018),
                horizontal: _getWidth(0.01),
              ),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(
                        colors: [Color(0xFF1565C0), Color(0xFF1E88E5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : LinearGradient(
                        colors: [Colors.white, Colors.grey.shade50]),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSelected
                      ? Colors.transparent
                      : Colors.grey.shade200,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isSelected
                        ? const Color(0xFF1565C0).withOpacity(0.35)
                        : Colors.black.withOpacity(0.04),
                    blurRadius: isSelected ? 14 : 8,
                    offset: isSelected
                        ? const Offset(0, 6)
                        : const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(_getWidth(0.018)),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withOpacity(0.22)
                          : const Color(0xFF1565C0).withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _categories[index]['icon'],
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF1565C0),
                      size: _getFontSize(17),
                    ),
                  ),
                  SizedBox(height: _getWidth(0.008)),
                  Text(
                    _categories[index]['label'],
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: _getFontSize(9.5),
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF1E3A5F),
                      letterSpacing: 0.1,
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withOpacity(0.2)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _categories[index]['count'],
                      style: TextStyle(
                        fontSize: _getFontSize(8.5),
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? Colors.white.withOpacity(0.9)
                            : Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Document card ──────────────────────────────────────────────────────────

  Widget _buildDocumentCard(Map<String, dynamic> doc) {
    final filePath = doc['file_path']?.toString() ?? '';
    final List<Color> gradColors = _gradientForFile(filePath); // ← dari ekstensi
    final Color accentColor = gradColors[0];

    return Container(
      margin: EdgeInsets.only(bottom: _getWidth(0.035)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.07),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          splashColor: accentColor.withOpacity(0.08),
          highlightColor: accentColor.withOpacity(0.04),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DetailDokumenPage(
                document: doc,
                apiService: _apiService,
              ),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(_getWidth(0.04)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Icon with gradient background ──────────────────
                    Container(
                      width: _getWidth(0.12),
                      height: _getWidth(0.12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: gradColors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        _getTypeIcon(doc['type'] as String? ?? ''),
                        color: Colors.white,
                        size: _getFontSize(20),
                      ),
                    ),
                    SizedBox(width: _getWidth(0.035)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            doc['title'],
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: _getFontSize(13),
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1E3A5F),
                              height: 1.35,
                              letterSpacing: -0.1,
                            ),
                          ),
                          SizedBox(height: _getWidth(0.008)),
                          Row(
                            children: [
                              Icon(
                                Icons.person_outline_rounded,
                                size: 12,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  doc['author'],
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: _getFontSize(11),
                                    color: Colors.grey.shade500,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: _getWidth(0.03)),
                // ── Tags row ─────────────────────────────────────────
                Row(
                  children: [
                    _buildTag(
                      text: doc['type'],
                      bgColor: accentColor.withOpacity(0.1),
                      textColor: accentColor,
                      icon: Icons.label_rounded,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildTag(
                        text: doc['status'],
                        bgColor: Colors.grey.shade100,
                        textColor: Colors.grey.shade600,
                        icon: Icons.school_outlined,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 11,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          doc['date'],
                          style: TextStyle(
                            fontSize: _getFontSize(10),
                            color: Colors.grey.shade400,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: _getWidth(0.025)),
                // ── Divider ──────────────────────────────────────────
                Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accentColor.withOpacity(0.12),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                SizedBox(height: _getWidth(0.025)),
                // ── Bottom row ───────────────────────────────────────
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.download_rounded,
                            size: _getFontSize(13),
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "${doc['downloads']}x diunduh",
                            style: TextStyle(
                              fontSize: _getFontSize(10),
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DetailDokumenPage(
                            document: doc,
                            apiService: _apiService,
                          ),
                        ),
                      ),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: _getWidth(0.04),
                          vertical: _getWidth(0.022),
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: gradColors,
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withOpacity(0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.open_in_new_rounded,
                              size: _getFontSize(12),
                              color: Colors.white,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              "Lihat Detail",
                              style: TextStyle(
                                fontSize: _getFontSize(11),
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _buildTag({
    required String text,
    required Color bgColor,
    required Color textColor,
    required IconData icon,
    int? maxLines,
    TextOverflow? overflow,
  }) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: textColor),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              text,
              maxLines: maxLines ?? 1,
              overflow: overflow ?? TextOverflow.clip,
              style: TextStyle(
                fontSize: _getFontSize(9.5),
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'skripsi':
        return Icons.menu_book_rounded;
      case 'tesis':
        return Icons.school_rounded;
      case 'kti':
        return Icons.science_rounded;
      case 'tugas akhir':
        return Icons.assignment_rounded;
      case 'laporan magang':
        return Icons.work_outline_rounded;
      default:
        return Icons.article_rounded;
    }
  }
}