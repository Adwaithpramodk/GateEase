import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:gateeaseapp/api_config.dart';
import 'package:gateeaseapp/login.dart';

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

  List<Map<String, dynamic>> classes = [];
  int? selectedClassId;

  final _formKey = GlobalKey<FormState>();

  Future<void> register(BuildContext context) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Map<String, dynamic> data = {
      'name': nameController.text,
      'email': emailController.text,
      'classs': selectedClassId,
      'admn_no': admissionController.text,
      'phone': phoneController.text,
      'password': passwordController.text,
      'confirmpassword': confirmpasswordController.text,
    };

    debugPrint(data.toString());

    try {
      final response = await dio.post('$baseurl/UserReg', data: data);
      if ((response.statusCode == 200 || response.statusCode == 201) &&
          context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Wait For Admin Verification")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (!context.mounted) return;

      String msg = "Registration failed";
      if (e is DioException && e.response != null && e.response!.data is Map) {
        msg = e.response!.data['message'] ?? msg;
      }

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> getClasses() async {
    try {
      final response = await dio.get('$baseurl/UserReg');
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
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F4F8),
        elevation: 0,
        foregroundColor: Colors.black,
        title: const Text('Create Account'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
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
                children: [
                  const Icon(
                    Icons.person_add_alt_1,
                    size: 60,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Student Registration',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Fill the details to create your account',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 28),

                  _inputField(
                    label: 'Full Name',
                    icon: Icons.person_outline,
                    controller: nameController,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),

                  _inputField(
                    label: 'Email Address',
                    icon: Icons.email_outlined,
                    keyboard: TextInputType.emailAddress,
                    controller: emailController,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!RegExp(
                        r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                      ).hasMatch(value)) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),

                  DropdownButtonFormField<int>(
                    initialValue: selectedClassId,
                    isExpanded: true, // Make dropdown take full width
                    decoration: _inputDecoration(
                      label: 'Batch',
                      icon: Icons.class_outlined,
                    ),
                    // Custom selected item builder to show full text
                    selectedItemBuilder: (BuildContext context) {
                      return classes.map<Widget>((cls) {
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            cls['class_name'].toString(),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        );
                      }).toList();
                    },
                    items: classes.map((cls) {
                      return DropdownMenuItem<int>(
                        value: cls['id'],
                        child: Container(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width - 80,
                          ),
                          child: Text(
                            cls['class_name'].toString(),
                            overflow: TextOverflow.visible,
                            softWrap: true,
                            maxLines: 3,
                            style: const TextStyle(fontSize: 15),
                          ),
                        ),
                      );
                    }).toList(),
                    validator: (value) {
                      if (value == null) {
                        return 'Please select your batch/class';
                      }
                      return null;
                    },
                    onChanged: (value) {
                      setState(() {
                        selectedClassId = value;
                      });
                    },
                    // Customize dropdown menu to handle long text
                    menuMaxHeight: 300,
                    dropdownColor: Colors.white,
                  ),

                  const SizedBox(height: 18),

                  _inputField(
                    label: 'Admission No',
                    icon: Icons.confirmation_number_outlined,
                    controller: admissionController,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter admission number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),

                  _inputField(
                    label: 'Phone Number',
                    icon: Icons.phone_outlined,
                    keyboard: TextInputType.phone,
                    controller: phoneController,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter phone number';
                      }
                      if (value.length != 10) {
                        return 'Phone number must be 10 digits';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),

                  _inputField(
                    label: 'Password',
                    icon: Icons.lock_outline,
                    obscure: _obscurePassword,
                    controller: passwordController,
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
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a password';
                      }
                      if (value.length < 8) {
                        return 'Password must be at least 8 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),

                  _inputField(
                    label: 'Confirm Password',
                    icon: Icons.lock_outline,
                    obscure: _obscureConfirmPassword,
                    controller: confirmpasswordController,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm your password';
                      }
                      if (value != passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 28),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => register(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Register',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Already have an account?',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => LoginPage()),
                      );
                    },
                    child: const Text(
                      'Login',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
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

  Widget _inputField({
    required String label,
    required IconData icon,
    TextInputType keyboard = TextInputType.text,
    bool obscure = false,
    Widget? suffixIcon,
    TextEditingController? controller,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      obscureText: obscure,
      decoration: _inputDecoration(
        label: label,
        icon: icon,
        suffixIcon: suffixIcon,
      ),
      validator: validator,
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
