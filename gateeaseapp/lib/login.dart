import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:gateeaseapp/Mentor/mentor_homepage.dart';
import 'package:gateeaseapp/Security/security_homepage.dart';
import 'package:gateeaseapp/forgotpassword.dart';
import 'package:gateeaseapp/api_config.dart';
import 'package:gateeaseapp/signup.dart';
import 'package:gateeaseapp/student/student_homepage.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  Future<void> login(BuildContext context) async {
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

        if (!context.mounted) return;

        if (usertype == 'Student') {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => StudentHomePage()),
            (route) => false,
          );
        } else if (usertype == 'mentor') {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => MentorHomePage()),
            (route) => false,
          );
        } else if (usertype == 'security') {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => SecurityHomePage()),
            (route) => false,
          );
        } else if (usertype == 'Rejected') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Admin Rejected Your Request Contact Admin'),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Admin Not Verified.Contact Admin if not resolved'),
            ),
          );
        }
      } else {
        String msg = "Login failed";
        if (response.data is Map && response.data.containsKey('message')) {
          msg = response.data['message'];
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (!context.mounted) return;
      if (e is DioException && e.response != null && e.response!.data is Map) {
        final errorData = e.response!.data;
        String msg = errorData['message'] ?? 'Login failed';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Server error. Try again later')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ===== ICON =====
                const Icon(Icons.lock_outline, size: 60, color: Colors.blue),
                const SizedBox(height: 16),

                // ===== TITLE =====
                const Text(
                  'Welcome Back',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Login to continue to GateEase',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),

                const SizedBox(height: 32),

                // ===== USERNAME =====
                TextFormField(
                  controller: usernameController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ===== PASSWORD =====
                TextFormField(
                  controller: passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // ===== FORGOT PASSWORD =====
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ForgotPasswordPage(),
                        ),
                      );
                    },
                    child: const Text(
                      'Forgot Password?',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // ===== LOGIN BUTTON =====
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      login(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Login',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ===== CREATE ACCOUNT =====
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Don't have an account?",
                      style: TextStyle(fontSize: 13),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SignUp(),
                          ),
                        );
                      },
                      child: const Text(
                        'Create Account',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // ===== FOOTER =====
                const Text(
                  'Smart Digital Campus Security',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
