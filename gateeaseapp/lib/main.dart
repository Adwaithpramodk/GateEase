import 'package:flutter/material.dart';
import 'package:gateeaseapp/splash.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:gateeaseapp/services/notification_service.dart';
import 'package:gateeaseapp/Mentor/pending_pass.dart';
// import 'package:gateeaseapp/Mentor/mentor_homepage.dart';
// import 'package:gateeaseapp/Mentor/student_details.dart';
// import 'package:gateeaseapp/Security/security_homepage.dart';
// import 'package:gateeaseapp/student/student_homepage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // 👈 REQUIRED

  // Initialize Firebase
  try {
    await Firebase.initializeApp();
    debugPrint('✅ Firebase initialized successfully');

    // Set up background message handler
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      // Add navigator key for notification navigation
      navigatorKey: NotificationService.navigatorKey,
      // Add routes for navigation
      routes: {'/pending-passes': (context) => const PendingPassPage()},
      home: SplashScreen(),
    );
  }
}
