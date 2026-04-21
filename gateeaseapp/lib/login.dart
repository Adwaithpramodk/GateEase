import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:gateeaseapp/Mentor/mentor_homepage.dart';
import 'package:gateeaseapp/Security/security_homepage.dart';
import 'package:gateeaseapp/forgotpassword.dart';
import 'package:gateeaseapp/api_config.dart';
import 'package:gateeaseapp/signup.dart';
import 'package:gateeaseapp/student/student_homepage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gateeaseapp/theme/app_theme.dart';

int? lid;
String? usertype;

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  Future<void> login(BuildContext context) async {
    if (usernameController.text.trim().isEmpty ||
        passwordController.text.trim().isEmpty) {
      _snack('Please fill in all fields');
      return;
    }
    setState(() => _isLoading = true);
    Map<String, dynamic> data = {
      'username': usernameController.text,
      'password': passwordController.text,
    };
    try {
      final response = await dio.post('$baseurl/LoginpageAPI', data: data);
      if (!context.mounted) return;
      if (response.statusCode == 200 || response.statusCode == 201) {
        lid = response.data['login_id'];
        usertype = response.data['usertype'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('lid', lid!);
        await prefs.setString('usertype', usertype!);
        final accessToken = response.data['access']?.toString() ?? '';
        final refreshToken = response.data['refresh']?.toString() ?? '';
        await prefs.setString('access_token', accessToken);
        await prefs.setString('refresh_token', refreshToken);
        setupDioInterceptor();
        if (!context.mounted) return;
        final lowerUserType = usertype?.toLowerCase();

        if (lowerUserType == 'student') {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => StudentHomePage()),
            (route) => false,
          );
        } else if (lowerUserType == 'mentor') {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => MentorHomePage()),
            (route) => false,
          );
        } else if (lowerUserType == 'security') {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => SecurityHomePage()),
            (route) => false,
          );
        } else if (lowerUserType == 'rejected') {
          _snack('Your account was rejected. Contact admin.');
        } else if (lowerUserType == 'admin') {
          _snack('Admin login restricted to web portal.');
        } else {
          _snack('Account status: ${usertype ?? 'Unknown'}. Contact admin.');
        }
      } else {
        String msg = 'Login failed';
        if (response.data is Map) {
          msg = response.data['message'] ?? response.data['detail'] ?? msg;
        }
        _snack(msg);
      }
    } catch (e) {
      if (!context.mounted) return;
      if (e is DioException && e.response != null && e.response!.data is Map) {
        final data = e.response!.data;
        _snack(data['message'] ?? data['detail'] ?? 'Login failed');
      } else {
        _snack('Server error. Try again later.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: Stack(
          children: [
            // Decorative header blob
            Container(
              height: MediaQuery.of(context).size.height * 0.45,
              decoration: const BoxDecoration(
                gradient: AppTheme.headerGradient,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(48),
                  bottomRight: Radius.circular(48),
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -40,
                    top: -20,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                  ),
                  Positioned(
                    left: -20,
                    bottom: 40,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.accent.withValues(alpha: 0.15),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 36),

                    // Brand
                    const SizedBox(height: 12),
                    const Text(
                      'GateEase',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'Smart Campus Security System',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Card
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: AppTheme.elevatedCardDecoration,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Welcome back',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Sign in to your account',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 28),

                          // Username
                          TextFormField(
                            controller: usernameController,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.person_outline_rounded),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Password
                          TextFormField(
                            controller: passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(
                                Icons.lock_outline_rounded,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                  size: 20,
                                ),
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Forgot password
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ForgotPasswordPage(),
                                ),
                              ),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 36),
                              ),
                              child: const Text('Forgot Password?'),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Sign In button
                          Container(
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.accent.withValues(alpha: 0.3),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                              borderRadius: BorderRadius.circular(50),
                            ),
                            child: ElevatedButton(
                              onPressed: _isLoading
                                  ? null
                                  : () => login(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(50),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : const Text('Sign In'),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Sign Up link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Don't have an account? ",
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SignUp()),
                          ),
                          style: TextButton.styleFrom(padding: EdgeInsets.zero),
                          child: const Text('Sign Up'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
