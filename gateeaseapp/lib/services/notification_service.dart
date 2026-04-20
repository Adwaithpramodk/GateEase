import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

/// Service class to handle all Firebase Cloud Messaging (FCM) operations
/// Manages device token registration, notification handling, and permissions
class NotificationService {
  static final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance;

  /// Initialize notification service and request permissions
  static Future<void> initialize() async {
    try {
      // Request notification permissions (iOS)
      NotificationSettings settings = await _firebaseMessaging
          .requestPermission(
            alert: true,
            badge: true,
            sound: true,
            provisional: false,
          );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('✅ User granted notification permission');
      } else if (settings.authorizationStatus ==
          AuthorizationStatus.provisional) {
        debugPrint('⚠️ User granted provisional notification permission');
      } else {
        debugPrint(
          '❌ User declined or has not accepted notification permission',
        );
      }

      // Get the FCM token (for device registration)
      await getFCMToken();

      // Listen to foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle notification taps when app is in background/terminated
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Check if app was opened from a terminated state
      RemoteMessage? initialMessage = await FirebaseMessaging.instance
          .getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }
    } catch (e) {
      debugPrint('❌ Error initializing notifications: $e');
    }
  }

  /// Get the FCM device token
  static Future<String?> getFCMToken() async {
    try {
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        debugPrint('✅ FCM Token retrieved successfully');
      }
      return token;
    } catch (e) {
      debugPrint('❌ Error getting FCM token: $e');
      return null;
    }
  }

  /// Handle foreground notifications (when app is open)
  static void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('📬 Foreground notification received');
    debugPrint('Title: ${message.notification?.title}');
    debugPrint('Body: ${message.notification?.body}');
    debugPrint('Data: ${message.data}');

    // You can show a local notification or in-app notification here
    // For now, we're just logging it
  }

  /// Handle notification tap (when user taps notification)
  static void _handleNotificationTap(RemoteMessage message) {
    debugPrint('👆 Notification tapped');
    debugPrint('Data: ${message.data}');

    // Navigate to pending passes screen based on notification type
    try {
      String? notificationType = message.data['type'];

      if (notificationType == 'pass_request') {
        // Navigate to pending passes page
        navigatorKey.currentState?.pushNamed('/pending-passes');
        debugPrint('✅ Navigating to pending passes page');
      }
    } catch (e) {
      debugPrint('❌ Error handling notification tap: $e');
    }
  }

  /// Global navigator key for navigation from notification handler
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  /// Listen to token refresh
  static void listenToTokenRefresh(Function(String) onTokenRefresh) {
    _firebaseMessaging.onTokenRefresh.listen((newToken) {
      debugPrint('🔄 FCM Token refreshed');
      onTokenRefresh(newToken);
    });
  }

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
  debugPrint('Title: ${message.notification?.title}');
  debugPrint('Body: ${message.notification?.body}');
  debugPrint('Data: ${message.data}');
}
