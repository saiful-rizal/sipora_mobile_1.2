import 'package:flutter/material.dart';
import '../services/app_session_service.dart';
import '../services/sipora_api_service.dart';
import 'dokumen_semua_page.dart';

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
  int? _userId;

  List<Map<String, dynamic>> _popularDocs      = [];
  List<Map<String, dynamic>> _recommendedDocs  = [];
  bool _isLoadingPopular     = false;
  bool _isLoadingRecommended = false;
  String? _recommendedKeyword;

  List<Map<String, dynamic>> _shortcuts = [
    {'icon': Icons.menu_book_rounded,      'label': 'Skripsi',           'count': '5.098', 'color': const Color(0xFF1565C0)},
    {'icon': Icons.school_rounded,         'label': 'Tesis',             'count': '3.435', 'color': const Color(0xFF7B1FA2)},
    {'icon': Icons.article_rounded,        'label': 'Paper',             'count': '9.908', 'color': const Color(0xFFE65100)},
    {'icon': Icons.computer_rounded,       'label': 'Teknik Informatika','count': '4.120', 'color': const Color(0xFF0277BD)},
    {'icon': Icons.engineering_rounded,    'label': 'Teknik Sipil',      'count': '2.150', 'color': const Color(0xFF4E342E)},
    {'icon': Icons.business_center_rounded,'label': 'Manajemen',         'count': '1.890', 'color': const Color(0xFF00695C)},
  ];

  List<String> _trendingTopics = [
    'Machine Learning','Artificial Intelligence','IoT (Internet of Things)',
    'Sistem Informasi','Data Mining','Cloud Computing',
  ];

  List<String> _recentSearches = [];

  double _w(double p) => MediaQuery.of(context).size.width * p;
  double _f(double s) => s * (MediaQuery.of(context).size.width / 400).clamp(0.8, 1.1);

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await _loadUserId();
    _loadSearchOverview();
    _loadPopularDocs();
    _loadRecommendedDocs();
  }

  Future<void> _loadUserId() async {
    final userId = AppSessionService.currentUserId;
    if (!mounted) return;
    setState(() => _userId = userId);
  }

  Future<void> _loadSearchOverview() async {
    try {
      final response = await _apiService.fetchSearchOverview();
      final recent    = (response['recent_searches'] as List?)?.map((e) => e.toString()).toList() ?? const <String>[];
      final trending  = (response['trending_topics']  as List?)?.map((e) => e.toString()).toList() ?? const <String>[];
      final shortcuts = (response['shortcuts'] as List?) ?? const [];

      final palette = [
        const Color(0xFF1565C0), const Color(0xFF7B1FA2), const Color(0xFFE65100),
        const Color(0xFF0277BD), const Color(0xFF4E342E), const Color(0xFF00695C),
      ];

      if (!mounted) return;
      setState(() {
        _recentSearches = recent;
        if (trending.isNotEmpty) _trendingTopics = trending;
        if (shortcuts.isNotEmpty) {
          _shortcuts = shortcuts.asMap().entries.map((entry) {
            final idx  = entry.key;
            final item = Map<String, dynamic>.from(entry.value as Map);
            return {
              'icon' : Icons.category_rounded,
              'label': (item['label'] ?? 'Kategori').toString(),
              'count': (item['count']  ?? '0').toString(),
              'color': palette[idx % palette.length],
            };
          }).toList();
        }
      });
    } catch (_) {}
  }

  Future<void> _loadPopularDocs() async {
    if (!mounted) return;
    setState(() => _isLoadingPopular = true);
    try {
      final docs = await _apiService.fetchPopularDocuments();
      if (!mounted) return;
      setState(() {
        _popularDocs = _normalizeDocs(docs);
        _isLoadingPopular = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingPopular = false);
    }
  }

  Future<void> _loadRecommendedDocs() async {
    if (!mounted) return;
    setState(() => _isLoadingRecommended = true);
    try {
      final userId = AppSessionService.currentUserId;

      String? topKeyword;
      try {
        final overview = await _apiService.fetchSearchOverview();
        topKeyword = (overview['top_keyword'] as String?)?.trim();
        if (topKeyword != null && topKeyword.isEmpty) topKeyword = null;
      } catch (_) {}

      final docs = await _apiService.fetchRecommendedDocuments(
        userId: userId,
        topKeyword: topKeyword,
      );
      if (!mounted) return;
      setState(() {
        _recommendedDocs    = _normalizeDocs(docs);
        _isLoadingRecommended = false;
        _recommendedKeyword = topKeyword;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingRecommended = false);
    }
  }

  List<Map<String, dynamic>> _normalizeDocs(List<dynamic> raw) {
    final colors = [
      const Color(0xFF1565C0), const Color(0xFF7B1FA2), const Color(0xFFE65100),
      const Color(0xFF0277BD), const Color(0xFF2E7D32), const Color(0xFF00695C),
    ];
    return raw.asMap().entries.map((entry) {
      final idx = entry.key;
      final map = Map<String, dynamic>.from(entry.value as Map);
      return {
        'dokumen_id': map['dokumen_id'],
        'title'     : map['title']?.toString()     ?? map['judul']?.toString()       ?? '-',
        'author'    : map['author']?.toString()    ?? map['nama_lengkap']?.toString() ?? '-',
        'date'      : map['date']?.toString()      ?? map['tgl_unggah']?.toString()   ?? '-',
        'category'  : map['category']?.toString()  ?? map['type']?.toString()         ?? 'Dokumen',
        'file_path' : (map['file_url'] ?? map['file_path'] ?? '').toString(),
        'downloads' : map['downloads']?.toString() ?? map['download_count']?.toString() ?? '0',
        'status'    : map['status']?.toString()    ?? 'Published',
        'prodi'     : map['prodi']?.toString()     ?? '-',
        'abstrak'   : map['abstrak']?.toString()   ?? '',
        'color'     : colors[idx % colors.length],
      };
    }).toList();
  }

  Future<void> _deleteSearchHistory({String? keyword}) async {
    try {
      await _apiService.deleteSearchHistory(userId: _userId, keyword: keyword);
      await _loadSearchOverview();
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
      setState(() { _lastQuery = ''; _searchResults = []; });
      return;
    }
    setState(() { _isSearching = true; _lastQuery = keyword; });

    try {
      final docs = await _apiService.searchDocuments(keyword, userId: _userId);
      if (!mounted) return;
      final normalized = _normalizeDocs(docs);
      setState(() { _searchResults = normalized; _isSearching = false; });
      _loadSearchOverview();
    } catch (e, st) {
      debugPrint('=== SEARCH ERROR: $e\n$st');
      if (!mounted) return;
      setState(() { _isSearching = false; _searchResults = []; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Pencarian gagal: $e'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFFB00020),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  Widget _buildStaggeredItem(int index, Widget child) {
    return AnimatedBuilder(
      animation: _staggerController,
      builder: (context, _) {
        final slide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
          CurvedAnimation(parent: _staggerController,
            curve: Interval((index * 0.1).clamp(0.0, 0.6), 0.9, curve: Curves.easeOutCubic)),
        );
        final fade = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(parent: _staggerController,
            curve: Interval((index * 0.1).clamp(0.0, 0.6), 0.9)),
        );
        return FadeTransition(opacity: fade, child: SlideTransition(position: slide, child: child));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Expanded(child: SafeArea(child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildSmartHeader()),
          SliverToBoxAdapter(child: _buildModernSearchBar()),
          if (_isSearching)
            const SliverToBoxAdapter(child: Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Center(child: CircularProgressIndicator()),
            ))
          else if (_lastQuery.isNotEmpty)
            SliverToBoxAdapter(child: _buildSearchResults())
          else ...[
            SliverToBoxAdapter(child: _buildRecentSearches()),
            SliverToBoxAdapter(child: _buildPopularDocs()),
            SliverToBoxAdapter(child: _buildSmartShortcutsGrid()),
            SliverToBoxAdapter(child: _buildRecommendedDocs()),
            SliverToBoxAdapter(child: _buildTrendingTopics()),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ))),
    ]);
  }

  // ==========================================
  // HEADER
  // ==========================================
  Widget _buildSmartHeader() {
  return _buildStaggeredItem(0,
    Padding(
      padding: EdgeInsets.fromLTRB(_w(0.04), _w(0.02), _w(0.04), _w(0.02)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Pencarian Cerdas",
                style: TextStyle(
                  fontSize: _f(20),
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1E3A5F),
                ),
              ),
              Text(
                "Temukan dokumen akademik terbaik",
                style: TextStyle(
                  fontSize: _f(11),
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
          const Spacer(),
        ],
      ),
    ),
  );
}

  // ==========================================
  // SEARCH BAR
  // ==========================================
  Widget _buildModernSearchBar() {
    return _buildStaggeredItem(1,
      Padding(
        padding: EdgeInsets.symmetric(horizontal: _w(0.06), vertical: _w(0.03)),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_w(0.04)),
            boxShadow: [BoxShadow(
              color: const Color(0xFF1565C0).withOpacity(0.12),
              blurRadius: 24, offset: const Offset(0, 8),
            )],
          ),
          child: Row(children: [
            Expanded(child: TextField(
              controller: _searchController,
              onSubmitted: (_) => _searchAction(),
              style: TextStyle(fontSize: _f(14), color: const Color(0xFF1E3A5F),
                fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: 'Judul, penulis, atau kata kunci...',
                hintStyle: TextStyle(fontSize: _f(13), color: Colors.grey.shade400),
                prefixIcon: Icon(Icons.search_rounded, color: const Color(0xFF1565C0), size: _f(22)),
                prefixIconConstraints: BoxConstraints(minWidth: _w(0.12), minHeight: _w(0.12)),
                border: InputBorder.none,
                contentPadding: EdgeInsets.only(top: _w(0.035), bottom: _w(0.035), right: _w(0.02)),
              ),
            )),
            Padding(
              padding: EdgeInsets.all(_w(0.015)),
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1565C0), Color(0xFF1E88E5)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(_w(0.03)),
                  boxShadow: [BoxShadow(
                    color: const Color(0xFF1565C0).withOpacity(0.4),
                    blurRadius: 8, offset: const Offset(0, 4),
                  )],
                ),
                child: Material(color: Colors.transparent,
                  borderRadius: BorderRadius.circular(_w(0.03)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(_w(0.03)),
                    onTap: _searchAction,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: _w(0.045), vertical: _w(0.028)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.search_rounded, color: Colors.white, size: _f(15)),
                        SizedBox(width: _w(0.01)),
                        Text("Cari", style: TextStyle(fontSize: _f(13),
                          fontWeight: FontWeight.bold, color: Colors.white)),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ==========================================
  // RECENT SEARCHES
  // ==========================================
  Widget _buildRecentSearches() {
    if (_recentSearches.isEmpty) return const SizedBox.shrink();

    return _buildStaggeredItem(2,
      Padding(
        padding: EdgeInsets.fromLTRB(_w(0.06), _w(0.02), _w(0.06), _w(0.01)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [
              Container(
                padding: EdgeInsets.all(_w(0.015)),
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(_w(0.015)),
                ),
                child: Icon(Icons.history_rounded, size: _f(14), color: const Color(0xFF1565C0)),
              ),
              SizedBox(width: _w(0.02)),
              Text("Riwayat Pencarian",
                style: TextStyle(fontSize: _f(13), fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E3A5F))),
            ]),
            GestureDetector(
              onTap: () async {
                setState(() => _recentSearches.clear());
                await _deleteSearchHistory();
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: _w(0.025), vertical: _w(0.01)),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text("Hapus Semua",
                  style: TextStyle(fontSize: _f(10), fontWeight: FontWeight.w600,
                    color: Colors.red.shade400)),
              ),
            ),
          ]),
          SizedBox(height: _w(0.025)),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(_w(0.03)),
              boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10, offset: const Offset(0, 4),
              )],
            ),
            child: Column(
              children: _recentSearches.asMap().entries.map((entry) {
                final idx    = entry.key;
                final search = entry.value;
                final isLast = idx == _recentSearches.length - 1;
                return Column(children: [
                  InkWell(
                    onTap: () {
                      setState(() => _searchController.text = search);
                      _searchAction();
                    },
                    borderRadius: BorderRadius.vertical(
                      top: idx == 0 ? Radius.circular(_w(0.03)) : Radius.zero,
                      bottom: isLast ? Radius.circular(_w(0.03)) : Radius.zero,
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: _w(0.04), vertical: _w(0.03)),
                      child: Row(children: [
                        Container(
                          padding: EdgeInsets.all(_w(0.015)),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4F8FF),
                            borderRadius: BorderRadius.circular(_w(0.015)),
                          ),
                          child: Icon(Icons.north_west_rounded, size: _f(13),
                            color: Colors.grey.shade500),
                        ),
                        SizedBox(width: _w(0.03)),
                        Expanded(child: Text(search,
                          style: TextStyle(fontSize: _f(13), color: const Color(0xFF1E3A5F),
                            fontWeight: FontWeight.w500))),
                        GestureDetector(
                          onTap: () async {
                            setState(() => _recentSearches.remove(search));
                            await _deleteSearchHistory(keyword: search);
                          },
                          child: Container(
                            padding: EdgeInsets.all(_w(0.01)),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.close_rounded, size: _f(13),
                              color: Colors.grey.shade500),
                          ),
                        ),
                      ]),
                    ),
                  ),
                  if (!isLast) Divider(height: 1, color: Colors.grey.shade100, indent: _w(0.14)),
                ]);
              }).toList(),
            ),
          ),
        ]),
      ),
    );
  }

  // ==========================================
  // DOKUMEN TERPOPULER MINGGU INI
  // ==========================================
  Widget _buildPopularDocs() {
    return _buildStaggeredItem(3,
      Padding(
        padding: EdgeInsets.fromLTRB(0, _w(0.03), 0, _w(0.01)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: _w(0.06)),
            child: Row(children: [
              Container(
                padding: EdgeInsets.all(_w(0.015)),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.amber.shade400, Colors.orange.shade500],
                  ),
                  borderRadius: BorderRadius.circular(_w(0.015)),
                ),
                child: Icon(Icons.trending_up_rounded, size: _f(14), color: Colors.white),
              ),
              SizedBox(width: _w(0.02)),
              Text("Terpopuler Minggu Ini",
                style: TextStyle(fontSize: _f(13), fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E3A5F))),
              SizedBox(width: _w(0.02)),
              Container(
                padding: EdgeInsets.symmetric(horizontal: _w(0.02), vertical: _w(0.005)),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Text("7 HARI",
                  style: TextStyle(fontSize: _f(8), fontWeight: FontWeight.w800,
                    color: Colors.amber.shade700, letterSpacing: 0.8)),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _loadPopularDocs,
                child: Container(
                  padding: EdgeInsets.all(_w(0.015)),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(_w(0.015)),
                  ),
                  child: Icon(Icons.refresh_rounded, size: _f(13), color: Colors.grey.shade500),
                ),
              ),
              SizedBox(width: _w(0.06)),
            ]),
          ),
          SizedBox(height: _w(0.025)),
          if (_isLoadingPopular)
            SizedBox(
              height: _w(0.38),
              child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (_popularDocs.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: _w(0.06)),
              child: _buildEmptyHorizontalCard(
                icon: Icons.trending_up_rounded,
                message: 'Belum ada data populer',
              ),
            )
          else
            SizedBox(
              height: _w(0.38),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: _w(0.06)),
                itemCount: _popularDocs.length,
                itemBuilder: (context, index) =>
                  _buildPopularDocCard(_popularDocs[index], rank: index + 1),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _buildPopularDocCard(Map<String, dynamic> doc, {required int rank}) {
    final color = doc['color'] as Color;
    final rankColors = [
      const Color(0xFFFFD700),
      const Color(0xFFC0C0C0),
      const Color(0xFFCD7F32),
    ];
    final rankColor = rank <= 3 ? rankColors[rank - 1] : Colors.grey.shade300;

    return GestureDetector(
      onTap: () => Navigator.push(context,
        MaterialPageRoute(builder: (_) =>
          DetailDokumenPage(document: doc, apiService: _apiService))),
      child: Container(
        width: _w(0.55),
        margin: EdgeInsets.only(right: _w(0.03)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 14, offset: const Offset(0, 5),
          )],
          border: Border.all(color: color.withOpacity(0.12)),
        ),
        child: Stack(children: [
          Positioned(
            top: _w(0.025), right: _w(0.025),
            child: Container(
              width: _w(0.07), height: _w(0.07),
              decoration: BoxDecoration(
                color: rankColor, shape: BoxShape.circle,
                boxShadow: [BoxShadow(
                  color: rankColor.withOpacity(0.4),
                  blurRadius: 6, offset: const Offset(0, 2),
                )],
              ),
              child: Center(child: Text('#$rank',
                style: TextStyle(fontSize: _f(9), fontWeight: FontWeight.w800,
                  color: rank == 1 ? const Color(0xFF7A5800) : Colors.white))),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(_w(0.04)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
              Container(
                padding: EdgeInsets.all(_w(0.025)),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(_w(0.02)),
                ),
                child: Icon(Icons.description_rounded, size: _f(18), color: color),
              ),
              SizedBox(height: _w(0.02)),
              Text(doc['title']?.toString() ?? '-',
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: _f(11.5), fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E3A5F), height: 1.3)),
              SizedBox(height: _w(0.01)),
              Row(children: [
                Icon(Icons.person_outline_rounded, size: _f(10), color: Colors.grey.shade400),
                SizedBox(width: _w(0.01)),
                Expanded(child: Text(doc['author']?.toString() ?? '-',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: _f(10), color: Colors.grey.shade500))),
              ]),
              SizedBox(height: _w(0.02)),
              Row(children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: _w(0.02), vertical: _w(0.007)),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(doc['category']?.toString() ?? 'Dokumen',
                    style: TextStyle(fontSize: _f(8.5), fontWeight: FontWeight.w700, color: color)),
                ),
                const Spacer(),
                Icon(Icons.download_rounded, size: _f(10), color: Colors.grey.shade400),
                SizedBox(width: _w(0.008)),
                Text(doc['downloads']?.toString() ?? '0',
                  style: TextStyle(fontSize: _f(10), color: Colors.grey.shade500,
                    fontWeight: FontWeight.w600)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  // ==========================================
  // REKOMENDASI UNTUK KAMU
  // ==========================================
  Widget _buildRecommendedDocs() {
    return _buildStaggeredItem(5,
      Padding(
        padding: EdgeInsets.fromLTRB(_w(0.06), _w(0.03), _w(0.06), _w(0.01)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: EdgeInsets.all(_w(0.015)),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7B1FA2), Color(0xFFAB47BC)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(_w(0.015)),
              ),
              child: Icon(Icons.auto_awesome_rounded, size: _f(14), color: Colors.white),
            ),
            SizedBox(width: _w(0.02)),
            Text("Rekomendasi untuk Kamu",
              style: TextStyle(fontSize: _f(13), fontWeight: FontWeight.w700,
                color: const Color(0xFF1E3A5F))),
            SizedBox(width: _w(0.02)),
            if (_userId != null)
              Container(
                padding: EdgeInsets.symmetric(horizontal: _w(0.02), vertical: _w(0.005)),
                decoration: BoxDecoration(
                  color: const Color(0xFF7B1FA2).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF7B1FA2).withOpacity(0.25)),
                ),
                child: Text("AI",
                  style: TextStyle(fontSize: _f(8), fontWeight: FontWeight.w800,
                    color: const Color(0xFF7B1FA2), letterSpacing: 0.8)),
              )
            else
              Container(
                padding: EdgeInsets.symmetric(horizontal: _w(0.02), vertical: _w(0.005)),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text("Login untuk hasil terbaik",
                  style: TextStyle(fontSize: _f(8), color: Colors.grey.shade500)),
              ),
          ]),
          SizedBox(height: _w(0.015)),
          Text(
            _userId != null
              ? (_recommendedKeyword != null
                  ? 'Karena kamu sering cari "$_recommendedKeyword"'
                  : 'Berdasarkan riwayat pencarian dan prodimu')
              : 'Dokumen populer yang mungkin kamu suka',
            style: TextStyle(fontSize: _f(11), color: Colors.grey.shade500),
          ),
          SizedBox(height: _w(0.025)),
          if (_isLoadingRecommended)
            Container(
              height: _w(0.3),
              alignment: Alignment.center,
              child: const CircularProgressIndicator(strokeWidth: 2),
            )
          else if (_recommendedDocs.isEmpty)
            _buildEmptyHorizontalCard(
              icon: Icons.auto_awesome_rounded,
              message: 'Belum ada rekomendasi',
            )
          else
            Column(
              children: _recommendedDocs.asMap().entries.map((entry) =>
                _buildRecommendedDocCard(entry.value, index: entry.key)
              ).toList(),
            ),
        ]),
      ),
    );
  }

  Widget _buildRecommendedDocCard(Map<String, dynamic> doc, {required int index}) {
    final color = doc['color'] as Color;
    final icons = [
      Icons.psychology_rounded,
      Icons.biotech_rounded,
      Icons.architecture_rounded,
      Icons.calculate_rounded,
      Icons.eco_rounded,
    ];

    return GestureDetector(
      onTap: () => Navigator.push(context,
        MaterialPageRoute(builder: (_) =>
          DetailDokumenPage(document: doc, apiService: _apiService))),
      child: Container(
        margin: EdgeInsets.only(bottom: _w(0.025)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 12, offset: const Offset(0, 4),
          )],
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Row(children: [
          Container(
            width: _w(0.012), height: _w(0.18),
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: _w(0.035)),
            child: Container(
              width: _w(0.11), height: _w(0.11),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(_w(0.025)),
              ),
              child: Icon(icons[index % icons.length], size: _f(20), color: color),
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: _w(0.03)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(doc['title']?.toString() ?? '-',
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: _f(12), fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E3A5F), height: 1.3)),
                SizedBox(height: _w(0.008)),
                Row(children: [
                  Icon(Icons.person_outline_rounded, size: _f(10), color: Colors.grey.shade400),
                  SizedBox(width: _w(0.01)),
                  Expanded(child: Text(doc['author']?.toString() ?? '-',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: _f(10), color: Colors.grey.shade400))),
                ]),
                SizedBox(height: _w(0.01)),
                Row(children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: _w(0.02), vertical: _w(0.005)),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(doc['category']?.toString() ?? 'Dokumen',
                      style: TextStyle(fontSize: _f(8.5), fontWeight: FontWeight.w700, color: color)),
                  ),
                  SizedBox(width: _w(0.02)),
                  Icon(Icons.download_outlined, size: _f(10), color: Colors.grey.shade400),
                  SizedBox(width: _w(0.005)),
                  Text('${doc['downloads']} unduhan',
                    style: TextStyle(fontSize: _f(9.5), color: Colors.grey.shade400)),
                ]),
              ]),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(right: _w(0.035)),
            child: Icon(Icons.arrow_forward_ios_rounded, size: _f(11), color: color.withOpacity(0.5)),
          ),
        ]),
      ),
    );
  }

  Widget _buildEmptyHorizontalCard({required IconData icon, required String message}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: _w(0.06)),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: Colors.grey.shade300, size: _f(28)),
        SizedBox(height: _w(0.02)),
        Text(message,
          style: TextStyle(fontSize: _f(12), color: Colors.grey.shade400,
            fontWeight: FontWeight.w500)),
      ]),
    );
  }

  // ==========================================
  // SHORTCUTS GRID
  // ==========================================
  Widget _buildSmartShortcutsGrid() {
    return _buildStaggeredItem(4,
      Padding(
        padding: EdgeInsets.symmetric(vertical: _w(0.03)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: _w(0.06)),
            child: Row(children: [
              Container(
                padding: EdgeInsets.all(_w(0.015)),
                decoration: BoxDecoration(
                  color: const Color(0xFF7B1FA2).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(_w(0.015)),
                ),
                child: Icon(Icons.grid_view_rounded, size: _f(14), color: const Color(0xFF7B1FA2)),
              ),
              SizedBox(width: _w(0.02)),
              Text("Jelajahi Kategori",
                style: TextStyle(fontSize: _f(13), fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E3A5F))),
            ]),
          ),
          SizedBox(height: _w(0.025)),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: _w(0.06)),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: _w(0.03),
              mainAxisSpacing: _w(0.03),
              childAspectRatio: 1.55,
            ),
            itemCount: _shortcuts.length,
            itemBuilder: (context, index) => _buildShortcutCard(_shortcuts[index]),
          ),
        ]),
      ),
    );
  }

  Widget _buildShortcutCard(Map<String, dynamic> data) {
    final color = data['color'] as Color;
    return InkWell(
      onTap: () {
        setState(() => _searchController.text = data['label'].toString());
        _searchAction();
      },
      borderRadius: BorderRadius.circular(_w(0.035)),
      child: Container(
        padding: EdgeInsets.all(_w(0.035)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_w(0.035)),
          boxShadow: [BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 12, offset: const Offset(0, 4),
          )],
          border: Border.all(color: color.withOpacity(0.12), width: 1.5),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: EdgeInsets.all(_w(0.02)),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(_w(0.02)),
            ),
            child: Icon(data['icon'] as IconData, size: _f(18), color: color),
          ),
          SizedBox(height: _w(0.02)),
          Text(data['label'].toString(),
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: _f(12), fontWeight: FontWeight.w700,
              color: const Color(0xFF1E3A5F))),
          SizedBox(height: _w(0.004)),
          Text("${data['count']} Dokumen",
            style: TextStyle(fontSize: _f(9.5), color: color,
              fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  // ==========================================
  // TRENDING TOPICS
  // ==========================================
  Widget _buildTrendingTopics() {
    final colors = [
      const Color(0xFF1565C0), const Color(0xFF7B1FA2), const Color(0xFFE65100),
      const Color(0xFF0277BD), const Color(0xFF2E7D32), const Color(0xFF00695C),
      const Color(0xFF6A1B9A), const Color(0xFF4E342E), const Color(0xFF1565C0),
      const Color(0xFF7B1FA2),
    ];

    return _buildStaggeredItem(6,
      Padding(
        padding: EdgeInsets.fromLTRB(_w(0.06), _w(0.01), _w(0.06), _w(0.03)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: EdgeInsets.all(_w(0.015)),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange.shade400, Colors.deepOrange.shade400],
                ),
                borderRadius: BorderRadius.circular(_w(0.015)),
              ),
              child: Icon(Icons.local_fire_department_rounded, size: _f(14), color: Colors.white),
            ),
            SizedBox(width: _w(0.02)),
            Text("Trending Sekarang",
              style: TextStyle(fontSize: _f(13), fontWeight: FontWeight.w700,
                color: const Color(0xFF1E3A5F))),
            SizedBox(width: _w(0.02)),
            Container(
              padding: EdgeInsets.symmetric(horizontal: _w(0.02), vertical: _w(0.005)),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Text("LIVE",
                style: TextStyle(fontSize: _f(8), fontWeight: FontWeight.w800,
                  color: Colors.orange.shade700, letterSpacing: 1)),
            ),
          ]),
          SizedBox(height: _w(0.025)),
          Wrap(
            spacing: _w(0.02),
            runSpacing: _w(0.02),
            children: _trendingTopics.asMap().entries.map((entry) {
              final idx   = entry.key;
              final topic = entry.value;
              final color = colors[idx % colors.length];
              return InkWell(
                onTap: () {
                  setState(() => _searchController.text = topic);
                  _searchAction();
                },
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: _w(0.035), vertical: _w(0.018)),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: color.withOpacity(0.25)),
                    boxShadow: [BoxShadow(
                      color: color.withOpacity(0.08),
                      blurRadius: 6, offset: const Offset(0, 2),
                    )],
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text("${idx + 1}",
                      style: TextStyle(fontSize: _f(9), fontWeight: FontWeight.w800,
                        color: color)),
                    SizedBox(width: _w(0.01)),
                    Container(width: 1, height: _f(10), color: color.withOpacity(0.3)),
                    SizedBox(width: _w(0.01)),
                    Text(topic,
                      style: TextStyle(fontSize: _f(11), color: color,
                        fontWeight: FontWeight.w600)),
                  ]),
                ),
              );
            }).toList(),
          ),
        ]),
      ),
    );
  }

  // ==========================================
  // SEARCH RESULTS
  // ==========================================
  Widget _buildSearchResults() {
    return Padding(
      padding: EdgeInsets.fromLTRB(_w(0.06), _w(0.01), _w(0.06), _w(0.02)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: _w(0.03), vertical: _w(0.012)),
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0).withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.search_rounded, size: _f(12), color: const Color(0xFF1565C0)),
              SizedBox(width: _w(0.01)),
              Text('Hasil: "$_lastQuery"',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: _f(11), fontWeight: FontWeight.w600,
                  color: const Color(0xFF1565C0))),
            ]),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: () {
              setState(() { _lastQuery = ''; _searchResults = []; _searchController.clear(); });
            },
            icon: Icon(Icons.close_rounded, size: _f(13)),
            label: Text("Reset", style: TextStyle(fontSize: _f(11))),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey.shade600,
              padding: EdgeInsets.symmetric(horizontal: _w(0.025), vertical: _w(0.01)),
            ),
          ),
        ]),
        SizedBox(height: _w(0.03)),
        if (_searchResults.isEmpty)
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: _w(0.1)),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(children: [
              Icon(Icons.search_off_rounded, color: Colors.grey.shade300, size: _f(40)),
              SizedBox(height: _w(0.02)),
              Text('Dokumen tidak ditemukan',
                style: TextStyle(fontSize: _f(13), fontWeight: FontWeight.w600,
                  color: Colors.grey.shade500)),
              SizedBox(height: _w(0.01)),
              Text('Coba kata kunci lain',
                style: TextStyle(fontSize: _f(11), color: Colors.grey.shade400)),
            ]),
          )
        else
          ..._searchResults.map(_buildSearchResultCard),
      ]),
    );
  }

  Widget _buildSearchResultCard(Map<String, dynamic> doc) {
    return GestureDetector(
      onTap: () => Navigator.push(context,
        MaterialPageRoute(builder: (_) =>
          DetailDokumenPage(document: doc, apiService: _apiService))),
      child: Container(
        margin: EdgeInsets.only(bottom: _w(0.03)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16, offset: const Offset(0, 6),
          )],
        ),
        child: Column(children: [
          Padding(
            padding: EdgeInsets.all(_w(0.04)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: _w(0.1), height: _w(0.1),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(_w(0.025)),
                ),
                child: Icon(Icons.description_rounded, color: Colors.white, size: _f(20)),
              ),
              SizedBox(width: _w(0.03)),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(doc['title']?.toString() ?? '-',
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: _f(13), fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E3A5F), height: 1.3)),
                SizedBox(height: _w(0.01)),
                Row(children: [
                  Icon(Icons.person_outline_rounded, size: _f(11), color: Colors.grey.shade400),
                  SizedBox(width: _w(0.01)),
                  Expanded(child: Text(doc['author']?.toString() ?? '-',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: _f(11), color: Colors.grey.shade500))),
                ]),
              ])),
            ]),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: _w(0.04), vertical: _w(0.025)),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFD),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              border: Border(top: BorderSide(color: Colors.grey.shade100)),
            ),
            child: Row(children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: _w(0.025), vertical: _w(0.008)),
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(doc['category']?.toString() ?? 'Dokumen',
                  style: TextStyle(fontSize: _f(9.5), fontWeight: FontWeight.w700,
                    color: const Color(0xFF1565C0))),
              ),
              const Spacer(),
              Icon(Icons.access_time_rounded, size: _f(11), color: Colors.grey.shade400),
              SizedBox(width: _w(0.01)),
              Text(doc['date']?.toString() ?? '-',
                style: TextStyle(fontSize: _f(10), color: Colors.grey.shade400)),
              SizedBox(width: _w(0.02)),
              Icon(Icons.arrow_forward_ios_rounded, size: _f(10), color: Colors.grey.shade400),
            ]),
          ),
        ]),
      ),
    );
  }
}