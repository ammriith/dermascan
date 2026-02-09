import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ViewAppointmentPage extends StatefulWidget {
  const ViewAppointmentPage({super.key});

  @override
  State<ViewAppointmentPage> createState() => _ViewAppointmentPageState();
}

class _ViewAppointmentPageState extends State<ViewAppointmentPage> {
  // 🎨 Premium Color Palette
  static const Color primaryColor = Color(0xFF4FD1C5);
  static const Color primaryDark = Color(0xFF38B2AC);
  static const Color bgColor = Color(0xFFF8FAFC);
  static const Color cardColor = Colors.white;
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);
  
  static const Color purpleAccent = Color(0xFF8B5CF6);
  static const Color blueAccent = Color(0xFF3B82F6);
  static const Color orangeAccent = Color(0xFFF59E0B);
  static const Color greenAccent = Color(0xFF10B981);
  static const Color redAccent = Color(0xFFEF4444);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = true;
  String _selectedFilter = 'All';
  
  // Appointments by date
  List<Map<String, dynamic>> _yesterdayAppointments = [];
  List<Map<String, dynamic>> _todayAppointments = [];
  List<Map<String, dynamic>> _tomorrowAppointments = [];
  List<Map<String, dynamic>> _upcomingAppointments = [];
  List<Map<String, dynamic>> _pastAppointments = [];
  List<Map<String, dynamic>> _allAppointments = [];
  
  StreamSubscription<QuerySnapshot>? _appointmentsSubscription;

  final List<String> _filters = ['All', 'Today', 'Tomorrow', 'Upcoming', 'Past'];

  @override
  void initState() {
    super.initState();
    _setupRealtimeListeners();
  }

  @override
  void dispose() {
    _appointmentsSubscription?.cancel();
    super.dispose();
  }

  void _setupRealtimeListeners() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));
    final tomorrowStart = todayStart.add(const Duration(days: 1));
    final tomorrowEnd = todayStart.add(const Duration(days: 2));

    _appointmentsSubscription = _firestore
        .collection('appointments')
        .where('patientId', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) {
      _allAppointments = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      // Yesterday's appointments
      _yesterdayAppointments = _allAppointments.where((a) {
        final date = (a['appodate'] as Timestamp?)?.toDate();
        return date != null && date.isAfter(yesterdayStart) && date.isBefore(todayStart);
      }).toList();

      // Today's appointments
      _todayAppointments = _allAppointments.where((a) {
        final date = (a['appodate'] as Timestamp?)?.toDate();
        return date != null && date.isAfter(todayStart) && date.isBefore(tomorrowStart);
      }).toList();

      // Tomorrow's appointments
      _tomorrowAppointments = _allAppointments.where((a) {
        final date = (a['appodate'] as Timestamp?)?.toDate();
        return date != null && date.isAfter(tomorrowStart) && date.isBefore(tomorrowEnd);
      }).toList();

      // Upcoming (after tomorrow)
      _upcomingAppointments = _allAppointments.where((a) {
        final date = (a['appodate'] as Timestamp?)?.toDate();
        return date != null && date.isAfter(tomorrowEnd);
      }).toList();

      // Past appointments (before today)
      _pastAppointments = _allAppointments.where((a) {
        final date = (a['appodate'] as Timestamp?)?.toDate();
        return date != null && date.isBefore(todayStart);
      }).toList();

      // Sort all lists
      _sortByDate(_yesterdayAppointments);
      _sortByDate(_todayAppointments);
      _sortByDate(_tomorrowAppointments);
      _sortByDate(_upcomingAppointments);
      _sortByDateDesc(_pastAppointments);
      _sortByDateDesc(_allAppointments);

      if (mounted) setState(() => _isLoading = false);
    });
  }

  void _sortByDate(List<Map<String, dynamic>> list) {
    list.sort((a, b) {
      final aDate = (a['appodate'] as Timestamp?)?.toDate() ?? DateTime.now();
      final bDate = (b['appodate'] as Timestamp?)?.toDate() ?? DateTime.now();
      return aDate.compareTo(bDate);
    });
  }

  void _sortByDateDesc(List<Map<String, dynamic>> list) {
    list.sort((a, b) {
      final aDate = (a['appodate'] as Timestamp?)?.toDate() ?? DateTime.now();
      final bDate = (b['appodate'] as Timestamp?)?.toDate() ?? DateTime.now();
      return bDate.compareTo(aDate);
    });
  }

  List<Map<String, dynamic>> get _filteredAppointments {
    switch (_selectedFilter) {
      case 'Today':
        return _todayAppointments;
      case 'Tomorrow':
        return _tomorrowAppointments;
      case 'Upcoming':
        return _upcomingAppointments;
      case 'Past':
        return _pastAppointments;
      default:
        return _allAppointments;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildStats(),
            _buildFilterTabs(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: primaryColor))
                  : _buildAppointmentsList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 24, 16),
      decoration: BoxDecoration(
        color: cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: textPrimary),
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "My Appointments",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textPrimary),
                ),
                Text(
                  "View all your appointments",
                  style: TextStyle(fontSize: 12, color: textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    final activeAppointmentsCount = _allAppointments.where((a) => a['status'] != 'Cancelled').length;
    
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [primaryColor, primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(child: _buildStatItem("$activeAppointmentsCount", "Active", Icons.calendar_month_rounded)),
          Container(width: 1, height: 40, color: Colors.white.withValues(alpha: 0.3)),
          Expanded(child: _buildStatItem("${_todayAppointments.length}", "Today", Icons.today_rounded)),
          Container(width: 1, height: 40, color: Colors.white.withValues(alpha: 0.3)),
          Expanded(child: _buildStatItem("${_upcomingAppointments.length}", "Upcoming", Icons.event_rounded)),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.8), size: 20),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 10)),
      ],
    );
  }

  Widget _buildFilterTabs() {
    return Container(
      height: 50,
      margin: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        itemBuilder: (ctx, index) {
          final filter = _filters[index];
          final isSelected = _selectedFilter == filter;
          int count = 0;
          switch (filter) {
            case 'Today': count = _todayAppointments.length; break;
            case 'Tomorrow': count = _tomorrowAppointments.length; break;
            case 'Upcoming': count = _upcomingAppointments.length; break;
            case 'Past': count = _pastAppointments.length; break;
            default: count = _allAppointments.length;
          }
          
          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = filter),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? primaryColor : cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isSelected ? primaryColor : Colors.grey.shade200),
                boxShadow: isSelected
                    ? [BoxShadow(color: primaryColor.withValues(alpha: 0.3), blurRadius: 8)]
                    : null,
              ),
              child: Row(
                children: [
                  Text(
                    filter,
                    style: TextStyle(
                      color: isSelected ? Colors.white : textSecondary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white.withValues(alpha: 0.2) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "$count",
                      style: TextStyle(
                        color: isSelected ? Colors.white : textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAppointmentsList() {
    final appointments = _filteredAppointments;

    if (appointments.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () async {
        _appointmentsSubscription?.cancel();
        setState(() => _isLoading = true);
        _setupRealtimeListeners();
      },
      color: primaryColor,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        itemCount: appointments.length,
        itemBuilder: (ctx, index) => _buildAppointmentCard(appointments[index]),
      ),
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> appointment) {
    final doctorName = appointment['doctorName'] ?? 'Doctor';
    final specialization = appointment['specialization'] ?? 'Specialist';
    final status = appointment['status'] ?? 'Booked';
    final timeSlot = appointment['timeSlot'] ?? '';
    final symptoms = appointment['symptoms'] ?? '';
    
    final appodate = appointment['appodate'] as Timestamp?;
    DateTime? date;
    String dateStr = 'N/A';
    String dayStr = '';
    String timeStr = timeSlot.isNotEmpty ? timeSlot : '--:--';
    
    if (appodate != null) {
      date = appodate.toDate();
      dateStr = DateFormat('MMM dd, yyyy').format(date);
      dayStr = DateFormat('EEEE').format(date);
      if (timeSlot.isEmpty) {
        timeStr = DateFormat('hh:mm a').format(date);
      }
    }

    // Determine if past
    final now = DateTime.now();
    final isPast = date != null && date.isBefore(DateTime(now.year, now.month, now.day));

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'Booked':
        statusColor = orangeAccent;
        statusIcon = Icons.event_rounded;
        break;
      case 'Waiting':
        statusColor = blueAccent;
        statusIcon = Icons.hourglass_top_rounded;
        break;
      case 'In Progress':
        statusColor = purpleAccent;
        statusIcon = Icons.medical_services_rounded;
        break;
      case 'Completed':
        statusColor = greenAccent;
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'Cancelled':
        statusColor = redAccent;
        statusIcon = Icons.cancel_rounded;
        break;
      default:
        statusColor = textSecondary;
        statusIcon = Icons.event_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isPast && status != 'Completed' ? Colors.grey.shade50 : cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: status == 'Completed' ? greenAccent.withValues(alpha: 0.3) : 
                 status == 'Cancelled' ? redAccent.withValues(alpha: 0.3) :
                 Colors.grey.shade100,
        ),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [primaryColor.withValues(alpha: 0.2), primaryDark.withValues(alpha: 0.1)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          doctorName.isNotEmpty ? doctorName[0].toUpperCase() : 'D',
                          style: const TextStyle(color: primaryDark, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Dr. $doctorName",
                            style: TextStyle(
                              fontSize: 15, 
                              fontWeight: FontWeight.bold, 
                              color: isPast ? textSecondary : textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            specialization,
                            style: const TextStyle(fontSize: 12, color: textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 14, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            status,
                            style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 16, color: textSecondary),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    dateStr,
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isPast ? textSecondary : textPrimary),
                                  ),
                                  Text(
                                    dayStr,
                                    style: const TextStyle(fontSize: 10, color: textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 30, color: Colors.grey.shade200),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.access_time_rounded, size: 16, color: textSecondary),
                            const SizedBox(width: 6),
                            Text(
                              timeStr,
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isPast ? textSecondary : textPrimary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (symptoms.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.notes_rounded, size: 14, color: textSecondary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          symptoms,
                          style: const TextStyle(fontSize: 12, color: textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                
                // 🔹 Cancel Appointment Button (Visible if not past and not cancelled/completed)
                if (!isPast && status != 'Cancelled' && status != 'Completed') ...[
                  const SizedBox(height: 16),
                  Divider(color: Colors.grey.shade100, thickness: 1),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () => _confirmCancellation(appointment['id']),
                        icon: const Icon(Icons.cancel_outlined, size: 16, color: redAccent),
                        label: const Text("Cancel Appointment", style: TextStyle(color: redAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: redAccent.withValues(alpha: 0.2))),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmCancellation(String appointId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Cancel Appointment?", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text("Are you sure you want to cancel this appointment? This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Keep it", style: TextStyle(color: textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _cancelAppointment(appointId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Yes, Cancel", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelAppointment(String appointId) async {
    try {
      await _firestore.collection('appointments').doc(appointId).update({
        'status': 'Cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Appointment cancelled successfully"),
            backgroundColor: redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: blueAccent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.calendar_today_rounded, color: blueAccent, size: 60),
            ),
            const SizedBox(height: 24),
            Text(
              _selectedFilter == 'All' ? "No Appointments" : "No $_selectedFilter Appointments",
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedFilter == 'All' 
                  ? "You haven't booked any appointments yet"
                  : "No appointments found for $_selectedFilter",
              textAlign: TextAlign.center,
              style: const TextStyle(color: textSecondary, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
