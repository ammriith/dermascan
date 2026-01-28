import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dermascan/services/email_service.dart';

class AddDoctorPage extends StatefulWidget {
  const AddDoctorPage({super.key});

  @override
  State<AddDoctorPage> createState() => _AddDoctorPageState();
}

class _AddDoctorPageState extends State<AddDoctorPage> {
  final _formKey = GlobalKey<FormState>();
  static const Color accentColor = Color(0xFF4FD1C5);
  static const Color bgColor = Color(0xFFF8FAFC);
  static const Color inputFill = Color(0xFFF3F4F6);
  static const Color textColor = Color(0xFF1F2937);

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _specializationController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();
  final TextEditingController _consultationFeeController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isEmailSending = false;
  String? _emailStatusMessage;
  bool _emailSuccess = false;

  // Weekly Schedule State
  final Set<int> _selectedDays = {1, 2, 3, 4, 5}; // Monday to Friday
  TimeOfDay _startTime = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 16, minute: 0);

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _specializationController.dispose();
    _phoneController.dispose();
    _experienceController.dispose();
    _consultationFeeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Generate password based on doctor name
  String _generatePassword() {
    final name = _nameController.text.trim().split(' ').first.toLowerCase();
    return "Dr$name@123";
  }

  Future<void> _addDoctor() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      String password = _passwordController.text.trim();
      if (password.isEmpty) {
        password = _generatePassword();
      }

      // Create Firebase Auth account for doctor
      final UserCredential userCredential = 
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final String doctorId = userCredential.user!.uid;

      // Store in 'users' collection (for role-based access)
      await FirebaseFirestore.instance.collection('users').doc(doctorId).set({
        'uid': doctorId,
        'email': email,
        'name': _nameController.text.trim(),
        'userRole': 'doctor',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Store in 'doctors' collection (profile specific)
      await FirebaseFirestore.instance.collection('doctors').doc(doctorId).set({
        'uid': doctorId,
        'name': _nameController.text.trim(),
        'email': email,
        'phone': _phoneController.text.trim(),
        'specialization': _specializationController.text.trim(),
        'experience': int.tryParse(_experienceController.text.trim()) ?? 0,
        'consultationFee': double.tryParse(_consultationFeeController.text.trim()) ?? 0.0,
        'isVerified': true,
        'weeklySchedule': {
          'days': _selectedDays.toList(),
          'startTime': '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}',
          'endTime': '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}',
          'slotDuration': 20, // requested 20 mins
        },
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        // Automatically trigger email sending
        _sendEmailViaService(_nameController.text.trim(), email, password, isAutomated: true);
        
        // Show credentials dialog (it now displays the automated status)
        _showCredentialsDialog(
          name: _nameController.text.trim(),
          email: email,
          password: password,
          phone: _phoneController.text.trim(),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'email-already-in-use':
          message = 'This email is already registered.';
          break;
        case 'invalid-email':
          message = 'Please enter a valid email address.';
          break;
        case 'weak-password':
          message = 'Password is too weak. Use at least 6 characters.';
          break;
        default:
          message = e.message ?? 'Registration failed.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showCredentialsDialog({
    required String name,
    required String email,
    required String password,
    required String phone,
  }) {
    final smsMessage = "Welcome to DermaScan!\n\n"
        "Your doctor account has been created.\n\n"
        "Login Credentials:\n"
        "Email: $email\n"
        "Password: $password\n\n"
        "Please change your password after first login.";
    
    final emailSubject = "Your DermaScan Doctor Account Credentials";
    final emailBody = "Dear Dr. $name,\n\n"
        "Welcome to DermaScan Clinic!\n\n"
        "Your doctor account has been created. Please use the following credentials to login:\n\n"
        "Email: $email\n"
        "Password: $password\n\n"
        "For security, please change your password after your first login.\n\n"
        "Go to: Settings > Change Password\n\n"
        "Best regards,\n"
        "DermaScan Clinic Team";
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.85,
            maxWidth: 400,
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Success Icon
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.check_circle_rounded, size: 40, color: Colors.green.shade600),
                  ),
                  const SizedBox(height: 14),
                  
                  // Title
                  const Text(
                    "Doctor Added!",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Send login credentials to the doctor",
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  
                  // Automated Email Status
                  StatefulBuilder(
                    builder: (context, setDialogState) {
                      // We use a listener or check the parent state
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: _isEmailSending 
                              ? Colors.blue.shade50 
                              : (_emailSuccess ? Colors.green.shade50 : Colors.red.shade50),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isEmailSending)
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.blue)),
                              )
                            else 
                              Icon(
                                _emailSuccess ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                                size: 16,
                                color: _emailSuccess ? Colors.green : Colors.red,
                              ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                _isEmailSending 
                                    ? "Sending automated email..." 
                                    : (_emailStatusMessage ?? "Email sending pending"),
                                style: TextStyle(
                                  fontSize: 12, 
                                  color: _isEmailSending 
                                      ? Colors.blue.shade700 
                                      : (_emailSuccess ? Colors.green.shade700 : Colors.red.shade700),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Credentials Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        _buildCredentialRow("Doctor Name", "Dr. $name", Icons.person_rounded),
                        const Divider(height: 16),
                        _buildCredentialRow("Email (Username)", email, Icons.email_rounded, canCopy: true),
                        const Divider(height: 16),
                        _buildCredentialRow("Password", password, Icons.lock_rounded, canCopy: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Send SMS Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _sendSMS(phone, smsMessage),
                      icon: const Icon(Icons.sms_rounded, size: 18),
                      label: const Text("Send SMS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Send Email Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _sendEmailViaService(name, email, password),
                      icon: const Icon(Icons.email_rounded, size: 18),
                      label: const Text("Send Email", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Copy Credentials Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final credentials = "Doctor Login Credentials\n\nName: Dr. $name\nEmail: $email\nPassword: $password";
                        Clipboard.setData(ClipboardData(text: credentials));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Credentials copied to clipboard!'),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text("Copy Credentials", style: TextStyle(fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: accentColor,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        side: const BorderSide(color: accentColor),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Done Button
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(ctx); // Close dialog
                        Navigator.pop(context, true); // Return to previous screen
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey.shade600,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text("Done", style: TextStyle(fontWeight: FontWeight.bold)),
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
  
  void _sendSMS(String phone, String message) async {
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Phone number not available'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    
    final Uri smsUri = Uri(
      scheme: 'sms',
      path: phone,
      queryParameters: {'body': message},
    );
    
    try {
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Opening SMS app...'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 1),
          ),
        );
      } else {
        Clipboard.setData(ClipboardData(text: message));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('SMS not available. Credentials copied to clipboard!'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      Clipboard.setData(ClipboardData(text: message));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Credentials copied to clipboard!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _sendEmailViaService(String doctorName, String doctorEmail, String password, {bool isAutomated = false}) async {
    if (mounted && isAutomated) {
      setState(() {
        _isEmailSending = true;
        _emailStatusMessage = "Sending...";
        _emailSuccess = false;
      });
    }
    
    // On Web platform, SMTP doesn't work - use mailto link instead
    if (kIsWeb) {
      if (mounted && isAutomated) {
        setState(() {
          _isEmailSending = false;
          _emailStatusMessage = "Web: Use manual email button";
          _emailSuccess = false;
        });
      }
      
      if (!isAutomated) {
        final emailSubject = Uri.encodeComponent("Your DermaScan Doctor Account Credentials");
        final emailBody = Uri.encodeComponent(
          "Dear Dr. $doctorName,\n\n"
          "Welcome to DermaScan Clinic!\n\n"
          "Your doctor account has been created. Please use the following credentials to login:\n\n"
          "Email: $doctorEmail\n"
          "Password: $password\n\n"
          "For security, please change your password after your first login.\n\n"
          "Go to: Settings > Change Password\n\n"
          "Best regards,\n"
          "DermaScan Clinic Team"
        );
        
        final mailtoUri = Uri.parse('mailto:$doctorEmail?subject=$emailSubject&body=$emailBody');
        
        try {
          if (await canLaunchUrl(mailtoUri)) {
            await launchUrl(mailtoUri);
          } else {
            final credentials = "Doctor Login Credentials\n\nEmail: $doctorEmail\nPassword: $password";
            await Clipboard.setData(ClipboardData(text: credentials));
          }
        } catch (e) {
          final credentials = "Doctor Login Credentials\n\nEmail: $doctorEmail\nPassword: $password";
          await Clipboard.setData(ClipboardData(text: credentials));
        }
      }
      return;
    }
    
    // On mobile/desktop, use SMTP email service
    if (!isAutomated) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(
          child: CircularProgressIndicator(color: accentColor),
        ),
      );
    }

    try {
      final result = await EmailService.sendDoctorCredentials(
        doctorName: doctorName,
        doctorEmail: doctorEmail,
        password: password,
      );

      // Close loading if manual
      if (mounted && !isAutomated) Navigator.pop(context);

      if (mounted) {
        setState(() {
          _isEmailSending = false;
          _emailSuccess = result.success;
          _emailStatusMessage = result.success ? "Email sent successfully!" : result.message;
        });
      }

      if (!isAutomated) {
        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Email sent successfully to $doctorEmail')),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(child: Text(result.message)),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted && !isAutomated) Navigator.pop(context);
      
      if (mounted) {
        setState(() {
          _isEmailSending = false;
          _emailSuccess = false;
          _emailStatusMessage = "Error: $e";
        });
      }
      
      if (!isAutomated) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildCredentialRow(String label, String value, IconData icon, {bool canCopy = false}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: accentColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
        if (canCopy)
          IconButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$label copied!'),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 1),
                ),
              );
            },
            icon: Icon(Icons.copy_rounded, size: 18, color: Colors.grey.shade500),
            tooltip: 'Copy',
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Add New Doctor",
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Icon
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_add_alt_1_rounded, size: 50, color: accentColor),
                ),
              ),
              const SizedBox(height: 30),

              // Section: Basic Info
              Text(
                "Basic Information",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 16),

              // Name Field
              _buildTextField(
                controller: _nameController,
                label: "Full Name",
                icon: Icons.person_outlined,
                validator: (val) => val!.isEmpty ? "Enter name" : null,
              ),
              const SizedBox(height: 16),

              // Email Field (moved to basic info)
              _buildTextField(
                controller: _emailController,
                label: "Email Address",
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v!.isEmpty) return "Email is required";
                  if (!v.contains('@')) return "Enter a valid email";
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Phone Field
              _buildTextField(
                controller: _phoneController,
                label: "Phone Number",
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                validator: (v) => v!.isEmpty ? "Phone is required" : null,
              ),
              const SizedBox(height: 16),

              // Specialization Field
              _buildTextField(
                controller: _specializationController,
                label: "Specialization",
                icon: Icons.medical_services_outlined,
                validator: (v) => v!.isEmpty ? "Specialization is required" : null,
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  // Experience Field
                  Expanded(
                    child: _buildTextField(
                      controller: _experienceController,
                      label: "Experience (Years)",
                      icon: Icons.work_outlined,
                      keyboardType: TextInputType.number,
                      validator: (val) => val!.isEmpty ? "Required" : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Consultation Fee Field
                  Expanded(
                    child: _buildTextField(
                      controller: _consultationFeeController,
                      label: "Fee (₹)",
                      icon: Icons.currency_rupee,
                      keyboardType: TextInputType.number,
                      validator: (v) => v!.isEmpty ? "Required" : null,
                    ),
                  ),
                ],
              ),


              const SizedBox(height: 24),
              _buildWeeklyScheduleSection(),
              const SizedBox(height: 24),
              
              // Info box about login credentials
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade600, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Login Credentials",
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Password will be auto-generated and shown after registration. Share it with the doctor.",
                            style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // Submit Button
              Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _addDoctor,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Add Doctor", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeeklyScheduleSection() {
    final List<String> weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Weekly Booking Window",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor.withValues(alpha: 0.7)),
        ),
        const SizedBox(height: 12),
        const Text(
          "Select work days and shift timings",
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        
        // Day Selector
        Wrap(
          spacing: 8,
          children: List.generate(7, (index) {
            final dayIndex = index + 1;
            final isSelected = _selectedDays.contains(dayIndex);
            return FilterChip(
              label: Text(weekdays[index], style: TextStyle(
                fontSize: 12, 
                color: isSelected ? Colors.white : textColor,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              )),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedDays.add(dayIndex);
                  } else {
                    _selectedDays.remove(dayIndex);
                  }
                });
              },
              selectedColor: accentColor,
              checkmarkColor: Colors.white,
              backgroundColor: inputFill,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            );
          }),
        ),
        
        const SizedBox(height: 16),
        
        // Time Window Selector
        Row(
          children: [
            Expanded(
              child: _buildTimePicker(
                label: "Starts at",
                time: _startTime,
                onTap: () async {
                  final picked = await showTimePicker(context: context, initialTime: _startTime);
                  if (picked != null) setState(() => _startTime = picked);
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTimePicker(
                label: "Ends at",
                time: _endTime,
                onTap: () async {
                  final picked = await showTimePicker(context: context, initialTime: _endTime);
                  if (picked != null) setState(() => _endTime = picked);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTimePicker({required String label, required TimeOfDay time, required VoidCallback onTap}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: inputFill,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  time.format(context),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const Icon(Icons.access_time_rounded, size: 18, color: accentColor),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    bool isPassword = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: isPassword,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: accentColor),
        filled: true,
        fillColor: inputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: accentColor, width: 2),
        ),
      ),
    );
  }
}
