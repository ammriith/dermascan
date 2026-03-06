import 'package:flutter_test/flutter_test.dart';
// Note: We are testing the private logic or public structure where possible
// Since many methods are static and private, we focus on what's accessible

void main() {
  group('EmailService Validation Tests', () {
    
    // Helper to simulate the private _isValidEmail if it were public or via a wrapper
    bool isValidEmail(String email) {
      return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(email);
    }

    test('Should validate correct email formats', () {
      expect(isValidEmail('test@example.com'), isTrue);
      expect(isValidEmail('doctor.name@clinic.org'), isTrue);
      expect(isValidEmail('patient123@gmail.co.in'), isTrue);
    });

    test('Should reject invalid email formats', () {
      expect(isValidEmail('test@example'), isFalse);
      expect(isValidEmail('test@.com'), isFalse);
      expect(isValidEmail('@example.com'), isFalse);
      expect(isValidEmail('test example@com'), isFalse);
    });
  });
}
