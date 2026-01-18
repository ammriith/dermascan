import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dermascan/admin/staff_register_patient.dart';
import 'package:dermascan/admin/staff_book_appointment.dart';

class ViewTodayAppointmentsPage extends StatefulWidget {
  const ViewTodayAppointmentsPage({super.key});

  @override
  State<ViewTodayAppointmentsPage> createState() => _ViewTodayAppointmentsPageState();
}

class _ViewTodayAppointmentsPageState extends State<ViewTodayAppointmentsPage> with SingleTickerProviderStateMixin {
  static const Color accentColor = Color(0xFF4FD1C5);
  static const Color accentColorDark = Color(0xFF38B2AC);
  static const Color bgColor = Color(0xFFF8FAFC);
  static const Color cardColor = Colors.white;
  static const Color textColor = Color(0xFF1F2937);
  
  late TabController _tabController;
  String _selectedFilter = 'All';
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // Custom Header
            _buildHeader(today),
            
            // Quick Action Buttons
            _buildQuickActions(),
            
            // Filter Tabs
            _buildFilterTabs(),
            
            // Appointments List
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 80), // Space for bottom nav
                child: _buildAppointmentsList(todayStart, todayEnd),
              ),
            ),
          ],
        ),
      ),
      
      // Floating Action Button
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 70), // Above bottom nav
        child: FloatingActionButton.extended(
          onPressed: () => _showQuickActionSheet(context),
          backgroundColor: accentColor,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: const Text('New', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
  
  Widget _buildHeader(DateTime today) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        color: cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Back Button
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: textColor),
                ),
              ),
              
              // Title & Date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Today's Schedule",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.calendar_today_rounded, size: 14, color: accentColor),
                        const SizedBox(width: 6),
                        Text(
                          "${_getWeekday(today.weekday)}, ${today.day} ${_getMonth(today.month)} ${today.year}",
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Search icon
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.search_rounded, color: accentColor, size: 22),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildQuickActionCard(
              "Register Patient",
              Icons.person_add_rounded,
              const Color(0xFF6366F1), // Indigo
              () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StaffRegisterPatientPage()),
                );
                if (result == true) setState(() {});
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildQuickActionCard(
              "Book Appointment",
              Icons.event_available_rounded,
              const Color(0xFF10B981), // Emerald
              () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StaffBookAppointmentPage()),
                );
                if (result == true) setState(() {});
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildQuickActionCard(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withValues(alpha: 0.85)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withValues(alpha: 0.7), size: 14),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFilterTabs() {
    final filters = ['All', 'Waiting', 'In Progress', 'Completed'];
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _selectedFilter == filter;
          
          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = filter),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? accentColor : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? accentColor : Colors.grey.shade300,
                ),
                boxShadow: isSelected ? [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ] : null,
              ),
              child: Text(
                filter,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildAppointmentsList(DateTime todayStart, DateTime todayEnd) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('appodate', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
          .where('appodate', isLessThan: Timestamp.fromDate(todayEnd))
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: accentColor));
        }

        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }

        var appointments = snapshot.data?.docs ?? [];
        
        // Apply filter
        if (_selectedFilter != 'All') {
          appointments = appointments.where((doc) {
            final status = (doc.data() as Map)['status'] ?? '';
            if (_selectedFilter == 'Waiting') return status == 'Waiting' || status == 'Booked';
            if (_selectedFilter == 'In Progress') return status == 'In Consultation';
            if (_selectedFilter == 'Completed') return status == 'Completed';
            return true;
          }).toList();
        }
        
        // Sort by token number
        appointments.sort((a, b) {
          int tokenA = (a.data() as Map)['tokenno'] ?? 0;
          int tokenB = (b.data() as Map)['tokenno'] ?? 0;
          return tokenA.compareTo(tokenB);
        });

        if (appointments.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          itemCount: appointments.length,
          itemBuilder: (context, index) {
            final doc = appointments[index] as QueryDocumentSnapshot;
            final data = doc.data() as Map<String, dynamic>;
            return _buildAppointmentCard(data, index);
          },
        );
      },
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.event_busy_rounded, size: 48, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 20),
          const Text(
            "No appointments found",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedFilter == 'All' 
                ? "Tap the + button to book an appointment"
                : "No ${_selectedFilter.toLowerCase()} appointments",
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> data, int index) {
    final patientName = data['patient_name'] ?? "Unknown Patient";
    final doctorName = data['doctor_name'] ?? "Unknown Doctor";
    final token = data['tokenno'] ?? 0;
    final status = data['status'] ?? "Booked";
    final isActive = status == 'In Consultation';

    return AnimatedContainer(
      duration: Duration(milliseconds: 200 + (index * 50)),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? accentColor.withValues(alpha: 0.3) : Colors.grey.shade200,
          width: isActive ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isActive 
                ? accentColor.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showAppointmentDetails(data),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Token Badge
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isActive 
                          ? [accentColor, accentColorDark]
                          : [Colors.grey.shade200, Colors.grey.shade300],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "#$token",
                        style: TextStyle(
                          color: isActive ? Colors.white : textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                
                // Patient Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patientName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.medical_services_rounded, size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              "Dr. $doctorName",
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Status Badge
                _buildStatusBadge(status),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildStatusBadge(String status) {
    final color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
  
  void _showQuickActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
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
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "Quick Actions",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
            ),
            const SizedBox(height: 20),
            _buildBottomSheetAction("Register New Patient", Icons.person_add_rounded, () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffRegisterPatientPage()));
            }),
            _buildBottomSheetAction("Book Appointment", Icons.event_available_rounded, () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffBookAppointmentPage()));
            }),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
  
  Widget _buildBottomSheetAction(String label, IconData icon, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: accentColor),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
    );
  }
  
  void _showAppointmentDetails(Map<String, dynamic> data) {
    // Can be implemented to show full appointment details
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed': return const Color(0xFF10B981);
      case 'cancelled': return const Color(0xFFEF4444);
      case 'in consultation': return const Color(0xFFF59E0B);
      case 'waiting': return const Color(0xFF6366F1);
      default: return accentColor;
    }
  }
  
  String _getWeekday(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }
  
  String _getMonth(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}
