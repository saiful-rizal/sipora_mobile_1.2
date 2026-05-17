import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AppSessionService {
  AppSessionService._();

  static const _key = 'current_user';
  static Map<String, dynamic>? _currentUser;

  static Map<String, dynamic>? get currentUser => _currentUser;

  static int? get currentUserId {
    final raw = _currentUser?['id_user'];
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '');
  }

  static String? get currentEmail {
    final value = _currentUser?['email']?.toString().trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  static String? get currentName {
    final value = _currentUser?['nama_lengkap']?.toString().trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  // Panggil sekali saat app start
  static Future<void> loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_key);
    if (json != null) {
      _currentUser = Map<String, dynamic>.from(jsonDecode(json));
    }
  }

  // Sekarang async — simpan ke RAM + disk
  static Future<void> setCurrentUser(Map<String, dynamic> user) async {
    _currentUser = Map<String, dynamic>.from(user);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_currentUser));
  }

  static Future<void> clear() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}