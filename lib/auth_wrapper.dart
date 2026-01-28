import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dermascan/services/firebase_auth_service.dart';
import 'package:dermascan/landing_page.dart';
import 'package:dermascan/patient/patient_dashboard.dart';
import 'package:dermascan/admin/admin_dashboard.dart';
import 'package:dermascan/doctor/doctor_dashboard.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final FirebaseAuthService _authService = FirebaseAuthService();
  bool _isLoading = true;
  Widget? _startScreen;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    try {
      final user = _authService.currentUser;

      if (user != null) {
        // User is logged in, fetch role
        String? role = await _authService.getUserRole(user.uid);
        
        // Normalize role string
        role = role?.toLowerCase().trim();

        if (role == 'admin' || role == 'staff') {
          _startScreen = const ClinicStaffDashboard();
        } else if (role == 'doctor') {
          _startScreen = const DoctorDashboard();
        } else {
          // Default to patient if role is missing or 'patient'
          _startScreen = const PatientDashboard();
        }
      } else {
        // No user logged in
        _startScreen = const LandingPage();
      }
    } catch (e) {
      print("Session check error: $e");
      _startScreen = const LandingPage();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF4FD1C5), // Matches app accent color
          ),
        ),
      );
    }
    
    return _startScreen ?? const LandingPage();
  }
}
