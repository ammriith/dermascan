import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// EMAIL SERVICE FOR DERMASCAN
/// ═══════════════════════════════════════════════════════════════════════════
/// 
/// Uses SMTP via Gmail to send emails on Mobile and Desktop platforms.
/// 
/// SETUP STEPS:
/// 1. Enable 2-Factor Authentication on your Gmail account
/// 2. Go to: https://myaccount.google.com/apppasswords
/// 3. Generate an "App Password" (16 characters)
/// 4. Update _senderPassword below with that App Password
/// 
/// NOTE: This service works on Mobile and Desktop platforms only.
///       Web browsers don't support direct SMTP connections.

class EmailService {
  // ╔═══════════════════════════════════════════════════════════════════════╗
  // ║  SMTP CONFIGURATION                                                   ║
  // ╚═══════════════════════════════════════════════════════════════════════╝
  
  /// Your Gmail address
  static const String _senderEmail = 'amrithpalath@gmail.com';
  
  /// Your Gmail App Password (NOT your regular password!)
  /// Generate at: https://myaccount.google.com/apppasswords
  static const String _senderPassword = 'zhnk lppg apen revm';
  
  /// Display name for sent emails
  static const String _senderName = 'DermaScan Clinic';
  
  /// Connection timeout for mobile networks (in seconds)
  static const int _connectionTimeout = 30;
  
  /// Gmail SMTP Server configuration with proper settings for mobile
  static SmtpServer get _smtpServer => SmtpServer(
    'smtp.gmail.com',
    port: 465,
    ssl: true,
    username: _senderEmail,
    password: _senderPassword,
    allowInsecure: false,
  );

  // ╔═══════════════════════════════════════════════════════════════════════╗
  // ║  LOGGING UTILITY                                                       ║
  // ╚═══════════════════════════════════════════════════════════════════════╝
  
  static void _log(String message, {bool isError = false}) {
    final timestamp = DateTime.now().toIso8601String();
    final prefix = isError ? '❌ [EMAIL ERROR]' : '📧 [EMAIL]';
    if (kDebugMode) {
      print('$prefix [$timestamp] $message');
    }
  }

  // ╔═══════════════════════════════════════════════════════════════════════╗
  // ║  NETWORK CONNECTIVITY CHECK                                           ║
  // ╚═══════════════════════════════════════════════════════════════════════╝
  
