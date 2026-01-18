import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseAuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _firebaseAuth.currentUser;

  // Check if user is logged in
  bool get isLoggedIn => _firebaseAuth.currentUser != null;

  /// Register patient account
  Future<Map<String, dynamic>> registerPatient({
    required String email,
    required String password,
    required String name,
    required String dateOfBirth,
    required String gender,
    String? phone,
  }) async {
    try {
      final UserCredential userCredential =
          await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final String userId = userCredential.user!.uid;

      // Store in 'users' (Master collection for roles)
      await _firestore.collection('users').doc(userId).set({
        'uid': userId,
        'email': email,
        'name': name,
        'phone': phone ?? '',
        'userRole': 'patient',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Store in 'patients' (Profile specific)
      await _firestore.collection('patients').doc(userId).set({
        'uid': userId,
        'email': email,
        'name': name,
        'phone': phone ?? '',
        'dateOfBirth': dateOfBirth,
        'gender': gender,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return {'success': true, 'message': 'Registration successful', 'uid': userId};
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'message': _handleAuthException(e)};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Login user
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential userCredential =
          await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final String userId = userCredential.user!.uid;

      // Fetch Role
      final DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(userId).get();

      if (!userDoc.exists) {
        return {'success': false, 'message': 'User profile not found'};
      }

      final String userRole = userDoc['userRole'] ?? 'patient';

      return {
        'success': true,
        'message': 'Login successful',
        'uid': userId,
        'email': email,
        'userRole': userRole,
      };
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'message': _handleAuthException(e)};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// 🔹 NEW: Check if user exists by email (For Google Login Logic)
  Future<bool> doesEmailExist(String email) async {
    try {
      final QuerySnapshot result = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      return result.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// 🔹 UPDATED: Reset password (With Debugging)
  Future<Map<String, dynamic>> resetPassword({required String email}) async {
    try {
      // Logic check: Firebase only sends if the user exists in Auth list
      await _firebaseAuth.sendPasswordResetEmail(email: email);
      
      print("SUCCESS: Reset link triggered for $email");
      
      return {
        'success': true,
        'message': 'A reset link has been sent to $email. Please check your inbox and spam folder.',
      };
    } on FirebaseAuthException catch (e) {
      // ⚠️ Check your Debug Console/Terminal for these prints!
      print("FIREBASE AUTH ERROR: ${e.code}"); 
      print("ERROR MESSAGE: ${e.message}");
      
      return {
        'success': false,
        'message': _handleAuthException(e),
      };
    } catch (e) {
      print("GENERAL ERROR: $e");
      return {
        'success': false,
        'message': 'An unexpected error occurred.',
      };
    }
  }

  /// Logout
  Future<void> logout() async {
    await _firebaseAuth.signOut();
  }

  /// Handle Firebase Auth Exceptions
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Check your internet connection.';
      default:
        return e.message ?? 'Authentication failed.';
    }
  }

  /// 🔹 GET USER ROLE
  Future<String?> getUserRole(String userId) async {
    try {
      final DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(userId).get();

      if (userDoc.exists) {
        return userDoc['userRole'] as String?;
      }
    } catch (e) {
      print("Error fetching user role: $e");
    }
    return null;
  }
}