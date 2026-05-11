import 'package:flutter/material.dart';
import '../services/sipora_api_service.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _staggerController;
  final SiporaApiService _apiService = SiporaApiService();
  bool _isSearching = false;
  String _lastQuery = '';
  List<Map<String, dynamic>> _searchResults = [];

  // ✅ DATA SMART SHORTCUTS (MENGIKUTI DATA JELAJAHI)
  List<Map<String, dynamic>> _shortcuts = [
    {
      'icon': Icons.menu_book_rounded,
      'label': 'Skripsi',
      'count': '5.098',
      'color': const Color(0xFF1565C0),
    },
    {
      'icon': Icons.school_rounded,
      'label': 'Tesis',
      'count': '3.435',
      'color': const Color(0xFF7B1FA2),
    },
    {
      'icon': Icons.article_rounded,
      'label': 'Paper',
      'count': '9.908',
      'color': const Color(0xFFE65100),
    },
    {
      'icon': Icons.computer_rounded,
      'label': 'Teknik Informatika',
      'count': '4.120',
      'color': const Color(0xFF0277BD),
    },
    {
      'icon': Icons.engineering_rounded,
      'label': 'Teknik Sipil',
      'count': '2.150',
      'color': const Color(0xFF4E342E),
    },
    {
      'icon': Icons.business_center_rounded,
      'label': 'Manajemen',
      'count': '1.890',
      'color': const Color(0xFF00695C),
    },
  ];

  // ✅ DATA TRENDING TOPICS
  List<String> _trendingTopics = [
    'Machine Learning',
    'Artificial Intelligence',
    'IoT (Internet of Things)',
    'Sistem Informasi',
    'Data Mining',
    'Cloud Computing',
  ];

  // ✅ DATA RIWAYAT PENCARIAN
  List<String> _recentSearches = [
    'Jaringan Saraf Tiruan',
    'Analisis Sentimen SVM',
    'Sistem Pakar',
  ];

  // Responsif Helper
  double _w(double p) => MediaQuery.of(context).size.width * p;
  double _f(double s) =>
      s * (MediaQuery.of(context).size.width / 400).clamp(0.8, 1.1);

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();
    _loadSearchOverview();
  }

  Future<void> _loadSearchOverview() async {
    try {
      final response = await _apiService.fetchSearchOverview();
      final recent =
          (response['recent_searches'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[];
      final trending =
          (response['trending_topics'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[];
      final shortcuts = (response['shortcuts'] as List?) ?? const [];

      final palette = [
        const Color(0xFF1565C0),
        const Color(0xFF7B1FA2),
        const Color(0xFFE65100),
        const Color(0xFF0277BD),
        const Color(0xFF4E342E),
        const Color(0xFF00695C),
      ];

      if (!mounted) return;
      setState(() {
        if (recent.isNotEmpty) _recentSearches = recent;
        if (trending.isNotEmpty) _trendingTopics = trending;
        if (shortcuts.isNotEmpty) {
          _shortcuts = shortcuts.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = Map<String, dynamic>.from(entry.value as Map);
            return {
              'icon': Icons.category_rounded,
              'label': (item['label'] ?? 'Kategori').toString(),
              'count': (item['count'] ?? 0).toString(),
              'color': palette[idx % palette.length],
            };
          }).toList();
        }
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchController.dispose();
    _staggerController.dispose();
    super.dispose();
  }

  Future<void> _searchAction() async {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) {
      setState(() {
        _lastQuery = '';
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _lastQuery = keyword;
    });

    try {
      final docs = await _apiService.searchDocuments(keyword);
      if (!mounted) return;

      final normalized = docs.map((item) {
        final map = Map<String, dynamic>.from(item);
        return {
          'title': map['title']?.toString() ?? '-',
          'author': map['author']?.toString() ?? '-',
          'date': map['date']?.toString() ?? '-',
          'category': map['category']?.toString() ?? 'Dokumen',
        };
      }).toList();

      setState(() {
        _searchResults = normalized;
        _isSearching = false;
        _recentSearches.remove(keyword);
        _recentSearches.insert(0, keyword);
        if (_recentSearches.length > 8) {
          _recentSearches = _recentSearches.take(8).toList();
        }
      });
      _loadSearchOverview();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pencarian gagal: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFB00020),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Widget _buildStaggeredItem(int index, Widget child) {
    return AnimatedBuilder(
      animation: _staggerController,
      builder: (context, _) {
        final slideAnim =
            Tween<Offset>(
              begin: const Offset(0, 0.15),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(
                parent: _staggerController,
                curve: Interval(
                  (index * 0.1).clamp(0.0, 0.6),
                  0.9,
                  curve: Curves.easeOutCubic,
                ),
              ),
            );
        final fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: _staggerController,
            curve: Interval((index * 0.1).clamp(0.0, 0.6), 0.9),
          ),
        );
        return FadeTransition(
          opacity: fadeAnim,
          child: SlideTransition(position: slideAnim, child: child),
        );
      },
    );
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
                // 1. Header (SUDAH DIBERSIHKAN)
                SliverToBoxAdapter(child: _buildSmartHeader()),

                // 2. Modern Search Bar
                SliverToBoxAdapter(child: _buildModernSearchBar()),

                if (_isSearching)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 36),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  )
                else if (_lastQuery.isNotEmpty)
                  SliverToBoxAdapter(child: _buildSearchResults())
                else ...[
                  // 3. Recent Searches (IKON PANAH SUDAH DIHAPUS)
                  SliverToBoxAdapter(child: _buildRecentSearches()),

                  // 4. Smart Shortcuts Grid
                  SliverToBoxAdapter(child: _buildSmartShortcutsGrid()),

                  // 5. Trending Topics
                  SliverToBoxAdapter(child: _buildTrendingTopics()),
                ],

                // Bottom Padding agar tidak tertimpa Navbar
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // 1. SMART HEADER (BERSIH TANPA ICON & SALAM)
  // ==========================================
  Widget _buildSmartHeader() {
    return _buildStaggeredItem(
      0,
      Padding(
        padding: EdgeInsets.fromLTRB(_w(0.06), _w(0.04), _w(0.06), _w(0.02)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ❌ Icon kotak biru bintang putih DIHAPUS
            Text(
              "Pencarian Dokumen Cerdas",
              style: TextStyle(
                fontSize: _f(22),
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1E3A5F),
                height: 1.2,
              ),
            ),
            SizedBox(height: _w(0.01)),
            Text(
              "Temukan referensi akademik dengan filter presisi tinggi.",
              style: TextStyle(fontSize: _f(12), color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 2. MODERN SEARCH BAR
  // ==========================================
  // ==========================================
  // SEARCH BAR YANG SUDAH DIPERBAIKI
  // ==========================================
  Widget _buildModernSearchBar() {
    return _buildStaggeredItem(
      1,
      Padding(
        padding: EdgeInsets.symmetric(horizontal: _w(0.06), vertical: _w(0.03)),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_w(0.04)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E3A5F).withOpacity(0.08),
                blurRadius: 30,
                offset: const Offset(0, 10),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Row(
            children: [
              // INPUT AREA
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onSubmitted: (_) => _searchAction(),
                  style: TextStyle(
                    fontSize: _f(15),
                    color: const Color(0xFF1E3A5F),
                    fontWeight: FontWeight.w500,
                    overflow: TextOverflow
                        .ellipsis, // ✅ MENCEGAH TEKS TYPING TERTIMPA
                  ),
                  decoration: InputDecoration(
                    hintText: 'Ketik judul, penulis, atau kata kunci...',
                    hintStyle: TextStyle(
                      fontSize: _f(13),
                      color: Colors.grey.shade400,
                      fontWeight: FontWeight.w400,
                      overflow: TextOverflow
                          .ellipsis, // ✅ MENCEGAH HINT TEXT TERTIMPA BUTTON
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: const Color(0xFF1565C0),
                      size: _f(24),
                    ),
                    prefixIconConstraints: BoxConstraints(
                      // ✅ MEMBATASI LEBAR IKON AGAR TIDAK NENDORONG TEKS
                      minWidth: _w(0.12),
                      minHeight: _w(0.12),
                    ),
                    border: InputBorder.none,
                    // ✅ PERBAIKAN ERROR: DIUBAH MENJADI EdgeInsets.only
                    contentPadding: EdgeInsets.only(
                      top: _w(0.035),
                      bottom: _w(0.035),
                      right: _w(0.02), // JARAK KANAN AGAR TIDAK MENEMPEL BUTTON
                    ),
                  ),
                ),
              ),

              // BUTTON AREA
              Padding(
                padding: EdgeInsets.only(
                  right: _w(0.015),
                  top: _w(0.015),
                  bottom: _w(0.015),
                ),
                child: Material(
                  color: const Color(0xFF1565C0),
                  borderRadius: BorderRadius.circular(_w(0.035)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(_w(0.035)),
                    onTap: _searchAction,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: _w(0.05),
                        vertical: _w(0.03),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: _f(16),
                          ),
                          SizedBox(width: _w(0.015)),
                          Text(
                            "Cari",
                            style: TextStyle(
                              fontSize: _f(14),
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
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
      ),
    );
  }

  // ==========================================
  // 3. RECENT SEARCHES (TANPA ICON PANAH HITAM)
  // ==========================================
  Widget _buildRecentSearches() {
    return _buildStaggeredItem(
      2,
      Padding(
        padding: EdgeInsets.symmetric(horizontal: _w(0.06), vertical: _w(0.02)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Pencarian Terakhir",
                  style: TextStyle(
                    fontSize: _f(13),
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
                InkWell(
                  onTap: () => setState(() => _recentSearches.clear()),
                  child: Text(
                    "Hapus Semua",
                    style: TextStyle(
                      fontSize: _f(11),
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1565C0),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: _w(0.02)),
            ..._recentSearches.map(
              (search) => Padding(
                padding: EdgeInsets.only(bottom: _w(0.015)),
                child: InkWell(
                  onTap: () {
                    setState(() => _searchController.text = search);
                    _searchAction();
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Row(
                    children: [
                      Icon(
                        Icons.history_rounded,
                        size: _f(18),
                        color: Colors.grey.shade400,
                      ),
                      SizedBox(width: _w(0.03)),
                      Expanded(
                        child: Text(
                          search,
                          style: TextStyle(
                            fontSize: _f(13),
                            color: const Color(0xFF1E3A5F),
                          ),
                        ),
                      ),
                      // ❌ Icon panah hitam (north_west) DIHAPUS
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

  // ==========================================
  // 4. SMART SHORTCUTS GRID
  // ==========================================
  Widget _buildSmartShortcutsGrid() {
    return _buildStaggeredItem(
      3,
      Padding(
        padding: EdgeInsets.symmetric(vertical: _w(0.02)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: _w(0.06)),
              child: Text(
                "Jelajahi Berdasarkan Kategori",
                style: TextStyle(
                  fontSize: _f(13),
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
            SizedBox(height: _w(0.02)),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: _w(0.06)),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: _w(0.03),
                mainAxisSpacing: _w(0.03),
                childAspectRatio: 1.5,
              ),
              itemCount: _shortcuts.length,
              itemBuilder: (context, index) {
                final data = _shortcuts[index];
                return _buildShortcutCard(data);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShortcutCard(Map<String, dynamic> data) {
    return InkWell(
      onTap: () {
        setState(() => _searchController.text = data['label'].toString());
        _searchAction();
      },
      borderRadius: BorderRadius.circular(_w(0.03)),
      child: Container(
        padding: EdgeInsets.all(_w(0.03)),
        decoration: BoxDecoration(
          color: (data['color'] as Color).withOpacity(0.06),
          borderRadius: BorderRadius.circular(_w(0.03)),
          border: Border.all(
            color: (data['color'] as Color).withOpacity(0.15),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(_w(0.015)),
              decoration: BoxDecoration(
                color: (data['color'] as Color).withOpacity(0.15),
                borderRadius: BorderRadius.circular(_w(0.015)),
              ),
              child: Icon(data['icon'], size: _f(20), color: data['color']),
            ),
            SizedBox(height: _w(0.02)),
            Text(
              data['label'],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: _f(12),
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E3A5F),
              ),
            ),
            SizedBox(height: _w(0.005)),
            Text(
              "${data['count']} Dokumen",
              style: TextStyle(fontSize: _f(10), color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 5. TRENDING TOPICS
  // ==========================================
  Widget _buildTrendingTopics() {
    return _buildStaggeredItem(
      4,
      Padding(
        padding: EdgeInsets.symmetric(horizontal: _w(0.06), vertical: _w(0.02)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.trending_up_rounded,
                  color: Colors.orange.shade700,
                  size: _f(20),
                ),
                SizedBox(width: _w(0.02)),
                Text(
                  "Trending Saat Ini",
                  style: TextStyle(
                    fontSize: _f(13),
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
            SizedBox(height: _w(0.02)),
            Wrap(
              spacing: _w(0.02),
              runSpacing: _w(0.02),
              children: _trendingTopics.map((topic) {
                return InkWell(
                  onTap: () {
                    setState(() => _searchController.text = topic);
                    _searchAction();
                  },
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: _w(0.035),
                      vertical: _w(0.018),
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.grey.shade300),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Text(
                      "# $topic",
                      style: TextStyle(
                        fontSize: _f(11),
                        color: const Color(0xFF1E3A5F),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    return Padding(
      padding: EdgeInsets.fromLTRB(_w(0.06), _w(0.01), _w(0.06), _w(0.02)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Hasil untuk "$_lastQuery"',
                style: TextStyle(
                  fontSize: _f(13),
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade700,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  setState(() {
                    _lastQuery = '';
                    _searchResults = [];
                    _searchController.clear();
                  });
                },
                child: const Text('Reset'),
              ),
            ],
          ),
          SizedBox(height: _w(0.01)),
          if (_searchResults.isEmpty)
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: _w(0.09)),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.search_off_rounded,
                    color: Colors.grey.shade400,
                    size: _f(30),
                  ),
                  SizedBox(height: _w(0.015)),
                  Text(
                    'Dokumen tidak ditemukan',
                    style: TextStyle(
                      fontSize: _f(12),
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            )
          else
            ..._searchResults.map(_buildSearchResultCard),
        ],
      ),
    );
  }

  Widget _buildSearchResultCard(Map<String, dynamic> doc) {
    return Container(
      margin: EdgeInsets.only(bottom: _w(0.025)),
      padding: EdgeInsets.all(_w(0.035)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            doc['title'],
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: _f(13),
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E3A5F),
            ),
          ),
          SizedBox(height: _w(0.012)),
          Text(
            doc['author'],
            style: TextStyle(fontSize: _f(11), color: Colors.grey.shade600),
          ),
          SizedBox(height: _w(0.02)),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  doc['category'],
                  style: TextStyle(
                    fontSize: _f(10),
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1565C0),
                  ),
                ),
              ),
              const Spacer(),
              Icon(
                Icons.access_time_rounded,
                size: _f(12),
                color: Colors.grey.shade400,
              ),
              const SizedBox(width: 4),
              Text(
                doc['date'],
                style: TextStyle(fontSize: _f(10), color: Colors.grey.shade500),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
