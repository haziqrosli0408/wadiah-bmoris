import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  static Future<void> initialize() async {
    try {
      final messaging = FirebaseMessaging.instance;

      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      await messaging.subscribeToTopic('announcements');

      final token = await messaging.getToken();
      developer.log('FCM token: ${token ?? "null"}');

      FirebaseMessaging.onMessage.listen((message) {
        developer.log('FCM foreground message: ${message.notification?.title ?? ""}');
      });

      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        developer.log('FCM opened message: ${message.notification?.title ?? ""}');
      });
    } on MissingPluginException catch (e) {
      developer.log('FCM plugin unavailable in this build: $e');
    } catch (e) {
      developer.log('FCM init skipped: $e');
    }
  }
}
