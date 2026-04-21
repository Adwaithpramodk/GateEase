import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:gateeaseapp/api_config.dart';
import 'package:gateeaseapp/theme/app_theme.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController otpController = TextEditingController();
  final TextEditingController newPasswordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _obscureNew = true;
  bool isOtpSent = false;
  bool isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    otpController.dispose();
    newPasswordController.dispose();
    super.dispose();
  }

  Future<void> sendOtp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => isLoading = true);
    try {
      final response = await dio.post(
        '$baseurl/ForgetPassword',
        data: {'Email': emailController.text.trim()},
      );
      if (!mounted) return;
      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() => isOtpSent = true);
        _snack('OTP sent to your email ✓', success: true);
      }
    } catch (e) {
      if (!mounted) return;
      String msg = 'Network Error';
      if (e is DioException && e.response != null && e.response!.data is Map) {
        msg = e.response!.data['error'] ?? msg;
      }
      _snack(msg);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> resetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => isLoading = true);
    try {
      final response = await dio.post(
        '$baseurl/ResetPassword',
        data: {
          'email': emailController.text.trim(),
          'otp': otpController.text.trim(),
          'new_password': newPasswordController.text.trim(),
        },
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        _snack('Password reset! Please sign in.', success: true);
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      String msg = 'Network Error';
      if (e is DioException && e.response != null && e.response!.data is Map) {
        msg = e.response!.data['error'] ?? msg;
      }
      _snack(msg);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _snack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? AppTheme.success : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: Stack(
          children: [
            Container(
              height: 220,
              decoration: const BoxDecoration(
                gradient: AppTheme.headerGradient,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  // Header bar
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded,
                              color: Colors.white, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Expanded(
                          child: Text(
                            'Reset Password',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 44),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            const SizedBox(height: 8),
                            // Icon
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  width: 2,
                                ),
                              ),
                              child: const Icon(Icons.lock_reset_rounded,
                                  size: 36, color: Colors.white),
                            ),
                            const SizedBox(height: 48),
                            Container(
                              padding: const EdgeInsets.all(28),
                              decoration: AppTheme.elevatedCardDecoration,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isOtpSent ? 'Verify & Reset' : 'Forgot Password?',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.textPrimary,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    isOtpSent
                                        ? 'Enter the 6-digit OTP and your new password.'
                                        : 'Enter your registered email to receive an OTP.',
                                    style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 13,
                                        height: 1.4),
                                  ),
                                  const SizedBox(height: 24),

                                  // Email field
                                  TextFormField(
                                    controller: emailController,
                                    readOnly: isOtpSent,
                                    keyboardType: TextInputType.emailAddress,
                                    decoration: InputDecoration(
                                      labelText: 'Email Address',
                                      prefixIcon: const Icon(Icons.email_outlined),
                                      filled: true,
                                      fillColor: isOtpSent
                                          ? AppTheme.border
                                          : AppTheme.surfaceAlt,
                                    ),
                                    validator: (v) {
                                      if (v == null || v.isEmpty) {
                                        return 'Email is required';
                                      }
                                      if (!v.contains('@')) {
                                        return 'Enter a valid email';
                                      }
                                      return null;
                                    },
                                  ),

                                  if (isOtpSent) ...[
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: otpController,
                                      keyboardType: TextInputType.number,
                                      maxLength: 6,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly
                                      ],
                                      decoration: const InputDecoration(
                                        labelText: 'OTP Code',
                                        prefixIcon: Icon(Icons.pin_outlined),
                                        counterText: '',
                                      ),
                                      validator: (v) => (v?.length ?? 0) != 6
                                          ? 'Enter valid 6-digit OTP'
                                          : null,
                                    ),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: newPasswordController,
                                      obscureText: _obscureNew,
                                      decoration: InputDecoration(
                                        labelText: 'New Password',
                                        prefixIcon: const Icon(Icons.lock_outline),
                                        suffixIcon: IconButton(
                                          icon: Icon(_obscureNew
                                              ? Icons.visibility_off_rounded
                                              : Icons.visibility_rounded,
                                              size: 20),
                                          onPressed: () => setState(
                                              () => _obscureNew = !_obscureNew),
                                        ),
                                      ),
                                      validator: (v) => (v?.length ?? 0) < 6
                                          ? 'Min 6 characters'
                                          : null,
                                    ),
                                  ],

                                  const SizedBox(height: 28),

                                  ElevatedButton(
                                    onPressed: isLoading
                                        ? null
                                        : (isOtpSent ? resetPassword : sendOtp),
                                    child: isLoading
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2.5))
                                        : Text(isOtpSent
                                            ? 'Set New Password'
                                            : 'Send OTP'),
                                  ),

                                  if (isOtpSent) ...[
                                    const SizedBox(height: 8),
                                    Center(
                                      child: TextButton(
                                        onPressed: () =>
                                            setState(() => isOtpSent = false),
                                        child: const Text('← Change Email'),
                                      ),
                                    ),
                                  ],
                                ],
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
          ],
        ),
      ),
    );
  }
}