  static Future<bool> _checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('smtp.gmail.com')
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    } on TimeoutException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  // ╔═══════════════════════════════════════════════════════════════════════╗
  // ║  SMTP SENDER WITH MOBILE OPTIMIZATIONS                                ║
  // ╚═══════════════════════════════════════════════════════════════════════╝
  
  static Future<EmailResult> _sendViaSmtp({
    required Message message,
    required String recipientEmail,
  }) async {
    _log('═══════════════════════════════════════════════════════');
    _log('Attempting to send email via SMTP...');
    _log('Recipient: $recipientEmail');
    _log('Sender Email: $_senderEmail');
    _log('Sender Name: $_senderName');

    // Check if running on web
    if (kIsWeb) {
      _log('Web platform detected - SMTP not supported on web browsers', isError: true);
      return EmailResult(
        success: false,
        message: 'Email sending is not supported on web browsers. Please use mobile or desktop app.',
      );
    }

    // Check if credentials are configured
    if (_senderEmail.isEmpty || _senderPassword.isEmpty) {
      _log('SMTP credentials not configured!', isError: true);
      return EmailResult(
        success: false,
        message: 'Email credentials not configured. Please update email_service.dart.',
      );
    }

    // Check internet connectivity first
    _log('Checking internet connectivity...');
    final hasInternet = await _checkInternetConnection();
    if (!hasInternet) {
      _log('No internet connection detected!', isError: true);
      return EmailResult(
        success: false,
        message: 'No internet connection. Please check your network and try again.',
      );
    }
    _log('Internet connection: OK');

    try {
      _log('Connecting to Gmail SMTP server...');
      _log('Host: smtp.gmail.com, Port: 465, SSL: true');
      _log('Timeout: $_connectionTimeout seconds');
      
      // Send with timeout for mobile networks
      final sendReport = await send(message, _smtpServer)
          .timeout(
            Duration(seconds: _connectionTimeout),
            onTimeout: () {
              throw TimeoutException('Email sending timed out after $_connectionTimeout seconds');
            },
          );
      
      _log('✅ SUCCESS: Email sent via SMTP!');
      _log('Send Report: ${sendReport.toString()}');
      
      return EmailResult(
        success: true,
        message: 'Email sent successfully to $recipientEmail',
      );
    } on TimeoutException catch (e) {
      _log('Timeout occurred!', isError: true);
      _log('Error: $e', isError: true);
      return EmailResult(
        success: false,
        message: 'Email sending timed out. Please check your internet connection and try again.',
      );
    } on SocketException catch (e) {
      _log('SocketException occurred!', isError: true);
      _log('Error: $e', isError: true);
      return EmailResult(
        success: false,
        message: 'Network error. Please check your internet connection and try again.',
      );
    } on MailerException catch (e) {
      _log('MailerException occurred!', isError: true);
      _log('Error message: ${e.message}', isError: true);
      
      // Log all problems
      for (var problem in e.problems) {
        _log('Problem [${problem.code}]: ${problem.msg}', isError: true);
      }
      
      // Provide user-friendly error messages
      String errorMessage = 'Failed to send email';
      final errorLower = e.message.toLowerCase();
      
      if (errorLower.contains('authentication') || 
          errorLower.contains('credentials') ||
          errorLower.contains('535')) {
        errorMessage = 'Gmail authentication failed. Please verify your App Password is correct.';
      } else if (errorLower.contains('connection') || 
                 errorLower.contains('socket') ||
                 errorLower.contains('timeout')) {
        errorMessage = 'Could not connect to email server. Please check your internet connection.';
      } else if (errorLower.contains('recipient') || 
                 errorLower.contains('address')) {
        errorMessage = 'Invalid recipient email address. Please verify the email.';
      } else if (errorLower.contains('ssl') || errorLower.contains('tls')) {
        errorMessage = 'Secure connection failed. Please try again.';
      } else {
        errorMessage = 'Email error: ${e.message}';
      }
      
      return EmailResult(
        success: false,
        message: errorMessage,
      );
    } on HandshakeException catch (e) {
      _log('SSL/TLS HandshakeException occurred!', isError: true);
      _log('Error: $e', isError: true);
      return EmailResult(
        success: false,
        message: 'Secure connection failed. Please check your network settings.',
      );
    } catch (e, stackTrace) {
      _log('Unexpected error during SMTP send!', isError: true);
      _log('Error type: ${e.runtimeType}', isError: true);
      _log('Error: $e', isError: true);
      _log('Stack trace: $stackTrace', isError: true);
      return EmailResult(
        success: false,
        message: 'Unexpected error: ${e.toString().split('\n').first}',
      );
    }
  }

  // ╔═══════════════════════════════════════════════════════════════════════╗
  // ║  PUBLIC API: SEND DOCTOR CREDENTIALS                                  ║
  // ╚═══════════════════════════════════════════════════════════════════════╝
  
  /// Send email to doctor with their login credentials
  static Future<EmailResult> sendDoctorCredentials({
    required String doctorName,
    required String doctorEmail,
    required String password,
  }) async {
    _log('');
    _log('╔═══════════════════════════════════════════════════════════════╗');
    _log('║           SENDING DOCTOR CREDENTIALS EMAIL                    ║');
    _log('╚═══════════════════════════════════════════════════════════════╝');
    _log('Doctor Name: $doctorName');
    _log('Doctor Email: $doctorEmail');
    _log('Password: ${password.replaceAll(RegExp(r'.'), '*')}');
    _log('Platform: ${_getPlatformName()}');
    _log('');

    // Validate email format
    if (!_isValidEmail(doctorEmail)) {
      _log('Invalid email format: $doctorEmail', isError: true);
      return EmailResult(
        success: false,
        message: 'Invalid email address format.',
      );
    }

    final message = Message()
      ..from = Address(_senderEmail, _senderName)
      ..recipients.add(doctorEmail)
      ..subject = 'Welcome to DermaScan - Your Doctor Account Credentials'
      ..html = _buildDoctorCredentialsHtml(doctorName, doctorEmail, password);

    return _sendViaSmtp(message: message, recipientEmail: doctorEmail);
  }

  // ╔═══════════════════════════════════════════════════════════════════════╗
  // ║  PUBLIC API: SEND PATIENT CREDENTIALS                                 ║
  // ╚═══════════════════════════════════════════════════════════════════════╝
  
  /// Send email to patient with their login credentials
  static Future<EmailResult> sendPatientCredentials({
    required String patientName,
    required String patientEmail,
    required String password,
  }) async {
    _log('');
    _log('╔═══════════════════════════════════════════════════════════════╗');
    _log('║          SENDING PATIENT CREDENTIALS EMAIL                    ║');
    _log('╚═══════════════════════════════════════════════════════════════╝');
    _log('Patient Name: $patientName');
    _log('Patient Email: $patientEmail');
    _log('Password: ${password.replaceAll(RegExp(r'.'), '*')}');
    _log('Platform: ${_getPlatformName()}');
    _log('');

    // Validate email format
    if (!_isValidEmail(patientEmail)) {
      _log('Invalid email format: $patientEmail', isError: true);
      return EmailResult(
        success: false,
        message: 'Invalid email address format.',
      );
    }

    final message = Message()
      ..from = Address(_senderEmail, _senderName)
      ..recipients.add(patientEmail)
      ..subject = 'Welcome to DermaScan - Your Patient Account Credentials'
      ..html = _buildPatientCredentialsHtml(patientName, patientEmail, password);

    return _sendViaSmtp(message: message, recipientEmail: patientEmail);
  }

  // ╔═══════════════════════════════════════════════════════════════════════╗
  // ║  PUBLIC API: SEND APPOINTMENT CONFIRMATION                            ║
  // ╚═══════════════════════════════════════════════════════════════════════╝
  
  /// Send appointment confirmation email to patient
  static Future<EmailResult> sendAppointmentConfirmation({
    required String patientName,
    required String patientEmail,
    required String doctorName,
    required int tokenNumber,
    required String date,
    required String timeSlot,
  }) async {
    _log('');
    _log('╔═══════════════════════════════════════════════════════════════╗');
    _log('║        SENDING APPOINTMENT CONFIRMATION EMAIL                 ║');
    _log('╚═══════════════════════════════════════════════════════════════╝');
    _log('Patient: $patientName ($patientEmail)');
    _log('Doctor: Dr. $doctorName');
    _log('Token #$tokenNumber | Date: $date | Time: $timeSlot');
    _log('Platform: ${_getPlatformName()}');
    _log('');

    // Validate email format
    if (!_isValidEmail(patientEmail)) {
      _log('Invalid email format: $patientEmail', isError: true);
      return EmailResult(
        success: false,
        message: 'Invalid email address format.',
      );
    }

    final message = Message()
      ..from = Address(_senderEmail, _senderName)
      ..recipients.add(patientEmail)
      ..subject = 'Appointment Confirmed - Token #$tokenNumber'
      ..html = _buildAppointmentHtml(patientName, doctorName, tokenNumber, date, timeSlot);

    return _sendViaSmtp(message: message, recipientEmail: patientEmail);
  }

  // ╔═══════════════════════════════════════════════════════════════════════╗
  // ║  DEBUGGING UTILITY: TEST EMAIL                                        ║
  // ╚═══════════════════════════════════════════════════════════════════════╝
  
  /// Test email functionality - useful for debugging
  static Future<EmailResult> testEmailConfiguration({required String testEmail}) async {
    _log('');
    _log('╔═══════════════════════════════════════════════════════════════╗');
    _log('║              TESTING EMAIL CONFIGURATION                      ║');
    _log('╚═══════════════════════════════════════════════════════════════╝');
    _log('Test Email: $testEmail');
    _log('Platform: ${_getPlatformName()}');
    _log('');
    _log('Configuration Status:');
    _log('  - Sender Email: $_senderEmail');
    _log('  - Sender Name: $_senderName');
    _log('  - SMTP Password: ${_senderPassword.isNotEmpty ? "Configured (${_senderPassword.length} chars)" : "NOT CONFIGURED"}');
    _log('  - SMTP Host: smtp.gmail.com');
    _log('  - SMTP Port: 465 (SSL)');
    _log('  - Connection Timeout: $_connectionTimeout seconds');
    _log('');

    return sendPatientCredentials(
      patientName: 'Test User',
      patientEmail: testEmail,
      password: 'TestPassword123',
    );
  }

  // ╔═══════════════════════════════════════════════════════════════════════╗
  // ║  UTILITY FUNCTIONS                                                    ║
  // ╚═══════════════════════════════════════════════════════════════════════╝
  
  static bool _isValidEmail(String email) {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(email);
  }

  static String _getPlatformName() {
    if (kIsWeb) return 'Web (NOT SUPPORTED)';
    try {
      if (Platform.isAndroid) return 'Android';
      if (Platform.isIOS) return 'iOS';
      if (Platform.isWindows) return 'Windows';
      if (Platform.isMacOS) return 'macOS';
      if (Platform.isLinux) return 'Linux';
    } catch (_) {}
    return 'Unknown';
  }

  // ╔═══════════════════════════════════════════════════════════════════════╗
  // ║  HTML TEMPLATES                                                       ║
  // ╚═══════════════════════════════════════════════════════════════════════╝
  
  static String _buildDoctorCredentialsHtml(String doctorName, String doctorEmail, String password) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="margin: 0; padding: 0; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f0f4f8;">
  <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
    <div style="background: linear-gradient(135deg, #4FD1C5 0%, #38B2AC 100%); padding: 40px 30px; border-radius: 20px 20px 0 0; text-align: center;">
      <h1 style="color: white; margin: 0; font-size: 28px; font-weight: 600;">Welcome to DermaScan!</h1>
      <p style="color: rgba(255,255,255,0.9); margin: 10px 0 0 0; font-size: 16px;">Your Doctor Account is Ready</p>
    </div>
    
    <div style="background: white; padding: 40px 30px; border-radius: 0 0 20px 20px; box-shadow: 0 10px 40px rgba(0,0,0,0.1);">
      <p style="font-size: 17px; color: #2D3748; margin: 0 0 20px 0;">Dear <strong>Dr. $doctorName</strong>,</p>
      
      <p style="font-size: 15px; color: #4A5568; line-height: 1.6; margin: 0 0 25px 0;">
        Your doctor account has been successfully created at DermaScan Clinic. 
        Please use the following credentials to login to the DermaScan app:
      </p>
      
      <div style="background: linear-gradient(135deg, #f7fafc 0%, #edf2f7 100%); border-radius: 16px; padding: 25px; margin: 25px 0; border-left: 4px solid #4FD1C5;">
        <div style="margin-bottom: 15px;">
          <span style="color: #718096; font-size: 13px; text-transform: uppercase; letter-spacing: 0.5px;">📧 Email (Username)</span>
          <p style="margin: 5px 0 0 0; font-size: 18px; color: #4FD1C5; font-weight: 600;">$doctorEmail</p>
        </div>
        <div>
          <span style="color: #718096; font-size: 13px; text-transform: uppercase; letter-spacing: 0.5px;">🔐 Password</span>
          <p style="margin: 5px 0 0 0; font-size: 18px; font-family: 'Courier New', monospace; background: white; padding: 8px 12px; border-radius: 8px; display: inline-block; color: #2D3748;">$password</p>
        </div>
      </div>
      
      <div style="background: #FFFAF0; border-radius: 12px; padding: 20px; margin: 25px 0; border: 1px solid #F6E05E;">
        <p style="margin: 0; color: #744210; font-size: 14px; line-height: 1.6;">
          <strong>⚠️ Security Notice:</strong><br>
          Please change your password after your first login for security purposes.<br>
          Navigate to: <strong>Settings → Change Password</strong>
        </p>
      </div>
      
      <p style="font-size: 14px; color: #718096; margin: 25px 0 0 0;">
        If you have any questions or need assistance, please contact the clinic administration.
      </p>
      
      <hr style="border: none; border-top: 1px solid #E2E8F0; margin: 30px 0;">
      
      <p style="font-size: 13px; color: #A0AEC0; text-align: center; margin: 0;">
        Best regards,<br>
        <strong style="color: #4A5568;">DermaScan Clinic Team</strong>
      </p>
    </div>
  </div>
