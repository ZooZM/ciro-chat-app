import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:injectable/injectable.dart';
import '../di/injection.dart';
import '../network/dio_client.dart';
import '../routing/app_router.dart' show AppRouterName, appRouter, handleInitialNotification;
import '../../features/chat/presentation/bloc/chat_cubit.dart';

@lazySingleton
class PushNotificationService {
  final DioClient _dioClient;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _notificationTapSub;

  PushNotificationService(this._dioClient);

  Future<void> init() async {
    await _initLocalNotifications();

    final messaging = FirebaseMessaging.instance;

    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    final token = await messaging.getToken();
    if (token != null) await _registerToken(token);

    _tokenRefreshSub = messaging.onTokenRefresh.listen(_registerToken);
    _foregroundSub = FirebaseMessaging.onMessage.listen(handleForegroundMessage);
    _notificationTapSub = FirebaseMessaging.onMessageOpenedApp.listen(handleNotificationTap);

    await handleInitialNotification();
  }

  Future<void> dispose() async {
    await _tokenRefreshSub?.cancel();
    await _foregroundSub?.cancel();
    await _notificationTapSub?.cancel();
    _tokenRefreshSub = null;
    _foregroundSub = null;
    _notificationTapSub = null;

    try {
      await _dioClient.dio.delete('/auth/device-token');
    } on DioException catch (e) {
      debugPrint('[Push] Token unregister failed: $e');
    }

    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (e) {
      debugPrint('[Push] FCM token delete failed: $e');
    }

    await _localNotifications.cancelAll();
  }

  Future<void> _initLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        final payload = details.payload;
        if (payload != null && payload.isNotEmpty) {
          _navigateToRoom(payload).ignore();
        }
      },
    );

    if (Platform.isAndroid) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              'ciro_chat_messages',
              'Messages',
              description: 'New chat messages',
              importance: Importance.high,
            ),
          );
    }
  }

  Future<void> _registerToken(String token) async {
    try {
      final platform = Platform.isIOS ? 'apns' : 'fcm';
      await _dioClient.dio.post(
        '/auth/device-token',
        data: {'token': token, 'platform': platform},
      );
      debugPrint('[Push] Token registered ($platform)');
    } on DioException catch (e) {
      debugPrint('[Push] Token registration failed: $e');
    }
  }

  void handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    final roomId = message.data['roomId'] as String?;
    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'ciro_chat_messages',
          'Messages',
          channelDescription: 'New chat messages',
          importance: Importance.high,
          priority: Priority.high,
          groupKey: roomId,
        ),
        iOS: const DarwinNotificationDetails(threadIdentifier: 'messages'),
      ),
      payload: roomId,
    );
  }

  void handleNotificationTap(RemoteMessage message) {
    final roomId = message.data['roomId'] as String?;
    if (roomId != null) _navigateToRoom(roomId).ignore();
  }

  Future<void> _navigateToRoom(String roomId) async {
    final chatCubit = getIt<ChatCubit>();
    final room = await chatCubit.getRoomById(roomId);
    if (room != null) {
      appRouter.push(AppRouterName.chatRoom, extra: room);
    } else {
      appRouter.go(AppRouterName.home);
    }
  }
}
