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
  
  // 🔹 PROFILE PHOTO STATE
  File? _profileImage;
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
      'reports': 'Reports & Timeline',
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
    },
    'Malayalam': {
      'welcome': 'സ്വാഗതം,',
      'hello': 'ഹലോ',
      'help': 'ഇന്ന് ഞങ്ങൾക്ക് എങ്ങനെ സഹായിക്കാനാകും?',
      'dashboard': 'ഡാഷ്‌ബോർഡ്',
      'reminders': 'ഓർമ്മപ്പെടുത്തലുകൾ',
      'book_appoint': 'അപ്പോയിന്റ്മെന്റ് ബുക്ക് ചെയ്യുക',
      'view_appoint': 'അപ്പോയിന്റ്മെന്റ് കാണുക',
      'reports': 'റിപ്പോർട്ടുകളും ടൈംലൈനും',
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

          if (userDoc.data()?['name'] != null) {
            setState(() {
              _patientName = _capitalize(userDoc['name']);
            });
          }
        } else {
          // 2. Fallback to 'patients' collection if 'users' doc is missing 
          // (Legacy support, but still check if it exists)
          final patientDoc = await FirebaseFirestore.instance.collection('patients').doc(user.uid).get();
          if (patientDoc.exists && patientDoc.data()?['name'] != null) {
            setState(() {
              _patientName = _capitalize(patientDoc['name']);
            });
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
      }
    });
  }

  void _showNotificationsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                      Text(
                        "Upcoming Appointments",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        "Your scheduled visits",
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_upcomingAppointments.isEmpty)
              _buildNoAppointmentsMessage()
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _upcomingAppointments.length > 5 ? 5 : _upcomingAppointments.length,
                  itemBuilder: (ctx, index) => _buildNotificationCard(_upcomingAppointments[index], index == 0),
                ),
              ),
          ],
        ),
      ),
    );
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


  // 📸 Pick image from camera
  Future<void> _pickImageFromCamera() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 500,
        maxHeight: 500,
      );
      if (image != null) {
        setState(() {
          _profileImage = File(image.path);
        });
        Navigator.pop(context); // Close the bottom sheet
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Profile photo updated!'),
              ],
            ),
            backgroundColor: accentColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // 🖼️ Pick image from gallery
  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 500,
        maxHeight: 500,
      );
      if (image != null) {
        setState(() {
          _profileImage = File(image.path);
        });
        Navigator.pop(context); // Close the bottom sheet
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Profile photo updated!'),
              ],
            ),
            backgroundColor: accentColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // 📋 Show photo picker options
  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
              "Change Profile Photo",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "Choose how you want to update your photo",
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _photoOptionCard(
                    icon: Icons.camera_alt_rounded,
                    label: "Camera",
                    color: accentColor,
                    onTap: _pickImageFromCamera,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _photoOptionCard(
                    icon: Icons.photo_library_rounded,
                    label: "Gallery",
                    color: const Color(0xFF8B5CF6),
                    onTap: _pickImageFromGallery,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_profileImage != null)
              TextButton.icon(
                onPressed: () {
                  setState(() => _profileImage = null);
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.delete_rounded, color: Colors.red),
                label: const Text("Remove Photo", style: TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _photoOptionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 36, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            child: IconButton(
              icon: Badge(
                label: Text(
                  '${_upcomingAppointments.length}',
                  style: const TextStyle(fontSize: 10),
                ),
                isLabelVisible: _upcomingAppointments.isNotEmpty,
                backgroundColor: Colors.orange,
                child: Icon(
                  _upcomingAppointments.isNotEmpty 
                      ? Icons.notifications_active_rounded 
                      : Icons.notifications_none_rounded,
                  color: _upcomingAppointments.isNotEmpty ? accentColor : textColor,
                ),
              ),
              onPressed: _showNotificationsSheet,
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
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accentColor, accentColor.withOpacity(0.7)],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _showPhotoOptions,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 38,
                          backgroundColor: Colors.white24,
                          backgroundImage: _profileImage != null 
                              ? FileImage(_profileImage!) 
                              : null,
                          child: _profileImage == null
                              ? const Icon(Icons.person, color: Colors.white, size: 40)
                              : null,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: accentColor, width: 2),
                            ),
                            child: Icon(Icons.camera_alt_rounded, size: 16, color: accentColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _patientName,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    "Tap photo to change",
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),

          /// Drawer List Items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _drawerTile(Icons.home_rounded, _t('home'), () => Navigator.pop(context)),
                ///_drawerTile(Icons.person_outline_rounded, "My Profile", () {}),
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
                      (route) => false
                    );
                  }
                }, color: Colors.redAccent),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text("v1.0.0", style: TextStyle(color: Colors.grey[400], fontSize: 12)),
          )
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
  }) {
    return Container(
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