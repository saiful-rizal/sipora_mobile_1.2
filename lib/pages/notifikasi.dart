import 'package:flutter/material.dart';
import '../services/app_session_service.dart';
import '../services/notification_state.dart';
import '../services/sipora_api_service.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  static const Color _brand = Color(0xFF1565C0);
  static const Color _title = Color(0xFF1E3A5F);

  @override
  void initState() {
    super.initState();
    NotificationState.initialize();
    _loadNotificationsFromServer();
  }

  Future<void> _loadNotificationsFromServer() async {
    final email = AppSessionService.currentEmail;
    final userId = AppSessionService.currentUserId;
    if (email == null && userId == null) {
      return;
    }

    try {
      final remoteNotifications = await SiporaApiService().fetchNotifications(
        email: email,
        userId: userId,
      );

      if (remoteNotifications.isEmpty) {
        return;
      }

      final currentNotifications = NotificationState.notifications.value;
      final merged = <Map<String, dynamic>>[];
      final seenIds = <String>{};

      for (final item in [...remoteNotifications, ...currentNotifications]) {
        final id = item['id']?.toString() ?? '';
        final stableId = id.isEmpty
            ? '${item['title']}-${item['message']}'
            : id;
        if (seenIds.add(stableId)) {
          merged.add(Map<String, dynamic>.from(item));
        }
      }

      NotificationState.replaceAll(merged);
    } catch (_) {
      // Abaikan kegagalan sinkronisasi; state lokal tetap dipakai.
    }
  }

  void _markAllAsRead() {
    NotificationState.markAllAsRead();
  }

  void _deleteAll() {
    NotificationState.clearAll();
  }

  void _openNotification(Map<String, dynamic> item) {
    final id = item['id']?.toString();
    if (id != null && id.isNotEmpty) {
      NotificationState.markAsReadById(id);
    }

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          title: Text(
            item['title']?.toString() ?? '-',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _title,
            ),
          ),
          content: Text(
            item['message']?.toString() ?? '-',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: Colors.grey.shade700,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup'),
            ),
          ],
        );
      },
    );
  }

  void _showItemActions(int index) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: Color(0xFFB00020),
                ),
                title: const Text('Hapus notifikasi ini'),
                onTap: () {
                  Navigator.pop(context);
                  NotificationState.removeAt(index);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _onTopMenuSelected(String value) {
    if (value == 'mark_all') {
      _markAllAsRead();
      return;
    }
    if (value == 'delete_all') {
      _deleteAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: NotificationState.notifications,
      builder: (context, notifications, _) {
        final unreadCount = notifications
            .where((item) => item['isRead'] != true)
            .length;

        return Scaffold(
          backgroundColor: const Color(0xFFF7F9FC),
          appBar: AppBar(
            leading: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            ),
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: _onTopMenuSelected,
                itemBuilder: (context) => const [
                  PopupMenuItem<String>(
                    value: 'mark_all',
                    child: Text('Tandai telah dibaca semua'),
                  ),
                  PopupMenuItem<String>(
                    value: 'delete_all',
                    child: Text('Hapus semua'),
                  ),
                ],
              ),
            ],
            title: const Text(
              'Notifikasi',
              style: TextStyle(fontWeight: FontWeight.w700, color: _title),
            ),
            centerTitle: true,
            backgroundColor: Colors.white,
            foregroundColor: _title,
            elevation: 0,
          ),
          body: Column(
            children: [
              Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE8EEF6)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.mark_email_unread_outlined,
                      color: _brand,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$unreadCount belum dibaca',
                      style: const TextStyle(
                        color: _title,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Tekan lama untuk hapus',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: notifications.isEmpty
                    ? _buildEmptyState()
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 2, 16, 16),
                        itemCount: notifications.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = notifications[index];
                          final isRead = item['isRead'] == true;
                          return _buildNotificationCard(
                            item: item,
                            isRead: isRead,
                            onTap: () => _openNotification(item),
                            onLongPress: () => _showItemActions(index),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE8EEF6)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none_rounded,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 10),
            const Text(
              'Tidak ada notifikasi',
              style: TextStyle(color: _title, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Notifikasi terbaru akan muncul di sini.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard({
    required Map<String, dynamic> item,
    required bool isRead,
    required VoidCallback onTap,
    required VoidCallback onLongPress,
  }) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isRead ? const Color(0xFFE8EEF6) : const Color(0xFFBFD8F6),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _brand.withOpacity(0.1),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(
                Icons.notifications_active_outlined,
                color: _brand,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item['title']?.toString() ?? '-',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isRead
                                ? FontWeight.w600
                                : FontWeight.w700,
                            color: _title,
                          ),
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: _brand,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item['message']?.toString() ?? '-',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item['time']?.toString() ?? '-',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
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
