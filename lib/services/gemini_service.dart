import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GeminiService {
  static const String _model = 'gemini-2.0-flash';
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';

  late final String _apiKey;

  GeminiService() {
    // ✅ Pelindung kalau .env gagal load
    try {
      _apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    } catch (e) {
      _apiKey = '';
    }
  }

  bool get isReady => _apiKey.isNotEmpty;

  Future<String> sendMessage({
    required String message,
    List<Map<String, String>>? history,
  }) async {
    if (!isReady) {
      throw Exception('API Key belum diset. Cek file .env');
    }

    // Bangun konteks percakapan
    final contents = <Map<String, dynamic>>[];

    // System instruction via pesan pertama
    contents.add({
      'role': 'user',
      'parts': [
        {
          'text':
              '''Kamu adalah asisten AI bernama "DocuBot" di dalam aplikasi manajemen dokumen PDF. 

Aturanmu:
- Jawab selalu dalam Bahasa Indonesia yang natural dan ramah
- Gunakan format markdown jika perlu (list, bold, dll)
- Jika ditanya di luar dokumen, jawab dengan sopan
- Jika tidak tahu jawabannya, katakan dengan jujur
- Pendek dan to the point, jangan terlalu panjang''',
        },
      ],
    });
    contents.add({
      'role': 'model',
      'parts': [
        {
          'text':
              'Siap! Saya DocuBot, asisten AI kamu. Ada yang bisa saya bantu? 😊',
        },
      ],
    });

    // Tambahkan history chat
    if (history != null) {
      for (final msg in history) {
        contents.add({
          'role': msg['role'] == 'user' ? 'user' : 'model',
          'parts': [
            {'text': msg['content']},
          ],
        });
      }
    }

    // Tambahkan pesan terbaru
    contents.add({
      'role': 'user',
      'parts': [
        {'text': message},
      ],
    });

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': contents,
          'generationConfig': {
            'temperature': 0.8,
            'topP': 0.95,
            'topK': 40,
            'maxOutputTokens': 1024,
          },
        }),
      );

      final body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final text = body['candidates']?[0]?['content']?['parts']?[0]?['text'];
        if (text != null) return text;
        return 'Maaf, saya tidak bisa menghasilkan jawaban saat ini.';
      }

      // Handle error dari API
      final errMsg = body['error']?['message'] ?? 'Unknown error';
      throw Exception(errMsg);
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Koneksi gagal: ${e.toString()}');
    }
  }
}
