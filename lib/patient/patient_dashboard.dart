import 'package:dermascan/landing_page.dart';
import 'package:dermascan/patient/patient_appointment.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  @override
  void initState() {
    super.initState();
    _fetchPatientName();
  }

  Future<void> _fetchPatientName() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('patients')
            .doc(user.uid)
            .get();

        if (doc.exists && doc.data()?['name'] != null) {
          setState(() {
            _patientName = doc['name'];
          });
        }
      }
    } catch (e) {
      print("Error fetching patient name: $e");
    }
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
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () {},
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
              "Hello, $_patientName!",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor),
            ),
            Text(
              "How can we help you today?",
              style: TextStyle(fontSize: 15, color: Colors.grey[600]),
            ),
            const SizedBox(height: 25),


            /// 1. BOOK APPOINTMENT
            _dashboardCard(
              title: "Book Appointment",
              subtitle: "Schedule a visit with a specialist",
              image: "assets/appointment.webp", 
              icon: Icons.event_available_rounded,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PatientAppointmentPage()),
              ),
            ),

            /// 2. MY REPORTS
            _dashboardCard(
              title: "Medical Reports",
              subtitle: "Access your history and AI results",
              image: "assets/rept.jpg", 
              icon: Icons.assignment_outlined,
              onTap: () {},
            ),

            /// 1. VIEW REMINDERS
            _dashboardCard(
              title: "View Reminders",
              subtitle: "Check appointments and medication alerts",
              image: "assets/rmdr.jpg",
             icon: Icons.notifications_active_outlined,
             onTap: () {
             // Navigate to reminders page
          },
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
          /// Drawer Header
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
                  const CircleAvatar(
                    radius: 35,
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.person, color: Colors.white, size: 40),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Patient Account",
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
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
                _drawerTile(Icons.home_rounded, "Home", () => Navigator.pop(context)),
                ///_drawerTile(Icons.person_outline_rounded, "My Profile", () {}),
                _drawerTile(Icons.language_rounded, "Language", () {}),
                _drawerTile(Icons.contact_support_outlined, "Contact Us", () {}),
                _drawerTile(Icons.description_outlined, "Terms & Conditions", () {}),
                const Divider(indent: 20, endIndent: 20),
                _drawerTile(Icons.logout_rounded, "Logout", () {
                  Navigator.pushAndRemoveUntil(
                    context, 
                    MaterialPageRoute(builder: (_) => const LandingPage()), 
                    (route) => false
                  );
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