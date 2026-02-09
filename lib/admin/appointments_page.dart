import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class AppointmentsPage extends StatefulWidget {
  final bool isDoctor; // true for doctor, false for clinic staff
  final VoidCallback? onBackPressed; // Callback for back navigation in tabs
  
  const AppointmentsPage({super.key, this.isDoctor = false, this.onBackPressed});

  @override
  State<AppointmentsPage> createState() => _AppointmentsPageState();
}

class _AppointmentsPageState extends State<AppointmentsPage> {
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

  DateTime _selectedDate = DateTime.now();
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Booked', 'Cancelled'];
  
  List<Map<String, dynamic>> _appointments = [];
  bool _isLoading = true;
  bool _viewingAllDates = false; // Add this
  int _newAppointmentsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      final userId = _auth.currentUser?.uid;
      final dateStart = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      final dateEnd = dateStart.add(const Duration(days: 1));
      
      List<QueryDocumentSnapshot> allDocs = [];
      
      if (widget.isDoctor) {
        if (userId != null) {
          // Fetch both variations in parallel to catch all appointments
          final results = await Future.wait([
            _firestore.collection('appointments').where('doctorId', isEqualTo: userId).get(),
            _firestore.collection('appointments').where('doctor_id', isEqualTo: userId).get(),
          ]);
          
          allDocs = [...results[0].docs, ...results[1].docs];
          
          // Remove duplicates (by document ID)
          final seenIds = <String>{};
          allDocs = allDocs.where((doc) => seenIds.add(doc.id)).toList();
        }
      } else {
        // Admin/Staff View - Use server-side filtering by date if not viewing all
        // We know this index exists because the today's schedule page uses it
        Query query = _firestore.collection('appointments');
        if (!_viewingAllDates) {
          query = query.where('appodate', isGreaterThanOrEqualTo: Timestamp.fromDate(dateStart))
                       .where('appodate', isLessThan: Timestamp.fromDate(dateEnd));
        }
        final snapshot = await query.get();
        allDocs = snapshot.docs;
      }

      // Final client-side filtering and mapping
      _appointments = allDocs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        
        // Date filter is only needed on client side for doctors (to avoid index issues)
        // or if _viewingAllDates is true (show everything)
        if (!_viewingAllDates && widget.isDoctor) {
          final timestamp = data['appodate'] as Timestamp?;
          if (timestamp == null) return false;
          final dt = timestamp.toDate();
          // Compare only dates (year-month-day) or use range
          if (dt.isBefore(dateStart) || !dt.isBefore(dateEnd)) return false;
        }
        
