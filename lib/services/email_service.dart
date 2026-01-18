import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

/// Email Service for sending emails via SMTP
/// 
/// IMPORTANT: For Gmail, you need to:
/// 1. Enable 2-Factor Authentication on your Gmail account
/// 2. Generate an "App Password" at: https://myaccount.google.com/apppasswords
/// 3. Use that App Password (not your regular password) below
/// 
/// For other email providers, use their SMTP settings

class EmailService {
  // ============ CONFIGURE YOUR EMAIL SETTINGS HERE ============
  // Replace these with your actual email credentials
  static const String _senderEmail = 'your-email@gmail.com'; // Your email
  static const String _senderPassword = 'your-app-password';  // Gmail App Password (16 chars)
  static const String _senderName = 'DermaScan Clinic';
  
  // Gmail SMTP Server (change if using different provider)
  static SmtpServer get _smtpServer => gmail(_senderEmail, _senderPassword);
  
  // For other providers:
  // static SmtpServer get _smtpServer => SmtpServer(
  //   'smtp.yourprovider.com',
  //   port: 587,
  //   username: _senderEmail,
  //   password: _senderPassword,
  //   ssl: false,
  //   allowInsecure: true,
  // );
  // ============================================================

  /// Send email to doctor with login credentials
  static Future<EmailResult> sendDoctorCredentials({
    required String doctorName,
    required String doctorEmail,
    required String password,
  }) async {
    final message = Message()
      ..from = Address(_senderEmail, _senderName)
      ..recipients.add(doctorEmail)
      ..subject = 'Welcome to DermaScan - Your Doctor Account Credentials'
      ..html = '''
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
          <div style="background: linear-gradient(135deg, #4FD1C5 0%, #38B2AC 100%); padding: 30px; border-radius: 15px 15px 0 0; text-align: center;">
            <h1 style="color: white; margin: 0;">Welcome to DermaScan!</h1>
          </div>
          
          <div style="background: #f8f9fa; padding: 30px; border-radius: 0 0 15px 15px;">
            <p style="font-size: 16px; color: #333;">Dear <strong>Dr. $doctorName</strong>,</p>
            
            <p style="font-size: 15px; color: #555;">Your doctor account has been successfully created. Please use the following credentials to login to the DermaScan app:</p>
            
            <div style="background: white; border-radius: 10px; padding: 20px; margin: 20px 0; border-left: 4px solid #4FD1C5;">
              <p style="margin: 10px 0;"><strong>📧 Email:</strong> <span style="color: #4FD1C5;">$doctorEmail</span></p>
              <p style="margin: 10px 0;"><strong>🔐 Password:</strong> <span style="font-family: monospace; background: #e9ecef; padding: 3px 8px; border-radius: 4px;">$password</span></p>
            </div>
            
            <div style="background: #fff3cd; border-radius: 8px; padding: 15px; margin: 20px 0;">
              <p style="margin: 0; color: #856404;">
                <strong>⚠️ Security Notice:</strong><br>
                Please change your password after your first login.<br>
                Go to: <strong>Settings → Change Password</strong>
              </p>
            </div>
            
            <p style="font-size: 14px; color: #666;">If you have any questions, please contact the clinic administration.</p>
            
            <hr style="border: none; border-top: 1px solid #ddd; margin: 25px 0;">
            
            <p style="font-size: 13px; color: #888; text-align: center;">
              Best regards,<br>
              <strong>DermaScan Clinic Team</strong>
            </p>
          </div>
        </div>
      ''';

    try {
      final sendReport = await send(message, _smtpServer);
      return EmailResult(
        success: true,
        message: 'Email sent successfully to $doctorEmail',
      );
    } on MailerException catch (e) {
      return EmailResult(
        success: false,
        message: 'Failed to send email: ${e.message}',
      );
    } catch (e) {
      return EmailResult(
        success: false,
        message: 'Error: $e',
      );
    }
  }

  /// Send appointment confirmation to patient
  static Future<EmailResult> sendAppointmentConfirmation({
    required String patientName,
    required String patientEmail,
    required String doctorName,
    required int tokenNumber,
    required String date,
    required String timeSlot,
  }) async {
    final message = Message()
      ..from = Address(_senderEmail, _senderName)
      ..recipients.add(patientEmail)
      ..subject = 'Appointment Confirmed - Token #$tokenNumber'
      ..html = '''
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
          <div style="background: linear-gradient(135deg, #4FD1C5 0%, #38B2AC 100%); padding: 30px; border-radius: 15px 15px 0 0; text-align: center;">
            <h1 style="color: white; margin: 0;">Appointment Confirmed!</h1>
          </div>
          
          <div style="background: #f8f9fa; padding: 30px; border-radius: 0 0 15px 15px;">
            <p style="font-size: 16px; color: #333;">Dear <strong>$patientName</strong>,</p>
            
            <p style="font-size: 15px; color: #555;">Your appointment has been successfully booked.</p>
            
            <div style="background: white; border-radius: 10px; padding: 20px; margin: 20px 0; text-align: center; border: 2px solid #4FD1C5;">
              <p style="margin: 0; color: #888; font-size: 14px;">Token Number</p>
              <h2 style="margin: 10px 0; font-size: 48px; color: #4FD1C5;">#$tokenNumber</h2>
            </div>
            
            <div style="background: white; border-radius: 10px; padding: 20px; margin: 20px 0;">
              <p style="margin: 10px 0;"><strong>📅 Date:</strong> $date</p>
              <p style="margin: 10px 0;"><strong>🕐 Time:</strong> $timeSlot</p>
              <p style="margin: 10px 0;"><strong>👨‍⚕️ Doctor:</strong> Dr. $doctorName</p>
            </div>
            
            <div style="background: #d4edda; border-radius: 8px; padding: 15px; margin: 20px 0;">
              <p style="margin: 0; color: #155724;">
                <strong>📍 Reminder:</strong><br>
                Please arrive 10 minutes before your appointment time.
              </p>
            </div>
            
            <hr style="border: none; border-top: 1px solid #ddd; margin: 25px 0;">
            
            <p style="font-size: 13px; color: #888; text-align: center;">
              Best regards,<br>
              <strong>DermaScan Clinic Team</strong>
            </p>
          </div>
        </div>
      ''';

    try {
      await send(message, _smtpServer);
      return EmailResult(
        success: true,
        message: 'Email sent successfully to $patientEmail',
      );
    } on MailerException catch (e) {
      return EmailResult(
        success: false,
        message: 'Failed to send email: ${e.message}',
      );
    } catch (e) {
      return EmailResult(
        success: false,
        message: 'Error: $e',
      );
    }
  }
}

class EmailResult {
  final bool success;
  final String message;

  EmailResult({required this.success, required this.message});
}
