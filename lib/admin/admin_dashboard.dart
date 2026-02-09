import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dermascan/admin/view_revenue.dart';
import 'package:dermascan/admin/view_doctors.dart';
import 'package:dermascan/admin/view_patients.dart';
import 'package:dermascan/admin/view_users.dart';
import 'package:dermascan/admin/settings_page.dart';
import 'package:dermascan/admin/view_today_appointments.dart';
import 'package:dermascan/admin/skin_scanner.dart';
import 'package:dermascan/admin/appointments_page.dart';
import 'package:dermascan/doctor/view_feedbacks_page.dart';


class ClinicStaffDashboard extends StatefulWidget {
  const ClinicStaffDashboard({super.key});

  @override
  State<ClinicStaffDashboard> createState() => _ClinicStaffDashboardState();
}

class _ClinicStaffDashboardState extends State<ClinicStaffDashboard> {
  // 🎨 Modern Color Palette
  static const Color primaryColor = Color(0xFF4FD1C5);
  static const Color primaryDark = Color(0xFF38B2AC);
  static const Color bgColor = Color(0xFFF8FAFC);
  static const Color cardColor = Colors.white;
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);
  
  static const Color purpleAccent = Color(0xFF8B5CF6);
  static const Color blueAccent = Color(0xFF3B82F6);
  static const Color orangeAccent = Color(0xFFF59E0B);
  static const Color pinkAccent = Color(0xFFEC4899);
  static const Color greenAccent = Color(0xFF10B981);
  
  int _selectedNavIndex = 0;

  // Dashboard data
  int _todayAppointments = 0;
  int _totalDoctors = 0;
  int _totalPatients = 0;
  int _patientsInQueue = 0;
  bool _isLoading = true;
  String _greeting = '';
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _setGreeting();
    _loadDashboardData();
  }
  
  void _setGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      _greeting = 'Good Morning';
    } else if (hour < 17) {
      _greeting = 'Good Afternoon';
    } else {
      _greeting = 'Good Evening';
    }
  }
  
  Future<void> _loadDashboardData() async {
    try {
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      final todayEnd = todayStart.add(const Duration(days: 1));
      final todayStartTs = Timestamp.fromDate(todayStart);
      final todayEndTs = Timestamp.fromDate(todayEnd);
      
      final results = await Future.wait([
        _firestore.collection('doctors').count().get(),
        _firestore.collection('patients').count().get(),
        _firestore.collection('appointments')
            .where('appodate', isGreaterThanOrEqualTo: todayStartTs)
            .where('appodate', isLessThan: todayEndTs)
            .get(),
      ]);
      
      _totalDoctors = (results[0] as AggregateQuerySnapshot).count ?? 0;
      _totalPatients = (results[1] as AggregateQuerySnapshot).count ?? 0;
      
      final todaySnapshot = results[2] as QuerySnapshot;
      final todayDocs = todaySnapshot.docs.map((doc) => doc.data() as Map).toList();
      
      // Today appointments excluding cancelled
      _todayAppointments = todayDocs.where((data) => data['status'] != 'Cancelled').length;
      
      // Patients in queue (Booked or Waiting)
      _patientsInQueue = todayDocs.where((data) {
        final status = data['status'];
        return status == 'Waiting' || status == 'Booked';
      }).length;
      
    } catch (e) {
      debugPrint('Error loading dashboard: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: _isLoading 
            ? const Center(child: CircularProgressIndicator(color: primaryColor))
            : IndexedStack(
                index: _selectedNavIndex,
                children: [
                  // Tab 0: Home/Dashboard
                  RefreshIndicator(
                    onRefresh: _loadDashboardData,
                    color: primaryColor,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(),
                          _buildQuickStats(),
                          _buildMainActionCard(),
                          _buildQuickActionsGrid(),
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
                  // Tab 1: Schedule - All Appointments with date filter
                  AppointmentsPage(
                    isDoctor: false,
                    onBackPressed: () {
                      setState(() => _selectedNavIndex = 0);
                      _loadDashboardData();
                    },
                  ),
                  // Tab 2: Scan - with back button
                  _buildTabWithBackButton(
                    child: _buildScanContent(),
                  ),
                  // Tab 3: Settings - with back button
                  _buildTabWithBackButton(
                    child: const SettingsPage(),
                  ),
                ],
              ),
      ),
      bottomNavigationBar: _buildBottomNav(),
      extendBody: true,
    );
  }

  Widget _buildTabWithBackButton({required Widget child}) {
    return Stack(
      children: [
        child,
        // Back button overlay
        Positioned(
          top: 10,
          left: 16,
          child: GestureDetector(
            onTap: () {
              setState(() => _selectedNavIndex = 0);
              _loadDashboardData();
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: textPrimary),
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildScanContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main Scanner Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [primaryColor, primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt_rounded, size: 48, color: Colors.white),
                ),
                const SizedBox(height: 20),
                const Text(
                  "AI Skin Scanner",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  "Analyze skin conditions using AI-powered detection",
                  style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.9)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SkinScannerPage()),
                      );
                    },
                    icon: const Icon(Icons.add_a_photo_rounded, size: 22),
                    label: const Text("Start New Scan", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: primaryDark,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          
          const SizedBox(height: 28),
          
          // Recent Scans
          const Text(
            "Recent Scans",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
          ),
          const SizedBox(height: 16),
          
          _buildRecentScansSection(),
        ],
      ),
    );
  }



  Widget _buildRecentScansSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('predictions')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: primaryColor));
        }
        
        final scans = snapshot.data?.docs ?? [];
        
        if (scans.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.biotech_rounded, size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  const Text("No scans yet", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary)),
                  const SizedBox(height: 4),
                  Text("Recent scans will appear here", style: TextStyle(color: Colors.grey.shade500)),
                ],
              ),
            ),
          );
        }
        
        return Column(
          children: scans.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final patientName = data['patientName'] ?? 'Unknown';
            final prediction = data['prediction'] ?? 'Unknown';
            final createdAt = data['createdAt'] as Timestamp?;
            String dateStr = 'N/A';
            if (createdAt != null) {
              final dt = createdAt.toDate();
              dateStr = '${dt.day}/${dt.month}/${dt.year}';
            }
            
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade100),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: greenAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.biotech_rounded, color: greenAccent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(patientName, style: const TextStyle(fontWeight: FontWeight.w600, color: textPrimary), overflow: TextOverflow.ellipsis),
                        Text(prediction, style: TextStyle(fontSize: 12, color: Colors.grey.shade600), overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Text(dateStr, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }


  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_greeting, style: const TextStyle(fontSize: 14, color: textSecondary, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              const Text("Clinic Dashboard", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: textPrimary)),
            ],
          ),
          _buildIconButton(Icons.notifications_outlined, () {
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No new notifications'), behavior: SnackBarBehavior.floating));
          }),
        ],
      ),
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 2))],
        ),
        child: Icon(icon, color: textPrimary, size: 22),
      ),
    );
  }

  Widget _buildQuickStats() {
    return Container(
      height: 100,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          _buildStatCard("Today", "$_todayAppointments", "Appointments", primaryColor),
          const SizedBox(width: 12),
          _buildStatCard("In Queue", "$_patientsInQueue", "Patients", orangeAccent),
          const SizedBox(width: 12),
          _buildStatCard("Total", "$_totalDoctors", "Doctors", purpleAccent),
        ],
      ),
    );
  }
  
  Widget _buildStatCard(String label, String value, String subtitle, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: textSecondary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            Text(subtitle, style: const TextStyle(fontSize: 10, color: textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildMainActionCard() {
    return GestureDetector(
      key: const ValueKey('view_today_schedule'),
      onTap: () async {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const ViewTodayAppointmentsPage()));
        _loadDashboardData();
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [primaryColor, primaryDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: primaryColor.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10))],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                    child: const Text("📅 TODAY", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1)),
                  ),
                  const SizedBox(height: 14),
                  const Text("Appointments\n& Queue", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white, height: 1.2)),
                  const SizedBox(height: 8),
                  Text("Register patients and manage the daily queue", style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.9))),
                  const SizedBox(height: 16),
                  _buildWhiteButton("Open Schedule"),
                ],
              ),
            ),
            _buildCircularIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _buildWhiteButton(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, style: const TextStyle(color: primaryDark, fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(width: 6),
          const Icon(Icons.arrow_forward_rounded, color: primaryDark, size: 18),
        ],
      ),
    );
  }

  Widget _buildCircularIndicator() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text("$_todayAppointments", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
          const Text("Appts", style: TextStyle(fontSize: 10, color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildQuickActionsGrid() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Quick Actions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary)),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildActionTile("Doctors", Icons.medical_services_rounded, blueAccent, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ViewDoctorsPage()))),
              const SizedBox(width: 12),
              _buildActionTile("Patients", Icons.people_rounded, pinkAccent, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ViewPatientsPage()))),
              const SizedBox(width: 12),
              _buildActionTile("Revenue", Icons.payments_rounded, greenAccent, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ViewRevenuePage()))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildActionTile("All Users", Icons.group_rounded, orangeAccent, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ViewUsersPage()))),
              const SizedBox(width: 12),
              _buildActionTile("Feedbacks", Icons.rate_review_rounded, purpleAccent, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ViewFeedbacksPage(isDoctor: false)))),
              const SizedBox(width: 12),
              Expanded(child: Container()), // Spacer
            ],
          ),
        ],
      ),
    );
  }

  
  Widget _buildActionTile(String label, IconData icon, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade100),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 10),
              Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: textPrimary, // Darker nav bar for high contrast
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(Icons.grid_view_rounded, "Home", 0),
          _buildNavItem(Icons.calendar_today_rounded, "Schedule", 1),
          _buildNavItem(Icons.camera_rounded, "Scan", 2),
          _buildNavItem(Icons.settings_rounded, "Settings", 3),
        ],
      ),
    );
  }
  
  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _selectedNavIndex == index;
    final String keyVal = index == 0 ? 'nav_home' : index == 1 ? 'nav_schedule' : index == 2 ? 'nav_scan' : 'nav_settings';
    
    return GestureDetector(
      key: ValueKey(keyVal),
      onTap: () {
        if (index == _selectedNavIndex) return;
        setState(() => _selectedNavIndex = index);
        
        // Refresh data when returning to home
        if (index == 0) {
          _loadDashboardData();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.white60, size: 22),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ],
        ),
      ),
    );
  }
}