</body>
</html>
    ''';
  }

  static String _buildPatientCredentialsHtml(String patientName, String patientEmail, String password) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="margin: 0; padding: 0; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f0f4f8;">
  <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
    <div style="background: linear-gradient(135deg, #4FD1C5 0%, #38B2AC 100%); padding: 40px 30px; border-radius: 20px 20px 0 0; text-align: center;">
      <h1 style="color: white; margin: 0; font-size: 28px; font-weight: 600;">Welcome to DermaScan!</h1>
      <p style="color: rgba(255,255,255,0.9); margin: 10px 0 0 0; font-size: 16px;">Your Patient Account is Ready</p>
    </div>
    
    <div style="background: white; padding: 40px 30px; border-radius: 0 0 20px 20px; box-shadow: 0 10px 40px rgba(0,0,0,0.1);">
      <p style="font-size: 17px; color: #2D3748; margin: 0 0 20px 0;">Dear <strong>$patientName</strong>,</p>
      
      <p style="font-size: 15px; color: #4A5568; line-height: 1.6; margin: 0 0 25px 0;">
        Your patient account has been successfully created at DermaScan Clinic. 
        Please use the following credentials to login to the DermaScan app:
      </p>
      
      <div style="background: linear-gradient(135deg, #f7fafc 0%, #edf2f7 100%); border-radius: 16px; padding: 25px; margin: 25px 0; border-left: 4px solid #4FD1C5;">
        <div style="margin-bottom: 15px;">
          <span style="color: #718096; font-size: 13px; text-transform: uppercase; letter-spacing: 0.5px;">📧 Email (Username)</span>
          <p style="margin: 5px 0 0 0; font-size: 18px; color: #4FD1C5; font-weight: 600;">$patientEmail</p>
        </div>
        <div>
          <span style="color: #718096; font-size: 13px; text-transform: uppercase; letter-spacing: 0.5px;">🔐 Password</span>
          <p style="margin: 5px 0 0 0; font-size: 18px; font-family: 'Courier New', monospace; background: white; padding: 8px 12px; border-radius: 8px; display: inline-block; color: #2D3748;">$password</p>
        </div>
      </div>
      
      <div style="background: #FFFAF0; border-radius: 12px; padding: 20px; margin: 25px 0; border: 1px solid #F6E05E;">
        <p style="margin: 0; color: #744210; font-size: 14px; line-height: 1.6;">
          <strong>⚠️ Security Notice:</strong><br>
          Please change your password after your first login.<br>
          Navigate to: <strong>Settings → Change Password</strong>
        </p>
      </div>
      
      <p style="font-size: 14px; color: #718096; margin: 25px 0 0 0;">
        If you have any questions, please contact the clinic.
      </p>
      
      <hr style="border: none; border-top: 1px solid #E2E8F0; margin: 30px 0;">
      
      <p style="font-size: 13px; color: #A0AEC0; text-align: center; margin: 0;">
        Best regards,<br>
        <strong style="color: #4A5568;">DermaScan Clinic Team</strong>
      </p>
    </div>
  </div>
</body>
</html>
    ''';
  }

  static String _buildAppointmentHtml(String patientName, String doctorName, int tokenNumber, String date, String timeSlot) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="margin: 0; padding: 0; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f0f4f8;">
  <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
    <div style="background: linear-gradient(135deg, #4FD1C5 0%, #38B2AC 100%); padding: 40px 30px; border-radius: 20px 20px 0 0; text-align: center;">
      <h1 style="color: white; margin: 0; font-size: 28px; font-weight: 600;">Appointment Confirmed!</h1>
      <p style="color: rgba(255,255,255,0.9); margin: 10px 0 0 0; font-size: 16px;">Your booking is confirmed</p>
    </div>
    
    <div style="background: white; padding: 40px 30px; border-radius: 0 0 20px 20px; box-shadow: 0 10px 40px rgba(0,0,0,0.1);">
      <p style="font-size: 17px; color: #2D3748; margin: 0 0 20px 0;">Dear <strong>$patientName</strong>,</p>
      
      <p style="font-size: 15px; color: #4A5568; line-height: 1.6; margin: 0 0 25px 0;">
        Your appointment has been successfully booked at DermaScan Clinic.
      </p>
      
      <!-- Token Number Card -->
      <div style="background: linear-gradient(135deg, #4FD1C5 0%, #38B2AC 100%); border-radius: 16px; padding: 30px; margin: 25px 0; text-align: center;">
        <p style="margin: 0; color: rgba(255,255,255,0.8); font-size: 14px; text-transform: uppercase; letter-spacing: 1px;">Your Token Number</p>
        <p style="margin: 10px 0; font-size: 56px; font-weight: 700; color: white;">#$tokenNumber</p>
      </div>
      
      <!-- Appointment Details -->
      <div style="background: #f7fafc; border-radius: 16px; padding: 25px; margin: 25px 0;">
        <div style="margin-bottom: 15px;">
          <span style="font-size: 16px;">📅 <strong>Date:</strong> $date</span>
        </div>
        <div style="margin-bottom: 15px;">
          <span style="font-size: 16px;">🕐 <strong>Time Slot:</strong> $timeSlot</span>
        </div>
        <div>
          <span style="font-size: 16px;">👨‍⚕️ <strong>Doctor:</strong> Dr. $doctorName</span>
        </div>
      </div>
      
      <div style="background: #C6F6D5; border-radius: 12px; padding: 20px; margin: 25px 0; border: 1px solid #9AE6B4;">
        <p style="margin: 0; color: #22543D; font-size: 14px; line-height: 1.6;">
          <strong>📍 Reminder:</strong><br>
          Please arrive 10 minutes before your scheduled appointment time.
        </p>
      </div>
      
      <hr style="border: none; border-top: 1px solid #E2E8F0; margin: 30px 0;">
      
      <p style="font-size: 13px; color: #A0AEC0; text-align: center; margin: 0;">
        Best regards,<br>
        <strong style="color: #4A5568;">DermaScan Clinic Team</strong>
      </p>
    </div>
  </div>
</body>
</html>
    ''';
  }
}

/// Result class for email operations
class EmailResult {
  final bool success;
  final String message;

  EmailResult({required this.success, required this.message});

  @override
  String toString() => 'EmailResult(success: $success, message: $message)';
}
