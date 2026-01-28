import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dermascan/doctor/doctor_slots_page.dart';
import 'package:dermascan/doctor/patient_reports.dart';
import 'package:dermascan/doctor/view_feedbacks_page.dart';
import 'package:dermascan/doctor/doctor_edit_profile.dart';
import 'package:dermascan/admin/appointments_page.dart';
import 'package:dermascan/admin/change_password_page.dart';

class DoctorDashboard extends StatefulWidget {
  const DoctorDashboard({super.key});

  @override
  State<DoctorDashboard> createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard> {
  // 🎨 Modern Color Palette (Same as Admin Dashboard)
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

  // Doctor data
  String _doctorName = '';
  String _specialization = '';
  int _todayAppointments = 0;
  int _totalPatients = 0;
  int _completedToday = 0;
  int _pendingToday = 0;
  bool _isLoading = true;
  String _greeting = '';
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  List<Map<String, dynamic>> _todayAppointmentsList = [];
  Map<String, dynamic>? _nextPatient;

  @override
  void initState() {
    super.initState();
    _setGreeting();
    _loadDoctorData();
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
  
  Future<void> _loadDoctorData() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;
      
      final doctorDoc = await _firestore.collection('doctors').doc(userId).get();
      if (doctorDoc.exists) {
        final data = doctorDoc.data()!;
        _doctorName = data['name'] ?? 'Doctor';
        _specialization = data['specialization'] ?? 'Dermatologist';
      }
      
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      final todayEnd = todayStart.add(const Duration(days: 1));
      
      // Fetch all appointments and filter on client side to support both field naming conventions
      final allAppointmentsSnapshot = await _firestore.collection('appointments').get();
      
      // Filter for this doctor's appointments today (support both doctorId and doctor_id)
      _todayAppointmentsList = allAppointmentsSnapshot.docs.where((doc) {
        final data = doc.data();
        final docId = data['doctorId'] ?? data['doctor_id'];
        final appodate = data['appodate'] as Timestamp?;
        
        if (docId != userId) return false;
        if (appodate == null) return false;
        
        final dt = appodate.toDate();
        return dt.isAfter(todayStart.subtract(const Duration(seconds: 1))) && dt.isBefore(todayEnd);
      }).map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
      
      // Sort by appointment time
      _todayAppointmentsList.sort((a, b) {
        final aTime = (a['appodate'] as Timestamp?)?.toDate() ?? DateTime.now();
        final bTime = (b['appodate'] as Timestamp?)?.toDate() ?? DateTime.now();
        return aTime.compareTo(bTime);
      });
      
      _todayAppointments = _todayAppointmentsList.length;
      _completedToday = _todayAppointmentsList.where((a) => a['status'] == 'Completed').length;
      _pendingToday = _todayAppointmentsList.where((a) => 
        a['status'] == 'Waiting' || a['status'] == 'Booked' || a['status'] == 'In Progress'
      ).length;
      
      // Find next patient (Waiting first, then Booked)
      final waitingPatients = _todayAppointmentsList.where((a) => a['status'] == 'Waiting').toList();
      final bookedPatients = _todayAppointmentsList.where((a) => a['status'] == 'Booked').toList();
      
      if (waitingPatients.isNotEmpty) {
        _nextPatient = waitingPatients.first;
      } else if (bookedPatients.isNotEmpty) {
        _nextPatient = bookedPatients.first;
      } else {
        _nextPatient = null;
      }
      
      // Calculate total unique patients
      final uniquePatients = <String>{};
      for (var doc in allAppointmentsSnapshot.docs) {
        final data = doc.data();
        final docId = data['doctorId'] ?? data['doctor_id'];
        final patientId = data['patientId'] ?? data['patient_id'];
        if (docId == userId && patientId != null) {
          uniquePatients.add(patientId);
        }
      }
      _totalPatients = uniquePatients.length;
      
    } catch (e) {
      debugPrint('Error loading doctor data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateAppointmentStatus(String appointmentId, String newStatus) async {
    try {
      await _firestore.collection('appointments').doc(appointmentId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Appointment marked as $newStatus'),
          backgroundColor: greenAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      
      _loadDoctorData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _auth.signOut();
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
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
                  _buildHomeTab(),
                  _buildReportsTab(),
                  AppointmentsPage(
                    isDoctor: true,
                    onBackPressed: () => setState(() => _selectedNavIndex = 0),
                  ), // Doctor's appointments with date filter
                  _buildProfileTab(),
                ],
              ),
      ),
      bottomNavigationBar: _buildBottomNav(),
      extendBody: true,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 0: HOME DASHBOARD
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildHomeTab() {
    return RefreshIndicator(
      onRefresh: _loadDoctorData,
      color: primaryColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            _buildOverviewCards(),
            _buildNextPatientCard(),
            _buildTodayAppointmentsCard(),
            _buildQuickActionsGrid(),
            _buildUpcomingAppointments(),
            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_greeting, style: const TextStyle(fontSize: 14, color: textSecondary, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(
                  "Dr. $_doctorName",
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(_specialization, style: const TextStyle(fontSize: 13, color: primaryColor, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Row(
            children: [
              _buildIconButton(Icons.notifications_outlined, () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No new notifications'), behavior: SnackBarBehavior.floating),
                );
              }),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => setState(() => _selectedNavIndex = 3),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [primaryColor, primaryDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      _doctorName.isNotEmpty ? _doctorName[0].toUpperCase() : 'D',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
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

  Widget _buildOverviewCards() {
    return Container(
      height: 100,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          _buildStatCard("Today", "$_todayAppointments", "Appointments", primaryColor),
          const SizedBox(width: 12),
          _buildStatCard("Pending", "$_pendingToday", "Patients", orangeAccent),
          const SizedBox(width: 12),
          _buildStatCard("Completed", "$_completedToday", "Today", greenAccent),
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

  Widget _buildNextPatientCard() {
    if (_nextPatient == null) {
      return Container(
        margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: greenAccent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: greenAccent.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: greenAccent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.check_circle_rounded, color: greenAccent, size: 24),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("No Patients Waiting", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textPrimary)),
                  SizedBox(height: 2),
                  Text("All patients have been attended", style: TextStyle(fontSize: 12, color: textSecondary)),
                ],
              ),
            ),
          ],
        ),
      );
    }
    
    final patientName = _nextPatient!['patientName'] ?? _nextPatient!['patient_name'] ?? 'Unknown';
    final status = _nextPatient!['status'] ?? 'Waiting';
    final timeSlot = _nextPatient!['timeSlot'] ?? _nextPatient!['time_slot'] ?? '';
    final appodate = _nextPatient!['appodate'] as Timestamp?;
    
    String timeStr = timeSlot;
    if (timeStr.isEmpty && appodate != null) {
      final dt = appodate.toDate();
      timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [orangeAccent, orangeAccent.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: orangeAccent.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                patientName.isNotEmpty ? patientName[0].toUpperCase() : 'P',
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "NEXT PATIENT",
                  style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
                const SizedBox(height: 4),
                Text(
                  patientName,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                if (timeStr.isNotEmpty)
                  Text(
                    "$timeStr • $status",
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status,
              style: const TextStyle(color: orangeAccent, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayAppointmentsCard() {
    return GestureDetector(
      onTap: () => setState(() => _selectedNavIndex = 2),
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
                    child: const Text("📅 TODAY'S SCHEDULE", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1)),
                  ),
                  const SizedBox(height: 14),
                  const Text("Your\nAppointments", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white, height: 1.2)),
                  const SizedBox(height: 8),
                  Text(
                    _pendingToday > 0 
                        ? "$_pendingToday patients waiting to be seen"
                        : "No pending appointments",
                    style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.9)),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("View All", style: TextStyle(color: primaryDark, fontWeight: FontWeight.w700, fontSize: 14)),
                        SizedBox(width: 6),
                        Icon(Icons.arrow_forward_rounded, color: primaryDark, size: 18),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("$_todayAppointments", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                  const Text("appt", style: TextStyle(fontSize: 10, color: Colors.white70)),
                ],
              ),
            ),
          ],
        ),
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
              _buildActionTile(
                "Reports",
                Icons.description_rounded,
                purpleAccent,
                () => setState(() => _selectedNavIndex = 1),
              ),
              const SizedBox(width: 12),
              _buildActionTile(
                "Schedule",
                Icons.calendar_today_rounded,
                blueAccent,
                () => setState(() => _selectedNavIndex = 2),
              ),
              const SizedBox(width: 12),
              _buildActionTile(
                "Feedbacks",
                Icons.rate_review_rounded,
                greenAccent,
                () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ViewFeedbacksPage(isDoctor: true))),
              ),
              const SizedBox(width: 12),
              _buildActionTile(
                "Slots",
                Icons.more_time_rounded,
                orangeAccent,
                () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DoctorSlotsPage())),
              ),
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