        return true;
      }).map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
      
      // Sort by time
      _appointments.sort((a, b) {
        final aTime = (a['appodate'] as Timestamp?)?.toDate() ?? DateTime.now();
        final bTime = (b['appodate'] as Timestamp?)?.toDate() ?? DateTime.now();
        return aTime.compareTo(bTime);
      });
      
      // Count new appointments (Booked status)
      _newAppointmentsCount = _appointments.where((a) => a['status'] == 'Booked').length;
      
    } catch (e) {
      debugPrint('Error loading appointments: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStatus(String appointmentId, String newStatus) async {
    try {
      await _firestore.collection('appointments').doc(appointmentId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Flexible(child: Text('Status updated to $newStatus')),
            ],
          ),
          backgroundColor: greenAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      
      _loadAppointments();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating status: $e'),
          backgroundColor: redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showCancelDialog(String appointmentId) {
    final reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: redAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.cancel_rounded, color: redAccent, size: 24),
            ),
            const SizedBox(width: 12),
            const Flexible(
              child: Text("Cancel Appointment", style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Please provide a reason (optional):",
              style: TextStyle(fontSize: 14, color: textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                hintText: "e.g., Patient could not come",
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Back", style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _firestore.collection('appointments').doc(appointmentId).update({
                  'status': 'Cancelled',
                  'cancelReason': reasonController.text.trim(),
                  'updatedAt': FieldValue.serverTimestamp(),
                });
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text('Appointment Cancelled'),
                      ],
                    ),
                    backgroundColor: redAccent,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
                
                _loadAppointments();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e'), backgroundColor: redAccent),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Confirm Cancel", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> get _filteredAppointments {
    if (_selectedFilter == 'All') {
      return _appointments;
    }
    return _appointments.where((a) => a['status'] == _selectedFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            if (widget.isDoctor) _buildNextPatientCard(),
            _buildDateSelector(),
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

  Widget _buildNextPatientCard() {
    // Determine the relevant appointments for the 'Next Patient' alert.
    // If viewing all dates, we only consider TODAY's patients to avoid confusion.
    // If a specific date is selected, we consider that day's patients.
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    final relevantAppointments = _viewingAllDates
        ? _appointments.where((a) {
            final ts = a['appodate'] as Timestamp?;
            if (ts == null) return false;
            final dt = ts.toDate();
            return dt.isAfter(todayStart.subtract(const Duration(seconds: 1))) && dt.isBefore(todayEnd);
          }).toList()
        : _appointments;

    // Find next patient: prioritize "Waiting", then "Booked"
    final waitingAppointments = relevantAppointments.where((a) => a['status'] == 'Waiting').toList();
    final bookedAppointments = relevantAppointments.where((a) => a['status'] == 'Booked').toList();
    
    Map<String, dynamic>? nextPatient;
    if (waitingAppointments.isNotEmpty) {
      nextPatient = waitingAppointments.first;
    } else if (bookedAppointments.isNotEmpty) {
      nextPatient = bookedAppointments.first;
    }
    
    if (nextPatient == null) {
      return Container(
        margin: const EdgeInsets.fromLTRB(24, 8, 24, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: greenAccent, size: 28),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                "No patients waiting!",
                style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary),
              ),
            ),
          ],
        ),
      );
    }
    
    final patientName = nextPatient['patientName'] ?? nextPatient['patient_name'] ?? 'Unknown';
    final status = nextPatient['status'] ?? 'Waiting';
    final timeSlot = nextPatient['timeSlot'] ?? nextPatient['time_slot'] ?? '';
    
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [orangeAccent, orangeAccent.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: orangeAccent.withOpacity(0.3),
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
              color: Colors.white.withOpacity(0.2),
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
                if (timeSlot.isNotEmpty)
                  Text(
                    "$timeSlot • $status",
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
              style: TextStyle(color: orangeAccent, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
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
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Show back button - use callback if provided, otherwise Navigator.pop
          GestureDetector(
            onTap: () {
              if (widget.onBackPressed != null) {
                widget.onBackPressed!();
              } else {
                Navigator.pop(context);
              }
            },
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isDoctor ? "My Appointments" : "All Appointments",
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textPrimary),
                ),
                Text(
                  _viewingAllDates ? "All Dates" : DateFormat('EEEE, MMMM dd, yyyy').format(_selectedDate),
                  key: const ValueKey('date_range_label'),
                  style: const TextStyle(fontSize: 12, color: textSecondary),
                ),
              ],
            ),
          ),
          // Calendar Picker Button
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
                builder: (context, child) => Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.light(primary: primaryColor),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) {
                setState(() {
                  _selectedDate = picked;
                  _viewingAllDates = false;
                });
                _loadAppointments();
              }
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.calendar_month_rounded, size: 20, color: primaryColor),
            ),
          ),
          const SizedBox(width: 8),
          if (_newAppointmentsCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: orangeAccent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.fiber_new_rounded, color: Colors.white, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    "$_newAppointmentsCount New",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Select Date",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
              ),
              // Show All Toggle
              GestureDetector(
                key: const ValueKey('toggle_all_dates'),
                onTap: () {
                  setState(() => _viewingAllDates = !_viewingAllDates);
                  _loadAppointments();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _viewingAllDates ? primaryColor : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "Show All Dates",
                    style: TextStyle(
                      fontSize: 11, 
                      fontWeight: FontWeight.bold, 
                      color: _viewingAllDates ? Colors.white : textSecondary
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 365, // Show a full year
              itemBuilder: (ctx, index) {
                // Show from -30 days to +335 days
                final date = DateTime.now().add(Duration(days: index - 30));
                final isSelected = _selectedDate.day == date.day && 
                                   _selectedDate.month == date.month && 
                                   _selectedDate.year == date.year;
                final isToday = DateTime.now().day == date.day && 
                                DateTime.now().month == date.month && 
                                DateTime.now().year == date.year;
                
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDate = date;
                      _viewingAllDates = false;
                    });
                    _loadAppointments();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 58,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      gradient: isSelected && !_viewingAllDates
                          ? const LinearGradient(colors: [primaryColor, primaryDark])
                          : null,
                      color: isSelected && !_viewingAllDates ? null : cardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected && !_viewingAllDates ? primaryColor : (isToday ? orangeAccent : Colors.grey.shade200),
                        width: isToday && !isSelected ? 2 : 1,
                      ),
                      boxShadow: isSelected && !_viewingAllDates
                          ? [BoxShadow(color: primaryColor.withOpacity(0.3), blurRadius: 8)]
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('EEE').format(date),
                          style: TextStyle(
                            fontSize: 10,
                            color: isSelected && !_viewingAllDates ? Colors.white70 : textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${date.day}",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isSelected && !_viewingAllDates ? Colors.white : textPrimary,
                          ),
                        ),
                        Text(
                          DateFormat('MMM').format(date),
                          style: TextStyle(
                            fontSize: 9,
                            color: isSelected && !_viewingAllDates ? Colors.white70 : textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    final activeAppointments = _appointments.where((a) => a['status'] != 'Cancelled').toList();
    final booked = _appointments.where((a) => a['status'] == 'Booked').length;
    final completed = _appointments.where((a) => a['status'] == 'Completed').length;
    final cancelled = _appointments.where((a) => a['status'] == 'Cancelled').length;
    
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor.withOpacity(0.1), primaryDark.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(child: _buildStatItem("Active", "${activeAppointments.length}", primaryDark)),
          Expanded(child: _buildStatItem("New", "$booked", orangeAccent)),
          Expanded(child: _buildStatItem("Done", "$completed", greenAccent)),
          Expanded(child: _buildStatItem("Cancel", "$cancelled", redAccent)),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: textSecondary),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildFilterTabs() {
    return Container(
      height: 40,
      margin: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        itemBuilder: (ctx, index) {
          final filter = _filters[index];
          final isSelected = _selectedFilter == filter;
          
          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = filter),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isSelected ? primaryColor : cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? primaryColor : Colors.grey.shade200,
                ),
              ),
              child: Center(
                child: Text(
                  filter,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : textSecondary,
                  ),
                ),
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_available_rounded, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              "No Appointments",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              _viewingAllDates
                  ? "No appointments found"
                  : (_selectedFilter == 'All'
                      ? "No appointments for this date"
                      : "No $_selectedFilter appointments"),
              style: const TextStyle(color: textSecondary),
            ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _loadAppointments,
      color: primaryColor,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        itemCount: appointments.length,
        itemBuilder: (ctx, index) => _buildAppointmentCard(appointments[index]),
      ),
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> appointment) {
    // Support both camelCase (patient app) and snake_case (staff app) field names
    final patientName = appointment['patientName'] ?? appointment['patient_name'] ?? 'Unknown Patient';
    final doctorName = appointment['doctorName'] ?? appointment['doctor_name'] ?? 'Unknown Doctor';
    final status = appointment['status'] ?? 'Booked';
    final symptoms = appointment['symptoms'] ?? '';
    final timeSlot = appointment['timeSlot'] ?? appointment['time_slot'] ?? '';
    final specialization = appointment['specialization'] ?? '';

    
    final appodate = appointment['appodate'] as Timestamp?;
    String timeStr = timeSlot.isNotEmpty ? timeSlot : '--:--';
    if (appodate != null && timeSlot.isEmpty) {
      final dt = appodate.toDate();
      timeStr = DateFormat('hh:mm a').format(dt);
    }
    
    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'Booked':
        statusColor = orangeAccent;
        statusIcon = Icons.fiber_new_rounded;
        break;
      case 'Waiting':
        statusColor = blueAccent;
        statusIcon = Icons.hourglass_empty_rounded;
        break;
      case 'In Progress':
        statusColor = purpleAccent;
        statusIcon = Icons.play_circle_rounded;
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
        statusIcon = Icons.schedule_rounded;
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: status == 'Booked' ? orangeAccent.withValues(alpha: 0.3) : Colors.grey.shade100,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Main content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
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
                      patientName.isNotEmpty ? patientName[0].toUpperCase() : 'P',
                      style: const TextStyle(color: primaryDark, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patientName,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      if (!widget.isDoctor)
                        Row(
                          children: [
                            const Icon(Icons.person_rounded, size: 14, color: textSecondary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                "Dr. $doctorName",
                                style: const TextStyle(fontSize: 12, color: textSecondary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded, size: 14, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            timeStr,
                            style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.w600),
                          ),
                          if (specialization.isNotEmpty) ...[
                            const SizedBox(width: 10),
                            const Icon(Icons.medical_services_rounded, size: 12, color: textSecondary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                specialization,
                                style: const TextStyle(fontSize: 11, color: textSecondary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Removed Status badge as requested
              ],
            ),
          ),
          // Symptoms (if any)
          if (symptoms.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.note_rounded, size: 14, color: textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        symptoms,
                        style: const TextStyle(fontSize: 12, color: textSecondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Action buttons - Only show Cancellation as other statuses were removed
          if (status != 'Cancelled' && status != 'Completed')
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      "Cancel Appointment",
                      Icons.cancel_rounded,
                      redAccent,
                      () => _showCancelDialog(appointment['id']),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
