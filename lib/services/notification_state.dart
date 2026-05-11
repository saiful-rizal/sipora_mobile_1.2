import 'package:flutter/foundation.dart';

class NotificationState {
  static final ValueNotifier<List<Map<String, dynamic>>> notifications =
      ValueNotifier<List<Map<String, dynamic>>>([
        {
          'id': 'seed-uploaded',
          'title': 'Dokumen Berhasil Diunggah',
          'message': 'File Skripsi_AI_2026.pdf berhasil diunggah.',
          'time': '2 menit lalu',
          'isRead': false,
        },
        {
          'id': 'seed-review',
          'title': 'Status Review Diperbarui',
          'message': 'Dokumen Anda sedang dalam proses validasi admin.',
          'time': '1 jam lalu',
          'isRead': false,
        },
        {
          'id': 'seed-approved',
          'title': 'Akun Disetujui',
          'message': 'Akun Anda sudah aktif dan dapat mengakses semua fitur.',
          'time': 'Kemarin',
          'isRead': true,
        },
      ]);

  static final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);
  static bool _initialized = false;

  static void initialize() {
    if (_initialized) return;
    _initialized = true;
    _recomputeUnread();
    notifications.addListener(_recomputeUnread);
  }

  static void setUnreadCount(int count) {
    unreadCount.value = count < 0 ? 0 : count;
  }

  static void addNotification({
    required String title,
    required String message,
    String? time,
    String? id,
    Map<String, dynamic>? data,
  }) {
    final current = List<Map<String, dynamic>>.from(notifications.value);
    current.insert(0, {
      'id': id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      'title': title,
      'message': message,
      'time': time ?? 'Baru saja',
      'isRead': false,
      if (data != null && data.isNotEmpty)
        'data': Map<String, dynamic>.from(data),
    });
    notifications.value = current;
  }

  static void replaceAll(List<Map<String, dynamic>> items) {
    notifications.value = items
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static void markAllAsRead() {
    final current = List<Map<String, dynamic>>.from(notifications.value);
    for (final item in current) {
      item['isRead'] = true;
    }
    notifications.value = current;
  }

  static void markAsRead(int index) {
    if (index < 0 || index >= notifications.value.length) return;
    final current = List<Map<String, dynamic>>.from(notifications.value);
    current[index]['isRead'] = true;
    notifications.value = current;
  }

  static void markAsReadById(String id) {
    final current = List<Map<String, dynamic>>.from(notifications.value);
    var changed = false;

    for (final item in current) {
      if ((item['id']?.toString() ?? '') == id) {
        item['isRead'] = true;
        changed = true;
        break;
      }
    }

    if (changed) {
      notifications.value = current;
    }
  }

  static void removeAt(int index) {
    if (index < 0 || index >= notifications.value.length) return;
    final current = List<Map<String, dynamic>>.from(notifications.value);
    current.removeAt(index);
    notifications.value = current;
  }

  static void removeById(String id) {
    final current = List<Map<String, dynamic>>.from(notifications.value);
    current.removeWhere((item) => (item['id']?.toString() ?? '') == id);
    notifications.value = current;
  }

  static void clearAll() {
    notifications.value = [];
  }

  static void _recomputeUnread() {
    final unread = notifications.value
        .where((item) => item['isRead'] != true)
        .length;
    unreadCount.value = unread;
  }
}
