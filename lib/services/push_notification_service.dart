import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'app_session_service.dart';
import 'notification_state.dart';
import 'sipora_api_service.dart';

class PushNotificationService {
  PushNotificationService._();

  static final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'sipora_push_channel',
    'SIPORA Push Notifications',
    description: 'Notifikasi push dari SIPORA',
    importance: Importance.high,
  );

  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await _initializeLocalNotifications();

    final messaging = FirebaseMessaging.instance;

    await messaging.requestPermission(alert: true, badge: true, sound: true);
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );

    FirebaseMessaging.onMessage.listen((message) {
      _handleRemoteMessage(message, showLocalNotification: true);
    });
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleRemoteMessage(message, showLocalNotification: false);
    });

    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleRemoteMessage(initialMessage, showLocalNotification: false);
    }

    final token = await messaging.getToken();
    debugPrint('FCM token: $token');

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      debugPrint('FCM token refreshed: $newToken');
      await _registerToken(newToken);
    });
  }

  static Future<void> handleBackgroundMessage(RemoteMessage message) async {
    await _initializeLocalNotifications();
    await _showSystemNotification(message);
  }

  static Future<void> registerCurrentDeviceToken() async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) {
      return;
    }

    await _registerToken(token);
  }

  static Future<void> clearCurrentDeviceToken() async {
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (error) {
      debugPrint('Gagal menghapus token FCM: $error');
    }
  }

  static Future<void> _registerToken(String token) async {
    final userEmail = AppSessionService.currentEmail;
    final userId = AppSessionService.currentUserId;
    if (userEmail == null && userId == null) {
      return;
    }

    try {
      await SiporaApiService().registerPushToken(
        token: token,
        email: userEmail,
        userId: userId,
      );
    } catch (error) {
      debugPrint('Gagal register token FCM: $error');
    }
  }

  static Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iOSSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iOSSettings,
    );

    await _localNotificationsPlugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        if (response.payload == null || response.payload!.isEmpty) {
          return;
        }

        final decoded = jsonDecode(response.payload!);
        if (decoded is Map<String, dynamic>) {
          _handleNotificationPayload(decoded);
        }
      },
    );

    final androidPlugin = _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(_channel);
    await androidPlugin?.requestNotificationsPermission();
  }

  static Future<void> _handleRemoteMessage(
    RemoteMessage message, {
    required bool showLocalNotification,
  }) async {
    final notification = message.notification;
    final title =
        notification?.title ??
        message.data['title']?.toString() ??
        'Notifikasi Baru';
    final body =
        notification?.body ??
        message.data['message']?.toString() ??
        message.data['body']?.toString() ??
        'Anda menerima notifikasi dari SIPORA.';

    _handleNotificationPayload({
      'id':
          message.messageId ?? DateTime.now().microsecondsSinceEpoch.toString(),
      'title': title,
      'message': body,
      'time': 'Baru saja',
      'data': message.data,
    });

    if (showLocalNotification) {
      await _showSystemNotification(message, title: title, body: body);
    }
  }

  static void _handleNotificationPayload(Map<String, dynamic> payload) {
    final title = payload['title']?.toString() ?? 'Notifikasi Baru';
    final message =
        payload['message']?.toString() ?? 'Anda menerima notifikasi.';
    final id = payload['id']?.toString();
    final time = payload['time']?.toString();
    final data = payload['data'] is Map
        ? Map<String, dynamic>.from(payload['data'] as Map)
        : <String, dynamic>{};

    NotificationState.addNotification(
      id: id,
      title: title,
      message: message,
      time: time,
      data: data,
    );
  }

  static Future<void> _showSystemNotification(
    RemoteMessage message, {
    String? title,
    String? body,
  }) async {
    final notificationTitle =
        title ?? message.notification?.title ?? 'Notifikasi Baru';
    final notificationBody =
        body ?? message.notification?.body ?? 'Anda menerima notifikasi.';

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channel.id,
        _channel.name,
        channelDescription: _channel.description,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _localNotificationsPlugin.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: notificationTitle,
      body: notificationBody,
      notificationDetails: details,
      payload: jsonEncode(message.data),
    );
  }
}
