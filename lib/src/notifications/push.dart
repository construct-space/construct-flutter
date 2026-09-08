// FCM glue. Two responsibilities:
//   1. Wait for permission + fetch the device token, then hand it to
//      delivery-api via NotificationsClient.registerDevice.
//   2. Hook foreground messages into flutter_local_notifications so the
//      OS shows a notification banner even while the app is open
//      (FCM only auto-displays when the app is backgrounded/terminated).

import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'client.dart';

class PushService {
  PushService(this._notifications);

  final NotificationsClient _notifications;
  final _local = FlutterLocalNotificationsPlugin();

  static const _channel = AndroidNotificationChannel(
    'construct_default',
    'Construct',
    description: 'Notifications from Construct',
    importance: Importance.high,
  );

  Future<void> init() async {
    // 1. Local notification channel for foreground display on Android.
    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // 2. iOS permission prompt. On Android 13+ the runtime permission for
    // POST_NOTIFICATIONS is also requested via this call.
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true, badge: true, sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return;
    }

    // 3. Foreground display — FCM lets the OS render automatically only when
    // the app is backgrounded; while open we have to render via the local
    // plugin or the user sees nothing.
    FirebaseMessaging.onMessage.listen((msg) {
      final n = msg.notification;
      if (n == null) return;
      _local.show(
        id: msg.hashCode,
        title: n.title,
        body: n.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        payload: msg.data['link'] as String?,
      );
    });

    // 4. Token registration. On iOS, FirebaseMessaging.getToken() throws
    // apns-token-not-set if called before APNs has issued the device
    // token (which happens after requestPermission, asynchronously). We
    // poll briefly for the APNs token to land — usually ~1s on a real
    // device, longer on simulators (where it may never come, since
    // APNs requires a real device). onTokenRefresh covers later
    // rotations regardless.
    final fcm = FirebaseMessaging.instance;
    if (Platform.isIOS) {
      for (var i = 0; i < 10; i++) {
        try {
          if (await fcm.getAPNSToken() != null) break;
        } catch (_) { /* keep polling */ }
        await Future.delayed(const Duration(seconds: 1));
      }
    }
    try {
      final token = await fcm.getToken();
      if (token != null) await _registerWithBackend(token);
    } catch (e) {
      // On the simulator (or if push permission was denied) APNs never
      // issues a token. onTokenRefresh below covers the case where the
      // user re-grants permission later or moves to a real device.
      debugPrint('[push] initial getToken failed: $e');
    }
    fcm.onTokenRefresh.listen(_registerWithBackend);
  }

  Future<void> _registerWithBackend(String token) async {
    try {
      await _notifications.registerDevice(
        platform: Platform.isIOS ? 'ios' : 'android',
        token: token,
      );
    } catch (e) {
      // Non-fatal — user is offline / 401 / etc. Token is durable
      // device-side; we'll retry on next app launch via init().
      debugPrint('[push] registerDevice failed: $e');
    }
  }
}
