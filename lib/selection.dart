import 'dart:ui';
import 'package:dermascan/login.dart';
import 'package:dermascan/patient/patient_register.dart';
import 'package:dermascan/patient/patient_dashboard.dart'; 
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AuthSelectionPage extends StatelessWidget {
  const AuthSelectionPage({super.key});

  final Color textColor = const Color(0xFFF5F7FA);
  final Color subTextColor = const Color(0xFFC9D6DF);
  final Color accentColor = const Color(0xFF4FD1C5);

  Future<void> _handleGoogleSignIn(BuildContext context) async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) return; // User canceled the picker

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase Auth
      final UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null && context.mounted) {
        // 🔹 LOOKUP: Search Firestore for this specific email
        final QuerySnapshot userQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: user.email)
            .limit(1)
            .get();

        if (userQuery.docs.isNotEmpty) {
          // 🔹 USER EXISTS: Navigate directly to Dashboard
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const PatientDashboard()),
            (route) => false,
          );
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Logged in successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          // 🔹 NEW USER: Navigate to registration to fill details (Age, Gender, etc.)
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RegisterPage(googleUser: user),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login Error: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: Stack(
        children: [
          // 🔹 Fixed Image Path
          Positioned.fill(
            child: Image.asset(
              'assets/image1.jpg', 
              fit: BoxFit.cover, 
              errorBuilder: (_, __, ___) => Container(color: Colors.black)
            )
          ),          
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, 
                  end: Alignment.bottomCenter, 
                  colors: [Colors.black.withOpacity(0.3), Colors.black.withOpacity(0.9)]
                )
              )
            )
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  Text("Welcome", style: TextStyle(color: textColor, fontSize: 32, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text("Select an option to continue", textAlign: TextAlign.center, style: TextStyle(color: subTextColor, fontSize: 16)),
                  const SizedBox(height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _textBtn("Login", accentColor, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginPage(userRole: 'patient')))),
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text("|", style: TextStyle(color: subTextColor, fontSize: 18))),
                      _textBtn("Signup", textColor, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterPage()))),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // 🔹 Google Button
                  _buildBtn(context, "Continue with Google", Colors.white, Colors.black87, Icons.g_mobiledata, () => _handleGoogleSignIn(context)),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _textBtn(String label, Color col, VoidCallback onTap) {
    return GestureDetector(onTap: onTap, child: Text(label, style: TextStyle(color: col, fontSize: 16, fontWeight: FontWeight.bold)));
  }

  Widget _buildBtn(BuildContext context, String label, Color bgColor, Color txtColor, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity, height: 54, alignment: Alignment.center,
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(16)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [Icon(icon, color: txtColor, size: 30), const SizedBox(width: 8), Text(label, style: TextStyle(color: txtColor, fontWeight: FontWeight.bold, fontSize: 16))],
        ),
      ),
    );
  }
}