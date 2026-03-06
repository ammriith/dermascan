import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class PatientStatisticsPage extends StatefulWidget {
  const PatientStatisticsPage({super.key});

  @override
  State<PatientStatisticsPage> createState() => _PatientStatisticsPageState();
}

class _PatientStatisticsPageState extends State<PatientStatisticsPage> {
  // 🎨 Premium Color Palette
  static const Color primaryColor = Color(0xFF4FD1C5);
  static const Color bgColor = Color(0xFFF8FAFC);
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);
  
  static const Color purpleAccent = Color(0xFF8B5CF6);
  static const Color blueAccent = Color(0xFF3B82F6);
  static const Color greenAccent = Color(0xFF10B981);
  static const Color orangeAccent = Color(0xFFF59E0B);
  static const Color pinkAccent = Color(0xFFEC4899);

  bool _isLoading = true;
  int _todayNewPatients = 0;
  int _totalPatientsAllTime = 0;
  int _todayAppointments = 0;
  int _totalAppointmentsAllTime = 0;

  @override
  void initState() {
    super.initState();
    _fetchDailyStats();
  }

  Future<void> _fetchDailyStats() async {
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = todayStart.add(const Duration(days: 1));

      // 1. Fetch Patient Stats
      final usersSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('userRole', isEqualTo: 'patient')
          .get();
      
      _totalPatientsAllTime = usersSnap.docs.length;
      _todayNewPatients = usersSnap.docs.where((doc) {
        final createdAt = (doc.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
        if (createdAt == null) return false;
        final dt = createdAt.toDate();
        return dt.isAfter(todayStart) && dt.isBefore(todayEnd);
      }).length;

      // 2. Fetch Appointments
      final appointmentsSnap = await FirebaseFirestore.instance
          .collection('appointments')
          .get();
      
      _totalAppointmentsAllTime = appointmentsSnap.docs.length;
      
      _todayAppointments = appointmentsSnap.docs.where((doc) {
        final appoDate = doc.get('appodate') as Timestamp?;
        if (appoDate == null) return false;
        final dt = appoDate.toDate();
        return dt.isAfter(todayStart) && dt.isBefore(todayEnd);
      }).length;

    } catch (e) {
      debugPrint("Error fetching daily stats: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Daily Patient Statistics",
          style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : RefreshIndicator(
              onRefresh: _fetchDailyStats,
              color: primaryColor,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDateHeader(),
                    const SizedBox(height: 32),
                    const Text(
                      "Today's Patient Activity",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
                    ),
                    const SizedBox(height: 16),
                    _buildActivityItem(
                      "New Patient Registrations", 
                      _todayNewPatients, 
                      Icons.person_add_rounded, 
                      pinkAccent,
                      subtitle: "Includes mobile self-registrations",
                    ),
                    _buildActivityItem(
                      "Appointments Today", 
                      _todayAppointments, 
                      Icons.calendar_today_rounded, 
                      blueAccent,
                      total: _totalAppointmentsAllTime,
                    ),
                    _buildActivityItem(
                      "Total Registered Patients", 
                      _totalPatientsAllTime, 
                      Icons.people_rounded, 
                      orangeAccent,
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildDateHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_month_rounded, color: primaryColor),
          const SizedBox(width: 12),
          Text(
            DateFormat('EEEE, MMMM dd, yyyy').format(DateTime.now()),
            style: const TextStyle(fontWeight: FontWeight.bold, color: primaryColor),
          ),
        ],
      ),
    );
  }


  Widget _buildActivityItem(String title, int value, IconData icon, Color color, {String? subtitle, int? total}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600, color: textPrimary),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: color.withOpacity(0.8), fontWeight: FontWeight.w500),
                  ),
                if (total != null)
                  Text(
                    "Total All-Time: $total",
                    style: const TextStyle(fontSize: 10, color: textSecondary),
                  ),
              ],
            ),
          ),
          Text(
            "$value",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}
