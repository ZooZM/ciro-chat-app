import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:injectable/injectable.dart';
import '../di/injection.dart';
import '../network/dio_client.dart';
import '../routing/app_router.dart'
    show AppRouterName, appRouter, handleInitialNotification, navigateToStatusReaction;
import '../services/callkit_service.dart';
import '../../features/chat/presentation/bloc/chat_cubit.dart';

/// FCM handler for terminated/background `call`-type messages. Runs in a
/// SEPARATE isolate (U1 — FR-VoIP-12), so it MUST bootstrap Firebase before
/// touching any plugin. Shows the native CallKit UI directly (no DI).
@pragma('vm:entry-point')
Future<void> firebaseCallkitBackgroundHandler(RemoteMessage message) async {
  if (message.data['type'] != 'call') return;
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Already initialized in this isolate — ignore.
  }
  await showCallkitIncomingFromData(Map<String, dynamic>.from(message.data));
}

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

    // FR-VoIP-12: wake the native call UI when a call push arrives while the app
    // is backgrounded or terminated (separate isolate, U1).
    FirebaseMessaging.onBackgroundMessage(firebaseCallkitBackgroundHandler);

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
        if (payload == null || payload.isEmpty) return;
        if (payload.startsWith('status:')) {
          navigateToStatusReaction(payload.substring('status:'.length)).ignore();
        } else {
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
    final type = message.data['type'] as String?;

    // Incoming 1:1 call push — show the native UI. Idempotent on callId, so it
    // is safe even when the socket path also fires (FR-VoIP-01, E2).
    if (type == 'call') {
      final callId = message.data['callId'] as String?;
      if (callId != null && callId.isNotEmpty) {
        getIt<CallKitService>().showIncoming(
          callId: callId,
          callerName: message.data['callerName'] as String? ?? 'Unknown',
          callerAvatarUrl: message.data['callerAvatarUrl'] as String?,
          isVideo: message.data['isVideo']?.toString() == 'true',
        );
      }
      return;
    }

    final notification = message.notification;
    if (notification == null) return;

    final roomId = message.data['roomId'] as String?;
    final statusId = message.data['statusId'] as String?;
    final payload = (type == 'statusReaction' && statusId != null)
        ? 'status:$statusId'
        : roomId;

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
          icon: '@mipmap/ic_launcher',
          color: const Color(0xFF4CAF50), // Green brand color
        ),
        iOS: const DarwinNotificationDetails(threadIdentifier: 'messages'),
      ),
      payload: payload,
    );
  }

  void handleNotificationTap(RemoteMessage message) {
    final type = message.data['type'] as String?;
    if (type == 'statusReaction') {
      final statusId = message.data['statusId'] as String?;
      if (statusId != null) navigateToStatusReaction(statusId).ignore();
      return;
    }
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
