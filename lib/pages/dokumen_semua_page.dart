import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/sipora_api_service.dart';

class SemuaDokumenPage extends StatefulWidget {
  const SemuaDokumenPage({super.key});

  @override
  State<SemuaDokumenPage> createState() => _SemuaDokumenPageState();
}

class _SemuaDokumenPageState extends State<SemuaDokumenPage> {
  final SiporaApiService _apiService = SiporaApiService();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  String _query = '';
  List<Map<String, dynamic>> _documents = [];

  double _w(double p) => MediaQuery.of(context).size.width * p;
  double _f(double s) =>
      s * (MediaQuery.of(context).size.width / 400).clamp(0.8, 1.1);

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDocuments() async {
    try {
      final docs = await _apiService.fetchBrowseDocuments();
      final palette = [
        const Color(0xFF4F46E5),
        const Color(0xFF10B981),
        const Color(0xFFF59E0B),
        const Color(0xFFEF4444),
      ];

      final mappedDocs = docs.asMap().entries.map((entry) {
        final index = entry.key;
        final item = Map<String, dynamic>.from(entry.value);
        return {
          'id': item['id'],
          'title': (item['title'] ?? '-').toString(),
          'author': (item['author'] ?? '-').toString(),
          'date': (item['date'] ?? '-').toString(),
          'downloads': (item['downloads'] ?? 0).toString(),
          'type': (item['type'] ?? 'Dokumen').toString(),
          'status': (item['status'] ?? '-').toString(),
          'prodi': (item['prodi'] ?? '-').toString(),
          'file_path': (item['file_path'] ?? '').toString(),
          'color': palette[index % palette.length],
        };
      }).toList();

      if (!mounted) return;
      setState(() {
        _documents = mappedDocs;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredDocuments {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _documents;
    return _documents.where((doc) {
      return [
        doc['title'],
        doc['author'],
        doc['type'],
        doc['status'],
        doc['prodi'],
      ].any((value) => value.toString().toLowerCase().contains(query));
    }).toList();
  }

  Uri? _resolveDocumentUri(Map<String, dynamic> doc) {
    final filePath = doc['file_path']?.toString() ?? '';
    if (filePath.trim().isEmpty) return null;
    return _apiService.resolveFileUri(filePath);
  }

  Future<void> _downloadDocument(Map<String, dynamic> doc) async {
    final uri = _resolveDocumentUri(doc);
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File dokumen belum tersedia')),
      );
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal membuka file dokumen')),
      );
    }
  }

  void _openDocumentDetail(Map<String, dynamic> doc) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            DetailDokumenPage(document: doc, apiService: _apiService),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.fromLTRB(
                _w(0.04),
                _w(0.02),
                _w(0.04),
                _w(0.03),
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1E3A5F), Color(0xFF3B82F6)],
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: _w(0.01)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Semua Dokumen',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: _f(18),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${_filteredDocuments.length} dokumen tersedia',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: _f(11),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                _w(0.04),
                _w(0.03),
                _w(0.04),
                _w(0.02),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: 'Cari dokumen, penulis, atau jurusan',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: EdgeInsets.symmetric(vertical: _w(0.035)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredDocuments.isEmpty
                  ? Center(
                      child: Text(
                        'Tidak ada dokumen yang cocok',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: _f(13),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.fromLTRB(
                        _w(0.04),
                        0,
                        _w(0.04),
                        _w(0.05),
                      ),
                      itemCount: _filteredDocuments.length,
                      separatorBuilder: (_, __) => SizedBox(height: _w(0.02)),
                      itemBuilder: (context, index) {
                        final doc = _filteredDocuments[index];
                        return _DocumentCard(
                          document: doc,
                          onOpen: () => _openDocumentDetail(doc),
                          onDownload: () => _downloadDocument(doc),
                          width: _w,
                          fontSize: _f,
                          resolveUri: _resolveDocumentUri(doc),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class DetailDokumenPage extends StatelessWidget {
  const DetailDokumenPage({
    super.key,
    required this.document,
    required this.apiService,
  });

  final Map<String, dynamic> document;
  final SiporaApiService apiService;

  double _w(BuildContext context, double p) =>
      MediaQuery.of(context).size.width * p;
  double _f(BuildContext context, double s) =>
      s * (MediaQuery.of(context).size.width / 400).clamp(0.8, 1.1);

  Uri? _resolveDocumentUri() {
    final filePath = document['file_path']?.toString() ?? '';
    if (filePath.trim().isEmpty) return null;
    return apiService.resolveFileUri(filePath);
  }

  Future<void> _download(BuildContext context) async {
    final uri = _resolveDocumentUri();
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File dokumen belum tersedia')),
      );
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal membuka file dokumen')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = document['color'] as Color? ?? const Color(0xFF4F46E5);
    final title = document['title']?.toString() ?? '-';
    final author = document['author']?.toString() ?? '-';
    final date = document['date']?.toString() ?? '-';
    final type = document['type']?.toString() ?? 'Dokumen';
    final status = document['status']?.toString() ?? '-';
    final downloads = document['downloads']?.toString() ?? '0';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                _w(context, 0.04),
                _w(context, 0.02),
                _w(context, 0.04),
                _w(context, 0.03),
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1E3A5F), Color(0xFF3B82F6)],
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Detail Dokumen',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: _f(context, 18),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.all(_w(context, 0.04)),
                children: [
                  Container(
                    padding: EdgeInsets.all(_w(context, 0.05)),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: _w(context, 0.14),
                              height: _w(context, 0.14),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Icon(
                                Icons.description_rounded,
                                color: color,
                                size: _f(context, 28),
                              ),
                            ),
                            SizedBox(width: _w(context, 0.04)),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: TextStyle(
                                      fontSize: _f(context, 16),
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF1E3A5F),
                                    ),
                                  ),
                                  SizedBox(height: _w(context, 0.01)),
                                  Text(
                                    author,
                                    style: TextStyle(
                                      fontSize: _f(context, 12),
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: _w(context, 0.04)),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _MetaChip(label: type, color: color),
                            _MetaChip(
                              label: status,
                              color: const Color(0xFF64748B),
                            ),
                            _MetaChip(
                              label: date,
                              color: const Color(0xFF0F766E),
                            ),
                          ],
                        ),
                        SizedBox(height: _w(context, 0.04)),
                        Container(
                          padding: EdgeInsets.all(_w(context, 0.04)),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFD),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE5EAF2)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    downloads,
                                    style: TextStyle(
                                      fontSize: _f(context, 18),
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF1E3A5F),
                                    ),
                                  ),
                                  Text(
                                    'Download',
                                    style: TextStyle(
                                      fontSize: _f(context, 11),
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                              ElevatedButton.icon(
                                onPressed: () => _download(context),
                                icon: const Icon(Icons.file_download_outlined),
                                label: const Text('Unduh'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: color,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.document,
    required this.onOpen,
    required this.onDownload,
    required this.width,
    required this.fontSize,
    required this.resolveUri,
  });

  final Map<String, dynamic> document;
  final VoidCallback onOpen;
  final VoidCallback onDownload;
  final double Function(double) width;
  final double Function(double) fontSize;
  final Uri? resolveUri;

  @override
  Widget build(BuildContext context) {
    final color = document['color'] as Color? ?? const Color(0xFF4F46E5);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(width(0.04)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: width(0.11),
                  height: width(0.11),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.description_rounded,
                    color: color,
                    size: fontSize(24),
                  ),
                ),
                SizedBox(width: width(0.03)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        document['title']?.toString() ?? '-',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: fontSize(13.5),
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1E3A5F),
                          height: 1.35,
                        ),
                      ),
                      SizedBox(height: width(0.01)),
                      Text(
                        document['author']?.toString() ?? '-',
                        style: TextStyle(
                          fontSize: fontSize(11),
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: width(0.02)),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetaChip(
                  label: document['type']?.toString() ?? 'Dokumen',
                  color: color,
                ),
                _MetaChip(
                  label: document['status']?.toString() ?? '-',
                  color: const Color(0xFF64748B),
                ),
                _MetaChip(
                  label: document['date']?.toString() ?? '-',
                  color: const Color(0xFF0F766E),
                ),
              ],
            ),
            SizedBox(height: width(0.02)),
            Row(
              children: [
                Icon(
                  Icons.download_done_rounded,
                  size: fontSize(13),
                  color: Colors.green[600],
                ),
                const SizedBox(width: 4),
                Text(
                  '${document['downloads'] ?? 0} Download',
                  style: TextStyle(
                    fontSize: fontSize(10.5),
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('Lihat'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: resolveUri == null ? null : onDownload,
                  icon: const Icon(Icons.file_download_outlined),
                  label: const Text('Unduh'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(
                      horizontal: width(0.03),
                      vertical: width(0.02),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
