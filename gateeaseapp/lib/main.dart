import 'package:flutter/material.dart';
import 'package:gateeaseapp/splash.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:gateeaseapp/services/notification_service.dart';
import 'package:gateeaseapp/api_config.dart';
import 'package:gateeaseapp/Mentor/pending_pass.dart';
import 'package:gateeaseapp/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set up JWT interceptor so all API calls carry the auth token
  setupDioInterceptor();

  // Initialize Firebase
  try {
    await Firebase.initializeApp();
    debugPrint('✅ Firebase initialized successfully');
    
    // Initialize Notification Service
    await NotificationService.initialize();
    
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint('❌ Firebase initialization error: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GateEase',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      // Add navigator key for notification navigation
      navigatorKey: NotificationService.navigatorKey,
      // Add routes for navigation
      routes: {'/pending-passes': (context) => const PendingPassPage()},
      home: SplashScreen(),
    );
  }
}
