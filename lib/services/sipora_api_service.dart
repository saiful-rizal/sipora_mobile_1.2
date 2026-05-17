import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'app_session_service.dart';
import 'localhost_api_service.dart';

class SiporaApiService {
  SiporaApiService({LocalhostApiService? client})
    : _client = client ?? LocalhostApiService();

  final LocalhostApiService _client;

  Uri resolveFileUri(String filePath) => _client.resolveFileUri(filePath);

  Future<Map<String, dynamic>> fetchDashboard({int? userId, String? email}) {
    return _client.get('sipora_api.php', query: {
      'action': 'dashboard',
      if (userId != null) 'user_id': '$userId',
      if (email != null) 'email': email,
    });
  }

  Future<List<Map<String, dynamic>>> fetchBrowseDocuments({
    String? year,
    String? jurusan,
    String? prodi,
  }) async {
    final response = await _client.get(
      'sipora_api.php',
      query: {
        'action': 'browse_documents',
        if (year != null && year.isNotEmpty) 'year': year,
        if (jurusan != null && jurusan.isNotEmpty) 'jurusan': jurusan,
        if (prodi != null && prodi.isNotEmpty) 'prodi': prodi,
      },
    );

    final docs = (response['documents'] as List?) ?? const [];
    return docs.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // Backend response harus menyertakan:
  //   'top_keyword' : String? — keyword paling sering dicari user ini
  //                   (query: SELECT keyword, COUNT(*) FROM search_history
  //                           WHERE user_id=? GROUP BY keyword ORDER BY COUNT(*) DESC LIMIT 1)
  //   'recent_searches', 'trending_topics', 'shortcuts' (sama seperti sebelumnya)
  Future<Map<String, dynamic>> fetchSearchOverview() {
    final userId = AppSessionService.currentUserId;
    return _client.get('sipora_api.php', query: {
      'action': 'search_overview',
      if (userId != null) 'user_id': '$userId',
    });
  }

  Future<List<Map<String, dynamic>>> searchDocuments(
    String keyword, {
    int? userId,
  }) async {
    final response = await _client.post(
      'sipora_api.php',
      query: {'action': 'search_documents'},
      body: {
        'keyword': keyword,
        if (userId != null) 'user_id': userId,
      },
    );
    final docs = (response['documents'] as List?) ?? const [];
    return docs.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> deleteSearchHistory({int? userId, String? keyword}) async {
    await _client.post(
      'sipora_api.php',
      query: {'action': 'delete_search_history'},
      body: {
        if (userId != null) 'user_id': userId,
        if (keyword != null) 'keyword': keyword,
      },
    );
  }

  // ── NEW: dokumen terpopuler berdasarkan download dalam 7 hari terakhir ───
  Future<List<Map<String, dynamic>>> fetchPopularDocuments({int days = 7}) async {
    final response = await _client.get(
      'sipora_api.php',
      query: {
        'action': 'popular_documents',
        'days': '$days',
      },
    );
    final docs = (response['documents'] as List?) ?? const [];
    return docs.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // ── NEW: rekomendasi dokumen berdasarkan userId / prodi ──────────────────
  // topKeyword = kata kunci paling sering dicari user (dari search_history)
  // Backend akan prioritaskan pencarian berdasarkan keyword ini,
  // kemudian fallback ke prodi user, lalu ke dokumen populer umum.
  Future<List<Map<String, dynamic>>> fetchRecommendedDocuments({
    int? userId,
    String? topKeyword,
  }) async {
    final response = await _client.get(
      'sipora_api.php',
      query: {
        'action': 'recommended_documents',
        if (userId != null) 'user_id': '$userId',
        if (topKeyword != null && topKeyword.isNotEmpty) 'top_keyword': topKeyword,
      },
    );
    final docs = (response['documents'] as List?) ?? const [];
    return docs.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
  // ─────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> fetchLookupOptions() {
    return _client.get('sipora_api.php', query: {'action': 'lookup_options'});
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) {
    return _client.post(
      'sipora_api.php',
      query: {'action': 'login'},
      body: {'email': email, 'password': password},
    );
  }

  Future<Map<String, dynamic>> registerPushToken({
    required String token,
    String? email,
    int? userId,
  }) {
    return _client.post(
      'sipora_api.php',
      query: {'action': 'register_push_token'},
      body: {
        'token': token,
        if (email != null && email.isNotEmpty) 'email': email,
        if (userId != null) 'user_id': userId,
        'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      },
    );
  }

  Future<List<Map<String, dynamic>>> fetchNotifications({
    String? email,
    int? userId,
  }) async {
    final response = await _client.get(
      'sipora_api.php',
      query: {
        'action': 'notifications',
        if (email != null && email.isNotEmpty) 'email': email,
        if (userId != null) 'user_id': '$userId',
      },
    );

    final items = (response['notifications'] as List?) ?? const [];
    return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> register({
    required String namaLengkap,
    required String nim,
    required String email,
    required String username,
    required String password,
  }) {
    return _client.post(
      'sipora_api.php',
      query: {'action': 'register'},
      body: {
        'nama_lengkap': namaLengkap,
        'nim': nim,
        'email': email,
        'username': username,
        'password': password,
      },
    );
  }

  Future<Map<String, dynamic>> uploadDocument({
    required String judul,
    required String abstrak,
    required String filePath,
    required List<int> fileBytes,
    required String tahun,
    required String jurusan,
    required String prodi,
    required String divisi,
    required String tema,
    required String tipeDokumen,
    required List<String> penulis,
    required List<String> kataKunci,
    required int turnitin,
    String? turnitinFile,
    int uploaderId = 1,
    String? uploaderEmail,
  }) {
    return _client.post(
      'sipora_api.php',
      query: {'action': 'upload_document'},
      body: {
        'judul': judul,
        'abstrak': abstrak,
        'file_path': filePath,
        'original_file_name': filePath,
        'file_bytes_base64': base64Encode(fileBytes),
        'tahun': tahun,
        'jurusan': jurusan,
        'prodi': prodi,
        'divisi': divisi,
        'tema': tema,
        'tipe_dokumen': tipeDokumen,
        'penulis': penulis,
        'kata_kunci': kataKunci,
        'turnitin': turnitin,
        'turnitin_file': turnitinFile ?? '',
        'uploader_id': uploaderId,
        if (uploaderEmail != null && uploaderEmail.isNotEmpty)
          'uploader_email': uploaderEmail,
      },
    );
  }

  Future<Map<String, dynamic>> screenDocument({
    required String fileName,
    required List<int> fileBytes,
    required String tipeDokumen,
  }) {
    return _client.post(
      'sipora_api.php',
      query: {'action': 'screen_document'},
      body: {
        'original_file_name': fileName,
        'file_bytes_base64': base64Encode(fileBytes),
        'tipe_dokumen': tipeDokumen,
      },
    );
  }

  Future<void> incrementDownload(int dokumenId) async {
    await _client.post(
      'sipora_api.php',
      query: {'action': 'increment_download'},
      body: {'dokumen_id': dokumenId},
    );
  }
}