import 'package:dermascan/login.dart' show LoginPage;
import 'package:dermascan/services/firebase_auth_service.dart';
import 'package:dermascan/services/email_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'patient_dashboard.dart'; 

class RegisterPage extends StatefulWidget {
  final User? googleUser; // Changed to Nullable User?
  const RegisterPage({super.key, this.googleUser}); // Made optional

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  final TextEditingController _confirmPassController = TextEditingController();

  final FirebaseAuthService _authService = FirebaseAuthService();
  final Color accentColor = const Color(0xFF4FD1C5); 
  final Color bgColor = Colors.white;
  final Color inputFill = const Color(0xFFF3F4F6);
  final Color textColor = const Color(0xFF1F2937);

  bool _isObscured = true;
  bool _isLoading = false;
  String _selectedGender = "Male";

  @override
  void initState() {
    super.initState();
    // If user came from Google, auto-fill their info
    if (widget.googleUser != null) {
      _nameController.text = widget.googleUser!.displayName ?? "";
      _emailController.text = widget.googleUser!.email ?? "";
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: ColorScheme.light(primary: accentColor)), child: child!),
    );
    if (picked != null) setState(() => _dateController.text = "${picked.day}/${picked.month}/${picked.year}");
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      // Show payment confirmation dialog
      _showPaymentConfirmation();
    }
  }

  void _showPaymentConfirmation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.payment_rounded, color: accentColor, size: 48),
            ),
            const SizedBox(height: 20),
            const Text(
              "Registration Fee",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "A one-time registration fee is required to complete your account setup.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.currency_rupee_rounded, color: Colors.green.shade700, size: 28),
                  Text(
                    "100",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _processRegistration();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("Pay ₹100", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _processRegistration() async {
    setState(() => _isLoading = true);
    try {
      final result = await _authService.registerPatient(
        email: _emailController.text.trim(),
        password: _passController.text.isEmpty ? "google_auth_placeholder" : _passController.text,
        name: _nameController.text.trim(),
        dateOfBirth: _dateController.text,
        gender: _selectedGender,
        registrationFee: 100,
      );

      if (!mounted) return;
      if (result['success']) {
        // Automatically send credentials email in background
        EmailService.sendPatientCredentials(
          patientName: _nameController.text.trim(),
          patientEmail: _emailController.text.trim(),
          password: _passController.text.isEmpty ? "(Logged in via Google)" : _passController.text,
        );

        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const PatientDashboard()), (route) => false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message']), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, leading: IconButton(icon: Icon(Icons.chevron_left, color: textColor, size: 30), onPressed: () => Navigator.pop(context))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Text("Access Care", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textColor)),
              const SizedBox(height: 8),
              Text("Tell us a bit more about yourself", style: TextStyle(color: Colors.grey[600], fontSize: 15)),
              const SizedBox(height: 30),
              _validatedInput(controller: _nameController, hint: "Full Name", icon: Icons.person_outline, validator: (val) => val!.isEmpty ? "Enter your name" : null),
              const SizedBox(height: 16),
              _validatedInput(controller: _emailController, hint: "Email Address", icon: Icons.mail_outline, validator: (val) => val!.isEmpty ? "Enter email" : null),
              const SizedBox(height: 16),
              TextFormField(
                controller: _dateController,
                readOnly: true,
                onTap: () => _selectDate(context),
                validator: (val) => val!.isEmpty ? "Select Date of Birth" : null,
                decoration: _inputStyle(hint: "Date of Birth", icon: Icons.calendar_today_outlined),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedGender,
                decoration: _inputStyle(hint: "Gender", icon: Icons.wc_rounded),
                items: ["Male", "Female", "Other"].map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
                onChanged: (val) => setState(() => _selectedGender = val!),
              ),
              // Only show password fields if NOT registering with Google
              if (widget.googleUser == null) ...[
                const SizedBox(height: 16),
                _validatedInput(controller: _passController, hint: "Password", icon: Icons.lock_outline, isPassword: true, validator: (val) => val!.length < 6 ? "Min 6 chars" : null),
                const SizedBox(height: 16),
                _validatedInput(controller: _confirmPassController, hint: "Confirm Password", icon: Icons.lock_reset, isPassword: true, validator: (val) => val != _passController.text ? "No match" : null),
              ],
              const SizedBox(height: 30),
              _buildSubmitBtn(),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitBtn() {
    return Container(
      width: double.infinity, height: 56,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: accentColor.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))]),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitForm,
        style: ElevatedButton.styleFrom(backgroundColor: accentColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("Sign Up", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }

  InputDecoration _inputStyle({required String hint, required IconData icon, bool isPassword = false}) {
    return InputDecoration(
      hintText: hint, prefixIcon: Icon(icon, color: accentColor),
      suffixIcon: isPassword ? IconButton(icon: Icon(_isObscured ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _isObscured = !_isObscured)) : null,
      filled: true, fillColor: inputFill, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
    );
  }

  Widget _validatedInput({required TextEditingController controller, required String hint, required IconData icon, required String? Function(String?) validator, bool isPassword = false}) {
    return TextFormField(controller: controller, obscureText: isPassword ? _isObscured : false, validator: validator, decoration: _inputStyle(hint: hint, icon: icon, isPassword: isPassword));
  }
}