import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  bool _notificationsEnabled = true;

  bool get isEnabled => _notificationsEnabled;

  /// Initialize the notification service
  Future<void> init() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request Android 13+ notification permission
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // Load saved preference
    final prefs = await SharedPreferences.getInstance();
    _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;

    _isInitialized = true;
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
  }

  /// Toggle notifications on/off and persist preference
  Future<void> setEnabled(bool enabled) async {
    _notificationsEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notificationsEnabled', enabled);

    if (!enabled) {
      await _plugin.cancelAll();
    }
  }

  /// Show an instant notification
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_notificationsEnabled) return;

    const androidDetails = AndroidNotificationDetails(
      'dermascan_general',
      'Dermascan Notifications',
      channelDescription: 'General notifications for Dermascan',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF4FD1C5),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }

  /// Show notification for a new appointment
  Future<void> notifyNewAppointment({
    required String patientName,
    required String doctorName,
    required String date,
    required String time,
  }) async {
    await showNotification(
      title: '📅 New Appointment Booked',
      body: '$patientName with Dr. $doctorName on $date at $time',
      payload: 'appointment_new',
    );
  }

  /// Show notification for appointment status change
  Future<void> notifyAppointmentStatus({
    required String patientName,
    required String status,
  }) async {
    final emoji = status == 'Completed' ? '✅' : status == 'Cancelled' ? '❌' : '🔄';
    await showNotification(
      title: '$emoji Appointment $status',
      body: 'Appointment for $patientName has been $status',
      payload: 'appointment_status',
    );
  }

  /// Show notification for scan results
  Future<void> notifyScanComplete({
    required String patientName,
    required String result,
  }) async {
    await showNotification(
      title: '🔬 Scan Results Ready',
      body: 'Scan for $patientName: $result',
      payload: 'scan_result',
    );
  }

  /// Show notification for new patient registration
  Future<void> notifyNewPatient({required String patientName}) async {
    await showNotification(
      title: '👤 New Patient Registered',
      body: '$patientName has been registered successfully',
      payload: 'patient_new',
    );
  }

  /// Show proximity notification for upcoming events
  Future<void> checkAndNotifyProximity({
    required String id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    if (!_notificationsEnabled) return;

    final now = DateTime.now();
    final diff = scheduledTime.difference(now);

    // Only notify if within the next 24 hours and not in the past
    if (diff.inMinutes > 0 && diff.inHours < 24) {
      final prefs = await SharedPreferences.getInstance();
      final lastNotifiedKey = 'notified_$id';
      final lastNotified = prefs.getString(lastNotifiedKey);
      
      // Only notify once per 12 hours for the same item to avoid spam
      if (lastNotified == null || 
          now.difference(DateTime.parse(lastNotified)).inHours >= 12) {
        
        await showNotification(
          title: title,
          body: body,
          payload: id,
        );
        
        await prefs.setString(lastNotifiedKey, now.toIso8601String());
      }
    }
  }

  /// Listen for new appointments in realtime and trigger notifications
  void listenForNewAppointments() {
    if (!_notificationsEnabled) return;

    FirebaseFirestore.instance
        .collection('appointments')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docChanges.isNotEmpty) {
        final change = snapshot.docChanges.first;
        if (change.type == DocumentChangeType.added && _notificationsEnabled) {
          final data = change.doc.data();
          if (data != null) {
            // Avoid notifying for very old records that might trigger on initial load
            final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
            if (createdAt != null && DateTime.now().difference(createdAt).inMinutes < 5) {
              notifyNewAppointment(
                patientName: data['patientName'] ?? 'Patient',
                doctorName: data['doctorName'] ?? 'Doctor',
                date: data['date'] ?? '',
                time: data['time'] ?? '',
              );
            }
          }
        }
      }
    });
  }
}
