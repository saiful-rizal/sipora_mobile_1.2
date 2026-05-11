class AppSessionService {
  AppSessionService._();

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

  static void setCurrentUser(Map<String, dynamic> user) {
    _currentUser = Map<String, dynamic>.from(user);
  }

  static void clear() {
    _currentUser = null;
  }
}
