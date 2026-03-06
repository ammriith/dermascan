import 'dart:io';
import 'package:dermascan/landing_page.dart';
import 'package:dermascan/patient/patient_appointment.dart';
import 'package:dermascan/patient/patient_medical_history.dart';
import 'package:dermascan/patient/patient_reminders.dart';
import 'package:dermascan/patient/view_appointment.dart';
import 'package:dermascan/patient/feedback_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dermascan/services/notification_service.dart';
import 'package:firebase_storage/firebase_storage.dart';

class PatientDashboard extends StatefulWidget {
  const PatientDashboard({super.key});

  @override
  State<PatientDashboard> createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<PatientDashboard> {
  // 🔹 THEME COLORS (Consistent with Login/Register)
  final Color accentColor = const Color(0xFF4FD1C5); 
  final Color bgColor = const Color(0xFFF8FAFC); 
  final Color textColor = const Color(0xFF1F2937); 
  final Color drawerBg = Colors.white;

  // 🔹 PATIENT NAME STATE
  String _patientName = "Patient";
  bool _isLoadingProfile = false;
  
  // 🔹 PROFILE PHOTO STATE
  File? _profileImage;
  String? _profileImageUrl;
  final ImagePicker _imagePicker = ImagePicker();

  // 🔹 UPCOMING APPOINTMENTS STATE
  List<Map<String, dynamic>> _upcomingAppointments = [];
  Map<String, dynamic>? _nextAppointment;

  // 🔹 LANGUAGE STATE
  String _selectedLanguage = 'English'; 

  final Map<String, Map<String, String>> _translations = {
    'English': {
      'welcome': 'Welcome back,',
      'hello': 'Hello',
      'help': 'How can we help you today?',
      'dashboard': 'Dashboard',
      'reminders': 'Reminders',
      'book_appoint': 'Book Appointment',
      'view_appoint': 'View Appointment',
      'reports': 'Reports',
      'language': 'Language',
      'logout': 'Logout',
      'home': 'Home',
      'contact': 'Contact Us',
      'terms': 'Terms & Conditions',
      'select_lang': 'Select Language',
      'upcoming_title': 'Upcoming Appointments',
      'upcoming_subtitle': 'Your scheduled visits',
      'notification': 'Notification',
      'manage_visits': 'Check and manage your scheduled visits',
      'history_ai': 'View your reports and medical timeline',
      'med_alerts': 'Medications & doctor suggestions',
      'patient': 'Patient',
      'tap_to_change': 'Tap photo to change',
    },
    'Malayalam': {
      'welcome': 'സ്വാഗതം,',
      'hello': 'ഹലോ',
      'help': 'ഇന്ന് ഞങ്ങൾക്ക് എങ്ങനെ സഹായിക്കാനാകും?',
      'dashboard': 'ഡാഷ്‌ബോർഡ്',
      'reminders': 'ഓർമ്മപ്പെടുത്തലുകൾ',
      'book_appoint': 'അപ്പോയിന്റ്മെന്റ് ബുക്ക് ചെയ്യുക',
      'view_appoint': 'അപ്പോയിന്റ്മെന്റ് കാണുക',
      'reports': 'റിപ്പോർട്ടുകളും ',
      'language': 'ഭാഷ',
      'logout': 'പുറത്തിറങ്ങുക',
      'home': 'ഹോം',
      'contact': 'ഞങ്ങളെ ബന്ധപ്പെടുക',
      'terms': 'നിബന്ധനകളും വ്യവസ്ഥകളും',
      'select_lang': 'ഭാഷ തിരഞ്ഞെടുക്കുക',
      'upcoming_title': 'വരാനിരിക്കുന്ന അപ്പോയിന്റ്മെന്റുകൾ',
      'upcoming_subtitle': 'നിങ്ങളുടെ ഷെഡ്യൂൾ ചെയ്ത സന്ദർശനങ്ങൾ',
      'notification': 'അറിയിപ്പ്',
      'manage_visits': 'നിങ്ങളുടെ അപ്പോയിന്റ്‌മെന്റുകൾ പരിശോധിക്കുക',
      'history_ai': 'റിപ്പോർട്ടുകളും മെഡിക്കൽ ടൈംലൈനും കാണുക',
      'med_alerts': 'മരുന്നുകളും ഡോക്ടറുടെ നിർദ്ദേശങ്ങളും',
      'patient': 'രോഗി',
      'tap_to_change': 'മാറ്റാൻ ഫോട്ടോ ടാപ്പ് ചെയ്യുക',
    }
  };

  String _t(String key) => _translations[_selectedLanguage]?[key] ?? key;

  @override
  void initState() {
    super.initState();
    _fetchPatientName();
    _loadUpcomingAppointments();
  }

  Future<void> _fetchPatientName() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // 1. Fetch from 'users' collection (master source)
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

        if (userDoc.exists) {
          // 🛡️ SECURITY CHECK: Verify user role is 'patient'
          final role = userDoc.data()?['userRole']?.toString().toLowerCase();
          if (role != 'patient') {
            debugPrint("Unauthorized access: User role is $role, not patient.");
            _handleUnauthorized();
            return;
          }

          if (mounted) {
            setState(() {
              if (userDoc.data()?['name'] != null) {
                _patientName = _capitalize(userDoc['name']);
              }
              _profileImageUrl = userDoc.data()?['profileImageUrl'];
            });
          }
        } else {
          // 2. Fallback to 'patients' collection if 'users' doc is missing 
          // (Legacy support, but still check if it exists)
          final patientDoc = await FirebaseFirestore.instance.collection('patients').doc(user.uid).get();
          if (patientDoc.exists) {
            if (mounted) {
              setState(() {
                if (patientDoc.data()?['name'] != null) {
                  _patientName = _capitalize(patientDoc['name']);
                }
                _profileImageUrl = patientDoc.data()?['profileImageUrl'];
              });
            }
          } else {
            // If user exists in Auth but not in 'users' or 'patients' collections
            debugPrint("User profile not found in database.");
          }
        }
      }
    } catch (e) {
      debugPrint("Error in role and name fetching: $e");
    }
  }

  void _handleUnauthorized() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LandingPage()),
        (route) => false,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Unauthorized access. Please login as a patient."),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              "Profile Photo",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _photoOptionItem(
                  icon: Icons.camera_alt_rounded,
                  label: "Camera",
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
                _photoOptionItem(
                  icon: Icons.photo_library_rounded,
                  label: "Gallery",
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
                if (_profileImageUrl != null || _profileImage != null)
                  _photoOptionItem(
                    icon: Icons.delete_outline_rounded,
                    label: "Delete",
                    color: Colors.redAccent,
                    onTap: () {
                      Navigator.pop(context);
                      _deleteProfilePicture();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _photoOptionItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (color ?? accentColor).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color ?? accentColor, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color ?? Colors.grey.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );

      if (pickedFile != null) {
        setState(() => _isLoadingProfile = true);
        await _updateProfilePicture(File(pickedFile.path));
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
      _showErrorSnackBar("Failed to pick image");
    } finally {
      setState(() => _isLoadingProfile = false);
    }
  }

  Future<void> _updateProfilePicture(File image) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // 1. Upload to Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_pictures')
          .child('${user.uid}.jpg');

      await storageRef.putFile(image);
      final downloadUrl = await storageRef.getDownloadURL();

      // 2. Update Firestore (both collections for consistency)
      final batch = FirebaseFirestore.instance.batch();
      
      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      batch.update(userRef, {'profileImageUrl': downloadUrl});
      
      final patientRef = FirebaseFirestore.instance.collection('patients').doc(user.uid);
      final patientDoc = await patientRef.get();
      if (patientDoc.exists) {
        batch.update(patientRef, {'profileImageUrl': downloadUrl});
      }

      await batch.commit();

      if (mounted) {
        setState(() {
          _profileImage = image;
          _profileImageUrl = downloadUrl;
        });
        _showSuccessPopup();
      }
    } catch (e) {
      debugPrint("Error updating profile picture: $e");
      _showErrorSnackBar("Failed to update profile picture");
    }
  }

  Future<void> _deleteProfilePicture() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      setState(() => _isLoadingProfile = true);

      // 1. Remove from Storage
      try {
        await FirebaseStorage.instance
            .ref()
            .child('profile_pictures')
            .child('${user.uid}.jpg')
            .delete();
      } catch (e) {
        // Storage might be empty, just continue
        debugPrint("Storage delete error (safe to ignore if file doesn't exist): $e");
      }

      // 2. Update Firestore
      final batch = FirebaseFirestore.instance.batch();
      
      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      batch.update(userRef, {'profileImageUrl': FieldValue.delete()});
      
      final patientRef = FirebaseFirestore.instance.collection('patients').doc(user.uid);
      final patientDoc = await patientRef.get();
      if (patientDoc.exists) {
        batch.update(patientRef, {'profileImageUrl': FieldValue.delete()});
      }

      await batch.commit();

      if (mounted) {
        setState(() {
          _profileImage = null;
          _profileImageUrl = null;
        });
        _showSuccessSnackBar("Profile picture deleted");
      }
    } catch (e) {
      debugPrint("Error deleting profile picture: $e");
      _showErrorSnackBar("Failed to delete profile picture");
    } finally {
      setState(() => _isLoadingProfile = false);
    }
  }

  void _showSuccessPopup() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 50),
            ),
            const SizedBox(height: 20),
            const Text(
              "Success!",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              "Profile updated successfully",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Awesome", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  void _loadUpcomingAppointments() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    FirebaseFirestore.instance
        .collection('appointments')
        .where('patientId', isEqualTo: user.uid)
        .snapshots()
        .listen((snapshot) {
      final now = DateTime.now();
      final appointments = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).where((a) {
        final date = (a['appodate'] as Timestamp?)?.toDate();
        final status = a['status'] ?? '';
        return date != null && 
               date.isAfter(now) && 
               status != 'Completed' && 
               status != 'Cancelled';
      }).toList();

      // Sort by date
      appointments.sort((a, b) {
        final aDate = (a['appodate'] as Timestamp?)?.toDate() ?? DateTime.now();
        final bDate = (b['appodate'] as Timestamp?)?.toDate() ?? DateTime.now();
        return aDate.compareTo(bDate);
      });

      if (mounted) {
        setState(() {
          _upcomingAppointments = appointments;
          _nextAppointment = appointments.isNotEmpty ? appointments.first : null;
        });

        // Trigger proximity notifications for any appointment in the next 24 hours
        for (var appointment in appointments) {
          final date = (appointment['appodate'] as Timestamp?)?.toDate();
          if (date != null) {
            NotificationService().checkAndNotifyProximity(
              id: appointment['id'],
              title: '📅 Appointment Soon',
              body: 'You have an appointment with Dr. ${appointment['doctorName'] ?? 'Doctor'} at ${appointment['timeSlot'] ?? 'soon'}',
              scheduledTime: date,
            );
          }
        }
      }
    });
  }

  void _showNotificationsSheet() {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.72,
        maxChildSize: 0.92,
        minChildSize: 0.4,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.notifications_active_rounded, color: accentColor),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Notifications", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text("Scan results & updates", style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => _markAllPatientNotificationsRead(userId),
                      child: Text("Mark all read", style: TextStyle(color: accentColor, fontSize: 12)),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Combined notification list
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('patient_notifications')
                      .where('patientId', isEqualTo: userId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    final scanDocs = snapshot.data?.docs ?? [];
                    final sorted = scanDocs.toList()
                      ..sort((a, b) {
                        final aT = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                        final bT = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                        if (aT == null || bT == null) return 0;
                        return bT.compareTo(aT);
                      });

                    if (sorted.isEmpty && _upcomingAppointments.isEmpty) {
                      return _buildNoAppointmentsMessage();
                    }

                    return ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      children: [
                        // Scan result notifications
                        ...sorted.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final isRead = data['isRead'] == true;
                          final severity = data['severity'] ?? 'N/A';
                          final createdAt = data['createdAt'] as Timestamp?;

                          Color severityColor;
                          final sevL = severity.toString().toLowerCase();
                          if (sevL.contains('critical') || sevL.contains('severe')) {
                            severityColor = Colors.red;
                          } else if (sevL.contains('moderate')) {
                            severityColor = Colors.orange;
                          } else {
                            severityColor = const Color(0xFF10B981);
                          }

                          return GestureDetector(
                            onTap: () async {
                              await doc.reference.update({'isRead': true});
                              if (ctx.mounted) Navigator.pop(ctx);
                              if (mounted) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const PatientMedicalHistoryPage()),
                                );
                              }
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isRead ? Colors.white : accentColor.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isRead ? Colors.grey.shade200 : accentColor.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.biotech_rounded, color: Color(0xFF10B981), size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Expanded(
                                              child: Text(
                                                "Skin Scan Result Ready",
                                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                            if (!isRead)
                                              Container(
                                                width: 8, height: 8,
                                                decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          "Condition: ${data['prediction'] ?? 'Unknown'}",
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: severityColor.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(severity, style: TextStyle(fontSize: 10, color: severityColor, fontWeight: FontWeight.bold)),
                                            ),
                                            const Spacer(),
                                            Text(
                                              createdAt != null ? _formatNotifDate(createdAt.toDate()) : '',
                                              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "Tap to view full report →",
                                          style: TextStyle(fontSize: 11, color: accentColor, fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),

                        // Upcoming appointments section
                        if (_upcomingAppointments.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text("Upcoming Appointments", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
                          ),
                          ...List.generate(
                            _upcomingAppointments.length > 3 ? 3 : _upcomingAppointments.length,
                            (i) => _buildNotificationCard(_upcomingAppointments[i], i == 0),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatNotifDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Future<void> _markAllPatientNotificationsRead(String userId) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('patient_notifications')
          .where('patientId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error marking notifications read: $e');
    }
  }

  Widget _buildNoAppointmentsMessage() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 40),
          ),
          const SizedBox(height: 16),
          const Text(
            "No Upcoming Appointments",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            "Book an appointment to get started",
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> appointment, bool isNext) {
    final doctorName = appointment['doctorName'] ?? 'Doctor';
    final specialization = appointment['specialization'] ?? 'Specialist';
    final timeSlot = appointment['timeSlot'] ?? '';
    final appodate = appointment['appodate'] as Timestamp?;
    
    String dateStr = 'N/A';
    String dayStr = '';
    String countdown = '';
    
    if (appodate != null) {
      final date = appodate.toDate();
      dateStr = '${date.day}/${date.month}/${date.year}';
      
      final diff = date.difference(DateTime.now());
      if (diff.inDays == 0) {
        dayStr = 'Today';
        countdown = '${diff.inHours}h left';
      } else if (diff.inDays == 1) {
        dayStr = 'Tomorrow';
        countdown = '1 day left';
      } else {
        dayStr = '${diff.inDays} days';
        countdown = '${diff.inDays} days left';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isNext ? accentColor.withValues(alpha: 0.05) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isNext ? accentColor.withValues(alpha: 0.3) : Colors.grey.shade200,
          width: isNext ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                doctorName.isNotEmpty ? doctorName[0].toUpperCase() : 'D',
                style: TextStyle(color: accentColor, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Dr. $doctorName",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isNext)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          "NEXT",
                          style: TextStyle(fontSize: 9, color: Colors.orange, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                Text(specialization, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 12, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text("$dayStr • $timeSlot", style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        countdown,
                        style: TextStyle(fontSize: 10, color: accentColor, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('patient_dashboard'),
      backgroundColor: bgColor,
      
      /// 🔹 APP BAR
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textColor),
        title: Text(
          "Dermascan",
          style: TextStyle(
            color: accentColor, 
            fontWeight: FontWeight.bold, 
            letterSpacing: 1.2
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('patient_notifications')
                  .where('patientId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                  .where('isRead', isEqualTo: false)
                  .snapshots(),
              builder: (context, snapshot) {
                final unread = snapshot.data?.docs.length ?? 0;
                return IconButton(
                  icon: Badge(
                    label: Text('$unread', style: const TextStyle(fontSize: 10)),
                    isLabelVisible: unread > 0,
                    backgroundColor: Colors.red,
                    child: Icon(
                      unread > 0
                          ? Icons.notifications_active_rounded
                          : Icons.notifications_none_rounded,
                      color: unread > 0 ? accentColor : textColor,
                    ),
                  ),
                  onPressed: _showNotificationsSheet,
                );
              },
            ),
          ),
        ],
      ),

      /// 🔹 LEFT SIDE HAMBURGER MENU (Updated with your requested features)
      drawer: _buildCustomDrawer(context),

      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// WELCOME SECTION
            Text(
              "${_t('hello')}, $_patientName!",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor),
            ),
            Text(
              _t('help'),
              style: TextStyle(fontSize: 15, color: Colors.grey[600]),
            ),
            const SizedBox(height: 25),


            /// 1. BOOK APPOINTMENT
            _dashboardCard(
              title: _t('book_appoint'),
              key: const ValueKey('book_appointment_button'),
              subtitle: "Schedule a visit with a specialist",
              image: "assets/appointment.jpg",
              icon: Icons.add_task_rounded,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PatientAppointmentPage()),
              ),
            ),
 
            /// 2. View Appointment
            _dashboardCard(
            title: _t('view_appoint'),
            subtitle: _t('manage_visits'),
            image: "assets/vappoint.jpg",
            icon: Icons.event_available_rounded,
            onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
            builder: (_) => const ViewAppointmentPage(),
         ),
        ),
       ),
   
            /// 3. MY REPORTS
            _dashboardCard(
              title: _t('reports'),
              subtitle: _t('history_ai'),
              image: "assets/rept.jpg",
              icon: Icons.analytics_outlined,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PatientMedicalHistoryPage()),
              ),
            ),
 
            /// 4. VIEW REMINDERS
            _dashboardCard(
              title: _t('reminders'),
              subtitle: _t('med_alerts'),
              image: "assets/rmdr.jpg",
              icon: Icons.notifications_active_outlined,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PatientRemindersPage()),
              ),
            ),

            /// 5. GIVE FEEDBACK
            _dashboardCard(
              title: _selectedLanguage == 'Malayalam' ? 'ഫീഡ്ബാക്ക് നൽകുക' : 'Give Feedback',
              subtitle: _selectedLanguage == 'Malayalam' ? 'നിങ്ങളുടെ അനുഭവം പങ്കിടുക' : 'Share your experience with us',
              image: "assets/feedback.jpg",
              icon: Icons.rate_review_rounded,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FeedbackPage()),
              ),
            ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// 🔹 CUSTOM HAMBURGER MENU
  Widget _buildCustomDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: drawerBg,
      child: Column(
        children: [
          /// Drawer Header with tappable profile photo
          DrawerHeader(
            padding: EdgeInsets.zero,
            margin: EdgeInsets.zero,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accentColor, accentColor.withValues(alpha: 0.85)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _showPhotoOptions,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircleAvatar(
                          radius: 38,
                          backgroundColor: Colors.white24,
                          backgroundImage: _profileImage != null 
                              ? FileImage(_profileImage!) 
                              : (_profileImageUrl != null && _profileImageUrl!.isNotEmpty 
                                  ? NetworkImage(_profileImageUrl!) 
                                  : null) as ImageProvider?,
                          child: _profileImage == null && (_profileImageUrl == null || _profileImageUrl!.isEmpty)
                              ? const Icon(Icons.person_rounded, color: Colors.white, size: 45)
                              : null,
                        ),
                        if (_isLoadingProfile)
                          Positioned.fill(
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.black26, 
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: SizedBox(
                                  width: 40, 
                                  height: 40,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 4,
                                ),
                              ],
                              border: Border.all(color: accentColor, width: 2),
                            ),
                            child: Icon(Icons.camera_alt_rounded, size: 14, color: accentColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _patientName.isNotEmpty 
                        ? _patientName 
                        : (FirebaseAuth.instance.currentUser?.displayName ?? _t('patient')),
                    style: const TextStyle(
                      color: Colors.white, 
                      fontSize: 18, 
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    _t('tap_to_change'),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8), 
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 8),

          /// Drawer List Items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _drawerTile(Icons.home_rounded, _t('home'), () => Navigator.pop(context)),
                _drawerTile(Icons.language_rounded, _t('language'), _showLanguageDialog),
                _drawerTile(Icons.contact_support_outlined, _t('contact'), _showContactUs),
                _drawerTile(Icons.description_outlined, _t('terms'), _showTermsAndConditions),
                const Divider(indent: 20, endIndent: 20),
                _drawerTile(Icons.logout_rounded, _t('logout'), () async {
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context, 
                      MaterialPageRoute(builder: (_) => const LandingPage()), 
                      (route) => false,
                    );
                  }
                }, color: Colors.redAccent),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text("v1.0.0", style: TextStyle(color: Colors.grey[400], fontSize: 12)),
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.language_rounded, color: accentColor),
                ),
                const SizedBox(width: 14),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Select Language",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      "ഭാഷ തിരഞ്ഞെടുക്കുക",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            _languageOption("English", "English", _selectedLanguage == 'English'),
            const SizedBox(height: 12),
            _languageOption("Malayalam", "മലയാളം", _selectedLanguage == 'Malayalam'),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _languageOption(String title, String subtitle, bool isSelected) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedLanguage = title;
        });
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(title == 'Malayalam' ? "ഭാഷ മലയാളത്തിലേക്ക് മാറ്റി" : "Language changed to English"),
            backgroundColor: accentColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? accentColor.withOpacity(0.05) : Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? accentColor.withOpacity(0.3) : Colors.grey[200]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: accentColor)
            else
              const Icon(Icons.circle_outlined, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  void _showContactUs() {
    Navigator.pop(context); // Close the drawer first
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.contact_support_rounded, color: accentColor, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedLanguage == 'Malayalam' ? "ഞങ്ങളെ ബന്ധപ്പെടുക" : "Contact Us",
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        _selectedLanguage == 'Malayalam' ? "ഞങ്ങൾ സഹായിക്കാൻ ഇവിടെയുണ്ട്" : "We're here to help",
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildContactItem(
              Icons.email_rounded,
              _selectedLanguage == 'Malayalam' ? "ഇമെയിൽ" : "Email",
              "support@dermascan.com",
              accentColor,
            ),
            _buildContactItem(
              Icons.phone_rounded,
              _selectedLanguage == 'Malayalam' ? "ഫോൺ" : "Phone",
              "+91 1234567890",
              Colors.green,
            ),
            _buildContactItem(
              Icons.access_time_rounded,
              _selectedLanguage == 'Malayalam' ? "പ്രവർത്തന സമയം" : "Working Hours",
              "Mon - Sat, 9:00 AM - 6:00 PM",
              Colors.orange,
            ),
            _buildContactItem(
              Icons.location_on_rounded,
              _selectedLanguage == 'Malayalam' ? "വിലാസം" : "Address",
              "123 Health Street, Medical City, India",
              Colors.purple,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildContactItem(IconData icon, String title, String subtitle, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showTermsAndConditions() {
    Navigator.pop(context); // Close the drawer first
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.description_rounded, color: accentColor, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    _selectedLanguage == 'Malayalam' ? "നിബന്ധനകളും വ്യവസ്ഥകളും" : "Terms & Conditions",
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTermsSection(
                      "1. Acceptance of Terms",
                      "By accessing and using the Dermascan application, you agree to be bound by these Terms and Conditions. If you do not agree to these terms, please do not use the app.",
                    ),
                    _buildTermsSection(
                      "2. Medical Disclaimer",
                      "Dermascan is intended for informational purposes only and does not provide medical advice. The AI analysis is not a substitute for professional medical diagnosis. Always consult a qualified healthcare provider for medical conditions.",
                    ),
                    _buildTermsSection(
                      "3. User Account",
                      "You are responsible for maintaining the confidentiality of your account credentials. You must provide accurate and complete information during registration.",
                    ),
                    _buildTermsSection(
                      "4. Privacy Policy",
                      "Your personal and medical information is protected under our Privacy Policy. We do not share your data with third parties without your consent.",
                    ),
                    _buildTermsSection(
                      "5. Appointment Booking",
                      "Appointments booked through the app are subject to availability. Cancellation policies may apply as per the healthcare provider's terms.",
                    ),
                    _buildTermsSection(
                      "6. Limitation of Liability",
                      "Dermascan shall not be liable for any direct, indirect, incidental, or consequential damages arising from the use of this application.",
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        "Last updated: January 2026",
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTermsSection(String title, String content) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 6),
          Text(
            content,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }

  /// 🔹 DRAWER TILE HELPER
  Widget _drawerTile(IconData icon, String title, VoidCallback onTap, {Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? accentColor),
      title: Text(
        title, 
        style: TextStyle(color: color ?? textColor, fontWeight: FontWeight.w600, fontSize: 15)
      ),
      onTap: onTap,
    );
  }

  /// 🔹 DASHBOARD CARD COMPONENT
  Widget _dashboardCard({
    required String title,
    required String subtitle,
    required String image,
    required IconData icon,
    required VoidCallback onTap,
    Key? key,
  }) {
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: Image.asset(
                image,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 160,
                  color: accentColor.withOpacity(0.05),
                  child: Icon(icon, size: 40, color: accentColor),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(Icons.arrow_forward_ios_rounded, color: accentColor.withOpacity(0.4), size: 18),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}