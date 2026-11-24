import 'dart:async';

import 'package:gateeaseapp/api_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

/// Service class to handle all Firebase Cloud Messaging (FCM) operations
/// Manages device token registration, notification handling, and permissions
class NotificationService {
  static final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance;

  static Future<void>? _listenerSetup;

  static Future<bool> enableMentorNotifications() async {
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional) {
      return false;
    }

    await (_listenerSetup ??= _initializeListeners());
    return true;
  }

  static Future<void> _initializeListeners() async {
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) await _handleNotificationTap(initialMessage);
  }

  static Future<bool> _hasMentorSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('usertype') == 'mentor' && await restoreSession();
    } catch (_) {
      return false;
    }
  }

  /// Get the FCM device token
  static Future<String?> getFCMToken() async {
    try {
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
      }
      return token;
    } catch (e) {
      debugPrint('❌ Error getting FCM token: $e');
      return null;
    }
  }

  /// Handle foreground notifications (when app is open)
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    if (!await _hasMentorSession()) return;
    debugPrint('📬 Foreground notification received');
    
    final context = navigatorKey.currentContext;
    if (context != null && context.mounted && message.notification != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.notification!.title ?? 'New Notification',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(message.notification!.body ?? ''),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'View',
            onPressed: () => _handleNotificationTap(message),
          ),
        ),
      );
    }
  }

  static Future<void> _handleNotificationTap(RemoteMessage message) async {
    if (message.data['type'] == 'pass_request' && await _hasMentorSession()) {
      navigatorKey.currentState?.pushNamed('/pending-passes');
    }
  }

  /// Global navigator key for navigation from notification handler
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  /// Listen to token refresh
  static StreamSubscription<String> listenToTokenRefresh(
    Future<void> Function(String) onTokenRefresh,
  ) => _firebaseMessaging.onTokenRefresh.listen(onTokenRefresh);

  /// Subscribe to a topic (optional - for broadcast notifications)
  static Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      debugPrint('✅ Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('❌ Error subscribing to topic: $e');
    }
  }

  /// Unsubscribe from a topic
  static Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      debugPrint('✅ Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('❌ Error unsubscribing from topic: $e');
    }
  }
}

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('🔔 Background notification received');
}
