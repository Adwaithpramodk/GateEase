import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gateeaseapp/login.dart';
import 'package:gateeaseapp/student/student_homepage.dart';
import 'package:gateeaseapp/Mentor/mentor_homepage.dart';
import 'package:gateeaseapp/Security/security_homepage.dart';

// for lid & usertype globals

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat();
    _checkLogin();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _checkLogin() async {
    final prefs = await SharedPreferences.getInstance();

    final savedLid = prefs.getInt('lid');
    final savedType = prefs.getString('usertype');

    await Future.delayed(Duration(milliseconds: 800)); // splash delay

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
        _go(LoginPage());
      }
    } else {
      _go(LoginPage());
    }
  }

  void _go(Widget page) {
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue.shade50, Colors.white, Colors.blue.shade50],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Shimmer effect on "GateEase"
              AnimatedBuilder(
                animation: _shimmerController,
                builder: (context, child) {
                  return ShaderMask(
                    shaderCallback: (bounds) {
                      return LinearGradient(
                        colors: const [
                          Color(0xFF1565C0), // Darker blue
                          Color(0xFF1976D2), // Medium blue
                          Color(0xFF42A5F5), // Light blue
                          Color(0xFF1976D2), // Medium blue
                          Color(0xFF1565C0), // Darker blue
                        ],
                        stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
                        begin: Alignment(
                          -1.0 - _shimmerController.value * 2,
                          0.0,
                        ),
                        end: Alignment(1.0 + _shimmerController.value * 2, 0.0),
                      ).createShader(bounds);
                    },
                    child: const Text(
                      'GateEase',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              // Static subtitle
              const Text(
                'Smart Digital Campus Security',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF1565C0),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
