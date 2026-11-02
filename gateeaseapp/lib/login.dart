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
import 'package:gateeaseapp/privacy_policy_screen.dart';

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

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> login(BuildContext context) async {
    if (usernameController.text.trim().isEmpty ||
        passwordController.text.trim().isEmpty) {
      _snack('Please fill in all fields');
      return;
    }

    setState(() => _isLoading = true);

    final Map<String, dynamic> data = {
      'username': usernameController.text.trim(),
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

        if (usertype == 'Student') {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => StudentHomePage()),
                (route) => false,
          );
        } else if (usertype == 'mentor') {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => MentorHomePage()),
                (route) => false,
          );
        } else if (usertype == 'security') {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => SecurityHomePage()),
                (route) => false,
          );
        } else if (usertype == 'Rejected') {
          _snack('Your account was rejected. Contact admin.');
        } else {
          _snack('Account not verified. Contact admin.');
        }
      } else {
        String msg = 'Login failed';
        if (response.data is Map && response.data.containsKey('message')) {
          msg = response.data['message'].toString();
        }
        _snack(msg);
      }
    } catch (e) {
      if (!context.mounted) return;

      if (e is DioException &&
          e.response != null &&
          e.response!.data is Map) {
        _snack(e.response!.data['message'] ?? 'Login failed');
      } else {
        _snack('Server error. Try again later.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _openPage(Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20, color: AppTheme.textMuted),
      suffixIcon: suffix,
      filled: true,
      fillColor: AppTheme.background,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 18,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: AppTheme.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: AppTheme.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(
          color: AppTheme.primary,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: AppTheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(
          color: AppTheme.error,
          width: 1.5,
        ),
      ),
      labelStyle: const TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 13,
      ),
    );
  }

  Widget _buildBrand() {
    return Column(
      children: [
        const Text(
          'GateEase',
          style: TextStyle(
            color: Colors.white,
            fontSize: 36,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.1,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'SMART CAMPUS SECURITY SYSTEM',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.78),
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.8,
          ),
        ),
      ],
    );
  }


  Widget _buildLoginCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 25, 22, 22),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                const Text(
                  'Welcome Back',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Sign in to continue to your account',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 27),
          const Text(
            'EMAIL ADDRESS',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: usernameController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username, AutofillHints.email],
            decoration: _fieldDecoration(
              label: 'Enter your email address',
              icon: Icons.mail_outline_rounded,
            ),
          ),
          const SizedBox(height: 19),
          const Text(
            'PASSWORD',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: passwordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onFieldSubmitted: (_) {
              if (!_isLoading) login(context);
            },
            decoration: _fieldDecoration(
              label: 'Enter your password',
              icon: Icons.lock_outline_rounded,
              suffix: IconButton(
                tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppTheme.textMuted,
                  size: 19,
                ),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => _openPage(const ForgotPasswordPage()),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Forgot Password?',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _isLoading ? null : () => login(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                disabledBackgroundColor:
                AppTheme.primary.withValues(alpha: 0.35),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.2,
                ),
              )
                  : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Sign In',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: 9),
                  Icon(Icons.arrow_forward_rounded, size: 19),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final screenHeight = constraints.maxHeight;
            final isWide = constraints.maxWidth >= 600;

            return Stack(
              children: [
                // Existing GateEase header gradient and palette are retained.
                Container(
                  height: screenHeight * 0.43,
                  decoration: const BoxDecoration(
                    gradient: AppTheme.headerGradient,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(42),
                      bottomRight: Radius.circular(42),
                    ),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        top: -75,
                        right: -55,
                        child: Container(
                          width: 220,
                          height: 220,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.055),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 115,
                        left: -65,
                        child: Container(
                          width: 145,
                          height: 145,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.accent.withValues(alpha: 0.13),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 38,
                        bottom: 28,
                        child: Icon(
                          Icons.security_rounded,
                          size: 76,
                          color: Colors.white.withValues(alpha: 0.055),
                        ),
                      ),
                    ],
                  ),
                ),
                SafeArea(
                  child: Center(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: isWide ? 430 : 460,
                          minHeight: 0,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildBrand(),
                            const SizedBox(height: 30),
                            _buildLoginCard(),
                            const SizedBox(height: 23),
                            Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                const Text(
                                  "Don't have an account?",
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12.5,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => _openPage(const SignUp()),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppTheme.primary,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 8,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text(
                                    'Create Account',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: () =>
                                  _openPage(const PrivacyPolicyScreen()),

                              label: const Text('Privacy Policy'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.primary,
                                side: const BorderSide(
                                  color: AppTheme.border,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
