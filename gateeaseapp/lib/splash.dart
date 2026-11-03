import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gateeaseapp/login.dart';
import 'package:gateeaseapp/student/student_homepage.dart';
import 'package:gateeaseapp/Mentor/mentor_homepage.dart';
import 'package:gateeaseapp/Security/security_homepage.dart';
import 'package:gateeaseapp/theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _scaleAnim = Tween<double>(
      begin: 0.88,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
      ),
    );

    _controller.forward();
    _checkLogin();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLid = prefs.getInt('lid');
    final savedType = prefs.getString('usertype');

    await Future.delayed(const Duration(milliseconds: 1200));

    if (!mounted) return;

    if (savedLid != null && savedType != null) {
      lid = savedLid;
      usertype = savedType;

      if (savedType == 'Student') {
        _go(const StudentHomePage());
      } else if (savedType == 'mentor') {
        _go(const MentorHomePage());
      } else if (savedType == 'security') {
        _go(const SecurityHomePage());
      } else {
        _go(const LoginPage());
      }
    } else {
      _go(const LoginPage());
    }
  }

  void _go(Widget page) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: AppTheme.headerGradient,
          ),
          child: Stack(
            children: [
              // Subtle decorative shapes; existing purple theme is retained.
              Positioned(
                top: -75,
                right: -65,
                child: Container(
                  width: 230,
                  height: 230,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.055),
                  ),
                ),
              ),
              Positioned(
                bottom: 105,
                left: -85,
                child: Container(
                  width: 190,
                  height: 190,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.accent.withValues(alpha: 0.13),
                  ),
                ),
              ),
              Center(
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: ScaleTransition(
                    scale: _scaleAnim,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // GateEase wordmark is the logo; no icon above it.
                        const Text(
                          'GateEase',
                          style: TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -1.2,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Container(
                          width: 76,
                          height: 3,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        const SizedBox(height: 13),
                        Text(
                          'SMART CAMPUS SECURITY SYSTEM',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.72),
                            letterSpacing: 2.6,
                          ),
                        ),
                        const SizedBox(height: 64),
                        SizedBox(
                          width: 27,
                          height: 27,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.3,
                            color: Colors.white.withValues(alpha: 0.65),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
