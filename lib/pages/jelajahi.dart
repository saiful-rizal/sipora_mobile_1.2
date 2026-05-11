import 'package:flutter/material.dart';
import '../services/sipora_api_service.dart';

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
    5,
    (index) => (DateTime.now().year - index).toString(),
  );
  List<String> _fieldList = [
    'Semua Bidang',
    'Teknologi Informasi',
    'Teknik Sipil',
    'Teknik Elektro',
    'Bisnis dan Manajemen',
  ];

  final List<Map<String, dynamic>> _categories = [
    {'icon': Icons.menu_book_rounded, 'label': 'Skripsi', 'count': '5,098'},
    {'icon': Icons.school_rounded, 'label': 'Tesis', 'count': '3,435'},
    {'icon': Icons.article_rounded, 'label': 'Dokumen', 'count': '9,908'},
  ];

  List<Map<String, dynamic>> get _filteredDocuments {
    final selectedLabel =
        _categories[_selectedCategoryIndex]['label'] as String;
    if (selectedLabel == 'Dokumen') {
      return _documents;
    }
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
      duration: const Duration(milliseconds: 800),
    )..forward();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final lookup = await _apiService.fetchLookupOptions();
      final years = (lookup['tahun'] as List?)?.map((e) => '$e').toList() ?? [];
      final jurusan =
          (lookup['jurusan'] as List?)?.map((e) => '$e').toList() ?? [];

      if (mounted) {
        setState(() {
          if (years.isNotEmpty) {
            _yearList = years;
          }
          if (jurusan.isNotEmpty) {
            _fieldList = ['Semua Bidang', ...jurusan];
          }
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

      final palette = [Colors.blue, Colors.purple, Colors.orange, Colors.teal];
      final mappedDocs = docs.asMap().entries.map((entry) {
        final idx = entry.key;
        final item = Map<String, dynamic>.from(entry.value);
        item['title'] = item['title']?.toString() ?? '-';
        item['author'] = item['author']?.toString() ?? 'Unknown';
        item['date'] = item['date']?.toString() ?? '-';
        item['downloads'] = (item['downloads'] as num?)?.toInt() ?? 0;
        item['type'] = item['type']?.toString() ?? 'Dokumen';
        item['status'] =
            item['status']?.toString() ?? item['jurusan']?.toString() ?? '-';
        item['color'] = palette[idx % palette.length];
        return item;
      }).toList();

      final total = mappedDocs.length;
      final skripsiCount = mappedDocs
          .where(
            (doc) => (doc['type']?.toString() ?? '').toLowerCase() == 'skripsi',
          )
          .length;
      final tesisCount = mappedDocs
          .where(
            (doc) => (doc['type']?.toString() ?? '').toLowerCase() == 'tesis',
          )
          .length;

      if (!mounted) return;
      setState(() {
        _documents = mappedDocs;
        _categories[0]['count'] = '$skripsiCount';
        _categories[1]['count'] = '$tesisCount';
        _categories[2]['count'] = '$total';
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
                      ? const SliverToBoxAdapter(
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : _filteredDocuments.isEmpty
                      ? SliverToBoxAdapter(child: _buildEmptyState())
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => _buildAnimatedDocCard(index),
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

  Widget _buildAnimatedDocCard(int index) {
    final docs = _filteredDocuments;
    final totalDocs = docs.isEmpty ? 1 : docs.length;

    return AnimatedBuilder(
      animation: _listAnimationController,
      builder: (context, child) {
        final animation =
            Tween<Offset>(
              begin: const Offset(0.0, 0.2),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(
                parent: _listAnimationController,
                curve: Interval(
                  (index / totalDocs) * 0.5,
                  0.8,
                  curve: Curves.easeOutCubic,
                ),
              ),
            );
        final fade = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: _listAnimationController,
            curve: Interval(
              (index / totalDocs) * 0.5,
              0.8,
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

  Widget _buildEmptyState() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: _getWidth(0.12)),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.folder_open_rounded,
              size: _getFontSize(42),
              color: Colors.grey.shade400,
            ),
            SizedBox(height: _getWidth(0.02)),
            Text(
              'Belum ada dokumen',
              style: TextStyle(
                fontSize: _getFontSize(13),
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

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

  Future<void> _showFilterPopup() async {
    String? tempYear = _selectedYear;
    String? tempField = _selectedField ?? 'Semua Bidang';
    int tempCategoryIndex = _selectedCategoryIndex;

    final applied = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Filter Dialog',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 220),
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
                  margin: EdgeInsets.symmetric(horizontal: _getWidth(0.05)),
                  padding: EdgeInsets.fromLTRB(
                    _getWidth(0.05),
                    _getWidth(0.05),
                    _getWidth(0.05),
                    _getWidth(0.06),
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 28,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Filter Dokumen',
                          style: TextStyle(
                            fontSize: _getFontSize(16),
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1E3A5F),
                          ),
                        ),
                        SizedBox(height: _getWidth(0.035)),
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
                          onChanged: (val) {
                            modalSetState(() => tempYear = val);
                          },
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
                          onChanged: (val) {
                            modalSetState(() => tempField = val);
                          },
                        ),
                        SizedBox(height: _getWidth(0.03)),
                        _buildPopupLabel('Kategori'),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: List.generate(_categories.length, (index) {
                            final selected = tempCategoryIndex == index;
                            final label = _categories[index]['label'] as String;
                            return ChoiceChip(
                              label: Text(label),
                              selected: selected,
                              onSelected: (_) {
                                modalSetState(() => tempCategoryIndex = index);
                              },
                              labelStyle: TextStyle(
                                color: selected
                                    ? const Color(0xFF1565C0)
                                    : Colors.grey.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                              side: BorderSide(
                                color: selected
                                    ? const Color(0xFF1565C0)
                                    : Colors.grey.shade300,
                              ),
                              selectedColor: const Color(
                                0xFF1565C0,
                              ).withOpacity(0.12),
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
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
                                  foregroundColor: Colors.grey.shade700,
                                  side: BorderSide(color: Colors.grey.shade300),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                                child: const Text('Reset'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1565C0),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                                child: const Text('Terapkan'),
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
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
            ),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      filled: true,
      fillColor: Colors.grey.shade50,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: Color(0xFF1565C0), width: 1.5),
      ),
    );
  }

  Widget _buildPopupLabel(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: _getFontSize(12),
        fontWeight: FontWeight.w600,
        color: const Color(0xFF4A617D),
      ),
    );
  }

  Widget _buildActiveFilters() {
    final activeFilters = <String>[
      if (_selectedYear != null) 'Tahun: $_selectedYear',
      if ((_selectedField ?? '').isNotEmpty && _selectedField != 'Semua Bidang')
        'Bidang: $_selectedField',
      if (_selectedCategoryIndex != 2)
        'Kategori: ${_categories[_selectedCategoryIndex]['label']}',
    ];

    if (activeFilters.isEmpty) {
      return SizedBox(height: _getWidth(0.015));
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        _getWidth(0.04),
        _getWidth(0.012),
        _getWidth(0.04),
        _getWidth(0.02),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: activeFilters
            .map(
              (label) => Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: const Color(0xFF1565C0).withOpacity(0.2),
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: _getFontSize(10),
                    color: const Color(0xFF1565C0),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  // ==========================================
  // CARD KATEGORI YANG SUDAH 100% RESPONSIF
  // ==========================================
  Widget _buildCategoryFilters() {
    return Container(
      margin: EdgeInsets.only(top: _getWidth(0.02), bottom: _getWidth(0.02)),
      padding: EdgeInsets.symmetric(horizontal: _getWidth(0.04)),
      // ✅ GANTI LISTVIEW MENJADI ROW AGAR LEBAR NYA MENYESUAIKAN LAYAR OTOMATIS
      child: Row(
        children: List.generate(_categories.length, (index) {
          bool isSelected = _selectedCategoryIndex == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedCategoryIndex = index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                // ✅ HAPUS WIDTH TETAP, PAKAI MARGIN DINAMIS ANTAR CARD
                margin: EdgeInsets.only(
                  right: index < _categories.length - 1 ? _getWidth(0.02) : 0,
                ),
                padding: EdgeInsets.symmetric(vertical: _getWidth(0.025)),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF1565C0) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: isSelected
                          ? const Color(0xFF1565C0).withOpacity(0.3)
                          : Colors.black.withOpacity(0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(_getWidth(0.015)),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withOpacity(0.2)
                            : const Color(0xFF1565C0).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _categories[index]['icon'],
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF1565C0),
                        size: _getFontSize(20),
                      ),
                    ),
                    SizedBox(height: _getWidth(0.015)),
                    Text(
                      _categories[index]['label'],
                      style: TextStyle(
                        fontSize: _getFontSize(12),
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF1E3A5F),
                      ),
                    ),
                    Text(
                      _categories[index]['count'],
                      style: TextStyle(
                        fontSize: _getFontSize(10),
                        color: isSelected
                            ? Colors.white.withOpacity(0.8)
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ==========================================
  // CARD DOKUMEN (TELAH DIOPTIMASI UKURANNYA)
  // ==========================================
  Widget _buildDocumentCard(Map<String, dynamic> doc) {
    return Container(
      margin: EdgeInsets.only(bottom: _getWidth(0.03)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          16,
        ), // Diperkecil dari 20 agar tidak terlalu bulat
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(_getWidth(0.035)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4, // Diperkecil dari 5
                  height: _getWidth(0.11),
                  decoration: BoxDecoration(
                    color: doc['color'],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                SizedBox(width: _getWidth(0.025)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc['title'],
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: _getFontSize(13), // Diperkecil dari 14
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1E3A5F),
                          height: 1.3,
                        ),
                      ),
                      SizedBox(height: _getWidth(0.01)),
                      Text(
                        doc['author'],
                        style: TextStyle(
                          fontSize: _getFontSize(11),
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: _getWidth(0.02)),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: (doc['color']).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    doc['type'],
                    style: TextStyle(
                      fontSize: _getFontSize(10),
                      fontWeight: FontWeight.bold,
                      color: doc['color'],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    doc['status'],
                    style: TextStyle(
                      fontSize: _getFontSize(10),
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.access_time_rounded,
                  size: 12,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(width: 4),
                Text(
                  doc['date'],
                  style: TextStyle(
                    fontSize: _getFontSize(10),
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
            Divider(height: _getWidth(0.04), color: Colors.grey.shade200),
            Row(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.download_rounded,
                      size: _getFontSize(15),
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "${doc['downloads']} Download",
                      style: TextStyle(
                        fontSize: _getFontSize(11),
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Material(
                  color: const Color(0xFF1565C0).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {},
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: _getWidth(0.035),
                        vertical: _getWidth(0.020),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.file_download_outlined,
                            size: _getFontSize(13),
                            color: const Color(0xFF1565C0),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "Download",
                            style: TextStyle(
                              fontSize: _getFontSize(11),
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1565C0),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
