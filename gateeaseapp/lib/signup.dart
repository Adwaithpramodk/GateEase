import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:gateeaseapp/api_config.dart';
import 'package:gateeaseapp/theme/app_theme.dart';

class SignUp extends StatefulWidget {
  const SignUp({super.key});

  @override
  State<SignUp> createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> {
  TextEditingController nameController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController admissionController = TextEditingController();
  TextEditingController phoneController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  TextEditingController confirmpasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  List<Map<String, dynamic>> classes = [];
  int? selectedClassId;
  final _formKey = GlobalKey<FormState>();

  Future<void> register(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    Map<String, dynamic> data = {
      'name': nameController.text.trim(),
      'email': emailController.text.trim(),
      'classs': selectedClassId,
      'admn_no': admissionController.text.trim(),
      'phone': phoneController.text.trim(),
      'password': passwordController.text.trim(),
      'confirmpassword': confirmpasswordController.text.trim(),
    };
    try {
      final response = await dio.post('$baseurl/UserReg/', data: data);
      if ((response.statusCode == 200 || response.statusCode == 201) &&
          context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Registration successful! Wait for admin verification.',
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (!context.mounted) return;
      String msg = 'Registration failed';
      if (e is DioException && e.response != null && e.response!.data is Map) {
        msg = e.response!.data['message'] ?? msg;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> getClasses() async {
    try {
      final response = await dio.get('$baseurl/UserReg/');
      if (response.statusCode == 200) {
        setState(() {
          classes = List<Map<String, dynamic>>.from(response.data);
        });
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  @override
  void initState() {
    super.initState();
    getClasses();
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
              height: 200,
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
                  // Top bar
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Expanded(
                          child: Text(
                            'Create Account',
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
                  const SizedBox(height: 4),
                  const Text(
                    'Join GateEase',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Fill in your details to get started',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 28),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Form(
                        key: _formKey,
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: AppTheme.elevatedCardDecoration,
                          child: Column(
                            children: [
                              _field(
                                controller: nameController,
                                label: 'Full Name',
                                icon: Icons.person_rounded,
                                validator: (v) =>
                                    v!.isEmpty ? 'Name is required' : null,
                              ),
                              const SizedBox(height: 14),
                              _field(
                                controller: emailController,
                                label: 'Email Address',
                                icon: Icons.email_rounded,
                                keyboard: TextInputType.emailAddress,
                                validator: (v) =>
                                    !RegExp(
                                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                                    ).hasMatch(v ?? '')
                                    ? 'Enter a valid email'
                                    : null,
                              ),
                              const SizedBox(height: 14),
                              DropdownButtonFormField<int>(
                                initialValue: selectedClassId,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Batch / Class',
                                  prefixIcon: Icon(Icons.class_rounded),
                                ),
                                items: classes.isEmpty
                                    ? [
                                        const DropdownMenuItem(
                                          value: null,
                                          child: Text('Loading classes...'),
                                        ),
                                      ]
                                    : classes
                                          .map(
                                            (cls) => DropdownMenuItem<int>(
                                              value: cls['id'],
                                              child: Text(
                                                cls['class_name'].toString(),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          )
                                          .toList(),
                                validator: (v) =>
                                    v == null ? 'Select your batch' : null,
                                onChanged: (v) =>
                                    setState(() => selectedClassId = v),
                              ),
                              const SizedBox(height: 14),
                              _field(
                                controller: admissionController,
                                label: 'Admission Number',
                                icon: Icons.badge_rounded,
                                validator: (v) =>
                                    v!.isEmpty ? 'Required' : null,
                              ),
                              const SizedBox(height: 14),
                              _field(
                                controller: phoneController,
                                label: 'Phone Number',
                                icon: Icons.phone_rounded,
                                keyboard: TextInputType.phone,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(10),
                                ],
                                validator: (v) => (v?.length ?? 0) != 10
                                    ? 'Enter 10-digit phone'
                                    : null,
                              ),
                              const SizedBox(height: 14),
                              _field(
                                controller: passwordController,
                                label: 'Password',
                                icon: Icons.lock_rounded,
                                obscure: _obscurePassword,
                                suffix: IconButton(
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
                                validator: (v) => (v?.length ?? 0) < 6
                                    ? 'Min 6 characters'
                                    : null,
                              ),
                              const SizedBox(height: 14),
                              _field(
                                controller: confirmpasswordController,
                                label: 'Confirm Password',
                                icon: Icons.lock_clock_rounded,
                                obscure: _obscureConfirmPassword,
                                suffix: IconButton(
                                  icon: Icon(
                                    _obscureConfirmPassword
                                        ? Icons.visibility_off_rounded
                                        : Icons.visibility_rounded,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(
                                    () => _obscureConfirmPassword =
                                        !_obscureConfirmPassword,
                                  ),
                                ),
                                validator: (v) => v != passwordController.text
                                    ? 'Passwords do not match'
                                    : null,
                              ),
                              const SizedBox(height: 28),
                              ElevatedButton(
                                onPressed: _isLoading
                                    ? null
                                    : () => register(context),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : const Text('Create Account'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Already have an account? ',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(padding: EdgeInsets.zero),
                          child: const Text('Sign In'),
                        ),
                      ],
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

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    TextInputType keyboard = TextInputType.text,
    Widget? suffix,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboard,
      inputFormatters: inputFormatters,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: suffix,
      ),
    );
  }
}
