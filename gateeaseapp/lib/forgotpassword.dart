import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:gateeaseapp/api_config.dart';

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
        "$baseurl/ForgetPassword",
        data: {"Email": emailController.text.trim()},
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          isOtpSent = true;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("OTP sent to your email")));
      }
    } catch (e) {
      if (!mounted) return;
      String msg = "Network Error";
      if (e is DioException && e.response != null && e.response!.data is Map) {
        msg = e.response!.data['error'] ?? msg;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> resetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    if (otpController.text.length < 6) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Invalid OTP")));
      return;
    }

    setState(() => isLoading = true);

    try {
      final response = await dio.post(
        "$baseurl/ResetPassword",
        data: {
          "email": emailController.text.trim(),
          "otp": otpController.text.trim(),
          "new_password": newPasswordController.text.trim(),
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Password reset successful! Login now."),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      String msg = "Network Error";
      if (e is DioException && e.response != null && e.response!.data is Map) {
        msg = e.response!.data['error'] ?? msg;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFF2F4F8),
        foregroundColor: Colors.black,
        title: const Text('Forgot Password'),
        centerTitle: true,
      ),
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
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_reset, size: 60, color: Colors.blue),
                  const SizedBox(height: 16),

                  Text(
                    isOtpSent ? 'Verify OTP' : 'Reset Password',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  Text(
                    isOtpSent
                        ? 'Enter the 6-digit OTP sent to your email and your new password.'
                        : 'Enter your registered email address.\nWe will send you a 6-digit OTP.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 28),

                  // EMAIL FIELD (Always visible, readonly after OTP sent)
                  TextFormField(
                    controller: emailController,
                    readOnly: isOtpSent,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "Email is required";
                      }
                      if (!value.contains('@')) {
                        return "Enter a valid email";
                      }
                      return null;
                    },
                  ),

                  // OTP & NEW PASSWORD FIELDS (Visible only after OTP sent)
                  if (isOtpSent) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: otpController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: InputDecoration(
                        labelText: 'OTP Code',
                        prefixIcon: const Icon(Icons.pin_outlined),
                        counterText: "",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) =>
                          value!.length != 6 ? "Enter valid 6-digit OTP" : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: newPasswordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) => (value!.length < 6)
                          ? "Min 6 characters required"
                          : null,
                    ),
                  ],

                  const SizedBox(height: 28),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : (isOtpSent ? resetPassword : sendOtp),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              isOtpSent ? 'Set New Password' : 'Send OTP',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),

                  if (isOtpSent)
                    TextButton(
                      onPressed: () => setState(() => isOtpSent = false),
                      child: const Text(
                        "Change Email",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),

                  const SizedBox(height: 10),

                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Back to Login',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