  Widget _buildUpcomingAppointments() {
    final upcoming = _todayAppointmentsList.where((a) => 
      a['status'] == 'Waiting' || a['status'] == 'Booked' || a['status'] == 'In Progress'
    ).take(3).toList();
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Next Patients", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary)),
              if (upcoming.isNotEmpty)
                GestureDetector(
                  onTap: () => setState(() => _selectedNavIndex = 2),
                  child: const Text("See All", style: TextStyle(fontSize: 13, color: primaryColor, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (upcoming.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade100),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.check_circle_outline_rounded, size: 48, color: greenAccent.withValues(alpha: 0.5)),
                    const SizedBox(height: 12),
                    const Text("All Done!", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary)),
                    const SizedBox(height: 4),
                    const Text("No pending patients for today", style: TextStyle(fontSize: 13, color: textSecondary)),
                  ],
                ),
              ),
            )
          else
            ...upcoming.map((appointment) => _buildAppointmentCard(appointment)),
        ],
      ),
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> appointment) {
    final patientName = appointment['patientName'] ?? 'Unknown Patient';
    final status = appointment['status'] ?? 'Booked';
    final appointmentTime = appointment['appodate'];
    String timeStr = '--:--';
    
    if (appointmentTime != null && appointmentTime is Timestamp) {
      final dt = appointmentTime.toDate();
      timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    
    Color statusColor;
    switch (status) {
      case 'Waiting':
        statusColor = orangeAccent;
        break;
      case 'In Progress':
        statusColor = blueAccent;
        break;
      case 'Completed':
        statusColor = greenAccent;
        break;
      default:
        statusColor = textSecondary;
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                patientName.isNotEmpty ? patientName[0].toUpperCase() : 'P',
                style: const TextStyle(color: primaryColor, fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(patientName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textPrimary), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.access_time_rounded, size: 14, color: textSecondary),
                        const SizedBox(width: 4),
                        Text(timeStr, style: const TextStyle(fontSize: 12, color: textSecondary)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(status, style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (status != 'Completed')
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: textSecondary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (value) => _updateAppointmentStatus(appointment['id'], value),
              itemBuilder: (ctx) => [
                if (status == 'Waiting' || status == 'Booked')
                  const PopupMenuItem(value: 'In Progress', child: Text('Start Consultation')),
                const PopupMenuItem(value: 'Completed', child: Text('Mark as Completed')),
              ],
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 1: REPORTS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildReportsTab() {
    return Stack(
      children: [
        const PatientReportsPage(),
        // Back button overlay
        Positioned(
          top: 10,
          left: 16,
          child: GestureDetector(
            onTap: () {
              setState(() => _selectedNavIndex = 0);
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

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 3: PROFILE
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildProfileTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 100),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _selectedNavIndex = 0),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: textPrimary),
                  ),
                ),
                const SizedBox(width: 16),
                const Text("Profile", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textPrimary)),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [primaryColor, primaryDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: primaryColor.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10))],
            ),
            child: Row(
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Text(
                      _doctorName.isNotEmpty ? _doctorName[0].toUpperCase() : 'D',
                      style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Dr. $_doctorName", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white), overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(_specialization, style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.9))),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text("✓ Verified", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSettingsSection(),
        ],
      ),
    );
  }

  Widget _buildSettingsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Settings", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary)),
          const SizedBox(height: 16),
          _buildSettingsTile(Icons.person_outline_rounded, "Edit Profile", () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DoctorEditProfilePage()),
            );
            if (result == true) {
              _loadDoctorData(); // Refresh profile data
            }
          }),
          _buildSettingsTile(Icons.notifications_outlined, "Notifications", () {
            _showNotificationSettings();
          }),
          _buildSettingsTile(Icons.lock_outline_rounded, "Change Password", () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
            );
          }),
          _buildSettingsTile(Icons.help_outline_rounded, "Help & Support", () {
            _showHelpSupport();
          }),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _logout,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout_rounded, color: Colors.red.shade600),
                  const SizedBox(width: 8),
                  Text("Logout", style: TextStyle(color: Colors.red.shade600, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showNotificationSettings() {
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
            const Text("Notification Settings", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textPrimary)),
            const SizedBox(height: 20),
            _buildNotificationToggle("Appointment Reminders", true),
            _buildNotificationToggle("New Patient Alerts", true),
            _buildNotificationToggle("Feedback Notifications", true),
            _buildNotificationToggle("Email Notifications", false),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationToggle(String title, bool defaultValue) {
    return StatefulBuilder(
      builder: (context, setLocalState) {
        bool isEnabled = defaultValue;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 15, color: textPrimary)),
              Switch(
                value: isEnabled,
                onChanged: (val) => setLocalState(() => isEnabled = val),
                activeColor: primaryColor,
              ),
            ],
          ),
        );
      },
    );
  }

  void _showHelpSupport() {
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
            const Text("Help & Support", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textPrimary)),
            const SizedBox(height: 20),
            _buildHelpItem(Icons.email_outlined, "Email Support", "support@dermascan.com"),
            _buildHelpItem(Icons.phone_outlined, "Phone Support", "+91 1234567890"),
            _buildHelpItem(Icons.help_center_outlined, "FAQ", "Frequently asked questions"),
            _buildHelpItem(Icons.description_outlined, "Terms of Service", "View terms and conditions"),
            _buildHelpItem(Icons.privacy_tip_outlined, "Privacy Policy", "View privacy policy"),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpItem(IconData icon, String title, String subtitle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: primaryColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: textPrimary)),
                Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: textSecondary),
        ],
      ),
    );
  }

  Widget _buildSettingsTile(IconData icon, String title, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: primaryColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: textPrimary)),
            ),
            const Icon(Icons.chevron_right_rounded, color: textSecondary),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BOTTOM NAVIGATION
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildBottomNav() {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: textPrimary,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(Icons.grid_view_rounded, "Home", 0),
          _buildNavItem(Icons.description_rounded, "Reports", 1),
          _buildNavItem(Icons.calendar_today_rounded, "Schedule", 2),
          _buildNavItem(Icons.person_rounded, "Profile", 3),
        ],
      ),
    );
  }
  
  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _selectedNavIndex == index;
    return GestureDetector(
      onTap: () {
        if (index == _selectedNavIndex) return;
        setState(() => _selectedNavIndex = index);
        
        if (index == 0) {
          _loadDoctorData();
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