import 'package:dermascan/patient/patient_dashboard.dart';
import 'package:dermascan/patient/patient_register.dart';
import 'package:dermascan/services/firebase_auth_service.dart';
import 'package:dermascan/admin/admin_dashboard.dart';
import 'package:dermascan/doctor/doctor_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required String userRole}); 

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>{
  final _formKey = GlobalKey<FormState>();
  
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuthService _authService = FirebaseAuthService();

  final Color accentColor = const Color(0xFF4FD1C5); 
  final Color bgColor = Colors.white;
  final Color inputFill = const Color(0xFFF3F4F6);
  final Color textColor = const Color(0xFF1F2937);

  bool _isObscured = true;
  bool _isLoading = false;

  // 🔹 FUNCTION: HANDLE FORGOT PASSWORD
  void _handleForgotPassword() {
    final TextEditingController resetController = TextEditingController();
    
    // Capture messenger before dialog closes to avoid "deactivated widget" error
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Reset Password", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Enter your email address to receive a reset link."),
            const SizedBox(height: 20),
            TextField(
              controller: resetController,
              decoration: _inputStyle(hint: "Email Address", icon: Icons.email_outlined),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext), 
            child: const Text("Cancel")
          ),
          ElevatedButton(
            onPressed: () async {
              String email = resetController.text.trim();
              if (email.isEmpty) return;

              Navigator.pop(dialogContext); // Close dialog

              final result = await _authService.resetPassword(email: email);
              
              messenger.showSnackBar(
                SnackBar(
                  content: Text(result['message']), 
                  backgroundColor: result['success'] ? Colors.green : Colors.red
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: accentColor),
            child: const Text("Send", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // 🔹 FUNCTION: HANDLE LOGIN WITH ROLE REDIRECT
  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      HapticFeedback.mediumImpact();
      setState(() => _isLoading = true);

      try {
        final result = await _authService.login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

        if (!mounted) return;

        if (result['success']) {
          // Extract role and normalize to lowercase
          String userRole = result['userRole']?.toString().toLowerCase().trim() ?? 'patient';
          
          Widget destinationPage;
          
          if (userRole == 'admin' || userRole == 'staff') {
            // 🔹 NAVIGATE TO CLINIC STAFF DASHBOARD
            destinationPage = const ClinicStaffDashboard();
          } else if (userRole == 'doctor') {
            // 🔹 NAVIGATE TO DOCTOR DASHBOARD
            destinationPage = const DoctorDashboard();
          } else {
            // 🔹 NAVIGATE TO PATIENT DASHBOARD
            destinationPage = const PatientDashboard();
          }
          
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => destinationPage),
            (route) => false,
          );

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Login successful"), backgroundColor: Colors.teal),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message']), backgroundColor: Colors.red),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login error: $e'), backgroundColor: Colors.red),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.chevron_left, color: textColor, size: 30),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              Text(
                "Welcome Back",
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: textColor),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                "Access your Dermascan account",
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
              ),
              const SizedBox(height: 50),

              /// EMAIL
              TextFormField(
                controller: _emailController,
                validator: (value) => (value == null || value.isEmpty) ? "Enter email" : null,
                decoration: _inputStyle(hint: "Email Address", icon: Icons.mail_outline),
              ),
              const SizedBox(height: 20),

              /// PASSWORD
              TextFormField(
                controller: _passwordController,
                obscureText: _isObscured,
                validator: (value) => (value == null || value.isEmpty) ? "Enter password" : null,
                decoration: _inputStyle(hint: "Password", icon: Icons.lock_outline, isPassword: true),
              ),

              /// FORGOT PASSWORD
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _handleForgotPassword,
                  child: Text(
                    "Forgot Password?",
                    style: TextStyle(color: accentColor, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              /// LOGIN BUTTON
              Container(
                width: double.infinity, height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: accentColor.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
                ),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Log In", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),

              const SizedBox(height: 40),

              /// SIGN UP LINK
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Don't have an account? ", style: TextStyle(color: Colors.grey[600])),
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterPage())),
                    child: Text(
                      "Sign Up",
                      style: TextStyle(color: accentColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputStyle({required String hint, required IconData icon, bool isPassword = false}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: accentColor),
      suffixIcon: isPassword
          ? IconButton(
              icon: Icon(_isObscured ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _isObscured = !_isObscured),
            )
          : null,
      filled: true,
      fillColor: inputFill,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}