import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:dermascan/services/email_service.dart';

class PatientAppointmentPage extends StatefulWidget {
  const PatientAppointmentPage({super.key});

  @override
  State<PatientAppointmentPage> createState() => _PatientAppointmentPageState();
}

class _PatientAppointmentPageState extends State<PatientAppointmentPage> {
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
  static const Color pinkAccent = Color(0xFFEC4899);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Form data
  String? _selectedDoctorId;
  String? _selectedDoctorName;
  String? _selectedSpecialization;
  DateTime _selectedDate = DateTime.now();
  String? _selectedTimeSlot;
  String _symptoms = '';
  
  bool _isLoading = false;
  bool _isBooking = false;
  
  List<Map<String, dynamic>> _doctors = [];
  List<String> _availableSlots = [];
  List<String> _bookedSlots = [];

  // Available time slots (10 AM to 4 PM - Working Hours)
  final List<String> _allTimeSlots = [
    '10:00 AM', '10:30 AM', 
    '11:00 AM', '11:30 AM', 
    '12:00 PM', '12:30 PM',
    '01:00 PM', '01:30 PM',
    '02:00 PM', '02:30 PM', 
    '03:00 PM', '03:30 PM',
  ];

  @override
  void initState() {
    super.initState();
    _loadDoctors();
  }

  Future<void> _loadDoctors() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await _firestore.collection('doctors').get();
      _doctors = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint('Error loading doctors: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAvailableSlots() async {
    if (_selectedDoctorId == null) return;
    
    setState(() => _isLoading = true);
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final weekday = _selectedDate.weekday; // 1 (Mon) to 7 (Sun)
      
      // 1. Fetch Doctor's profile for weekly schedule
      final doctorDoc = await _firestore.collection('doctors').doc(_selectedDoctorId).get();
      final doctorData = doctorDoc.data();
      final weeklySchedule = doctorData?['weeklySchedule'] as Map<String, dynamic>?;

      // 2. Fetch Doctor's manual availability (overrides) for this specific date
      final availabilityDoc = await _firestore
          .collection('doctors')
          .doc(_selectedDoctorId)
          .collection('availability')
          .doc(dateStr)
          .get();

      List<String> generatedSlots = [];
      
      if (availabilityDoc.exists && availabilityDoc.data()?['slots'] != null) {
        // Manual override exists for this date
        final List<dynamic> slots = availabilityDoc.data()!['slots'];
        generatedSlots = slots.map((s) => s.toString()).toList();
      } else if (weeklySchedule != null) {
        // Explicitly cast days to List<int> for proper comparison
        final List<int> workDays = (weeklySchedule['days'] as List<dynamic>?)
            ?.map((d) => d is int ? d : int.tryParse(d.toString()) ?? 0)
            .toList() ?? [];
        
        debugPrint("Patient Booking: weekday=$weekday, workDays=$workDays, contains=${workDays.contains(weekday)}");
        
        if (workDays.contains(weekday)) {
          final String startTimeStr = weeklySchedule['startTime'] ?? '10:00';
          final String endTimeStr = weeklySchedule['endTime'] ?? '16:00';
          final int duration = weeklySchedule['slotDuration'] ?? 20;
          
          generatedSlots = _generateTimeSlots(startTimeStr, endTimeStr, duration);
        } else {
          // Doctor doesn't work on this day of the week
          generatedSlots = [];
        }
      } else {
        // No schedule set at all - fallback to default for legacy doctors
        generatedSlots = _generateTimeSlots('10:00', '16:00', 20); 
      }

      // 3. Fetch booked appointments for selected doctor
      final appointmentsQuery = await _firestore
          .collection('appointments')
          .where('doctorId', isEqualTo: _selectedDoctorId)
          .get();
      
      final dateStart = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      final dateEnd = dateStart.add(const Duration(days: 1));
      
      _bookedSlots = appointmentsQuery.docs.where((doc) {
        final data = doc.data();
        final timestamp = data['appodate'] as Timestamp?;
        if (timestamp != null) {
          final dt = timestamp.toDate();
          return dt.isAfter(dateStart) && dt.isBefore(dateEnd);
        }
        return false;
      }).map((doc) => doc.data()['timeSlot'] as String? ?? '').where((s) => s.isNotEmpty).toList();

      setState(() {
        _allTimeSlots.clear();
        _allTimeSlots.addAll(generatedSlots);
        
        _availableSlots = _allTimeSlots.where((slot) => !_bookedSlots.contains(slot)).toList();
        
        if (_selectedTimeSlot != null && !_allTimeSlots.contains(_selectedTimeSlot)) {
          _selectedTimeSlot = null;
        }
      });
      
    } catch (e) {
      debugPrint('Error loading slots: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<String> _generateTimeSlots(String start, String end, int durationMinutes) {
    List<String> slots = [];
    try {
      final startParts = start.split(':');
      final endParts = end.split(':');
      
      var current = DateTime(2000, 1, 1, int.parse(startParts[0]), int.parse(startParts[1]));
      final endTime = DateTime(2000, 1, 1, int.parse(endParts[0]), int.parse(endParts[1]));
      
      while (current.isBefore(endTime)) {
        slots.add(DateFormat('hh:mm a').format(current));
        current = current.add(Duration(minutes: durationMinutes));
      }
    } catch (e) {
      debugPrint("Error generating slots: $e");
    }
    return slots;
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  DateTime _parseTimeSlot(String slot) {
    final parts = slot.split(' ');
    final timeParts = parts[0].split(':');
    int hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);
    
    if (parts[1] == 'PM' && hour != 12) hour += 12;
    if (parts[1] == 'AM' && hour == 12) hour = 0;
    
    return DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, hour, minute);
  }

  Future<void> _bookAppointment() async {
    if (_selectedDoctorId == null || _selectedTimeSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a doctor and time slot'),
          backgroundColor: orangeAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Show payment confirmation dialog
    _showPaymentConfirmation();
  }

  void _showPaymentConfirmation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.payment_rounded, color: primaryColor, size: 48),
            ),
            const SizedBox(height: 20),
            const Text(
              "Consultation Fee",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              "Appointment with Dr. $_selectedDoctorName",
              textAlign: TextAlign.center,
              style: const TextStyle(color: textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: greenAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: greenAccent.withValues(alpha: 0.3)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.currency_rupee_rounded, color: greenAccent, size: 28),
                  Text(
                    "400",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: greenAccent,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: const Text("Cancel", style: TextStyle(color: textSecondary)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _processBooking();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("Pay ₹400", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processBooking() async {
    setState(() => _isBooking = true);
    
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not logged in');
      
      // Get patient info
      final patientDoc = await _firestore.collection('patients').doc(user.uid).get();
      String patientName = 'Patient';
      if (patientDoc.exists) {
        patientName = patientDoc.data()?['name'] ?? 'Patient';
      }
      
      // Parse appointment time
      final appointmentDateTime = _parseTimeSlot(_selectedTimeSlot!);
      
      // Create appointment with consultation fee
      await _firestore.collection('appointments').add({
        'patientId': user.uid,
        'patientName': patientName,
        'doctorId': _selectedDoctorId,
        'doctorName': _selectedDoctorName,
        'specialization': _selectedSpecialization,
        'appodate': Timestamp.fromDate(appointmentDateTime),
        'timeSlot': _selectedTimeSlot,
        'symptoms': _symptoms.trim(),
        'status': 'Booked',
        'consultationFee': 400,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      // Get patient email for confirmation
      final String? userEmail = user.email;
      if (userEmail != null) {
        // Automatically send confirmation email in background
        EmailService.sendAppointmentConfirmation(
          patientName: patientName,
          patientEmail: userEmail,
          doctorName: _selectedDoctorName ?? 'Doctor',
          tokenNumber: 0, // Placeholder or fetch actual token if implemented
          date: DateFormat('EEEE, MMM dd, yyyy').format(_selectedDate),
          timeSlot: _selectedTimeSlot ?? '',
        );
      }
      
      if (mounted) {
        // Show success dialog
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: greenAccent.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_rounded, color: greenAccent, size: 60),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Payment Successful!",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textPrimary),
                ),
                const SizedBox(height: 10),
                Text(
                  "Your appointment with Dr. $_selectedDoctorName on ${DateFormat('MMM dd, yyyy').format(_selectedDate)} at $_selectedTimeSlot has been confirmed.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: textSecondary, height: 1.4),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("Done", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error booking appointment: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() => _isBooking = false);
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
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStepIndicator(),
                    const SizedBox(height: 24),
                    _buildDoctorSelection(),
                    const SizedBox(height: 24),
                    _buildDateSelection(),
                    const SizedBox(height: 24),
                    _buildTimeSlotSelection(),
                    const SizedBox(height: 24),
                    _buildSymptomsInput(),
                    const SizedBox(height: 24),
                    _buildAppointmentSummary(),
                    const SizedBox(height: 24),
                    _buildBookButton(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
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
                  "Book Appointment",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textPrimary),
                ),
                Text(
                  "Schedule your visit with our doctors",
                  style: TextStyle(fontSize: 12, color: textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      child: Row(
        children: [
          _buildStep(1, "Doctor", _selectedDoctorId != null),
          _buildStepLine(_selectedDoctorId != null),
          _buildStep(2, "Date", _selectedDoctorId != null),
          _buildStepLine(_selectedTimeSlot != null),
          _buildStep(3, "Time", _selectedTimeSlot != null),
          _buildStepLine(_selectedTimeSlot != null),
          _buildStep(4, "Book", false),
        ],
      ),
    );
  }

  Widget _buildStep(int number, String label, bool completed) {
    return SizedBox(
      width: 45,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: completed ? primaryColor : Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: completed
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : Text("$number", style: TextStyle(color: completed ? Colors.white : textSecondary, fontWeight: FontWeight.bold, fontSize: 11)),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label, 
            style: TextStyle(fontSize: 9, color: completed ? primaryColor : textSecondary),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStepLine(bool completed) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 18),
        color: completed ? primaryColor : Colors.grey.shade200,
      ),
    );
  }

  Widget _buildDoctorSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Select Doctor",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
        ),
        const SizedBox(height: 4),
        const Text(
          "Choose from our available specialists",
          style: TextStyle(fontSize: 13, color: textSecondary),
        ),
        const SizedBox(height: 16),
        if (_isLoading && _doctors.isEmpty)
          const Center(child: CircularProgressIndicator(color: primaryColor))
        else if (_doctors.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Center(
              child: Text("No doctors available", style: TextStyle(color: textSecondary)),
            ),
          )
        else
          SizedBox(
            height: 180,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _doctors.length,
              itemBuilder: (ctx, index) => _buildDoctorCard(_doctors[index]),
            ),
          ),
      ],
    );
  }

  Widget _buildDoctorCard(Map<String, dynamic> doctor) {
    final isSelected = _selectedDoctorId == doctor['id'];
    final name = doctor['name'] ?? 'Doctor';
    final specialization = doctor['specialization'] ?? 'Specialist';
    final experience = doctor['experience'] ?? '5+ years';
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDoctorId = doctor['id'];
          _selectedDoctorName = name;
          _selectedSpecialization = specialization;
          _selectedTimeSlot = null;
        });
        _loadAvailableSlots();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 160,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: primaryColor.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 5))]
              : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10)],
        ),
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isSelected 
                      ? [Colors.white.withValues(alpha: 0.3), Colors.white.withValues(alpha: 0.1)]
                      : [primaryColor.withValues(alpha: 0.1), primaryDark.withValues(alpha: 0.1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'D',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : primaryColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Dr. $name",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              specialization,
              style: TextStyle(
                fontSize: 11,
                color: isSelected ? Colors.white70 : textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withValues(alpha: 0.2) : greenAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.verified_rounded,
                    size: 12,
                    color: isSelected ? Colors.white : greenAccent,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "Available",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : greenAccent,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelection() {
    final bool doctorSelected = _selectedDoctorId != null;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              "Select Date",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
            ),
            if (!doctorSelected) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: orangeAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  "Select doctor first",
                  style: TextStyle(fontSize: 10, color: orangeAccent, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        if (!doctorSelected)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.calendar_today_rounded, color: textSecondary.withValues(alpha: 0.5)),
                const SizedBox(width: 8),
                const Text("Select a doctor to view available dates", style: TextStyle(color: textSecondary)),
              ],
            ),
          )
        else
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 14, // Next 14 days
              itemBuilder: (ctx, index) {
                final date = DateTime.now().add(Duration(days: index));
                final isSelected = _selectedDate.day == date.day && 
                                   _selectedDate.month == date.month && 
                                   _selectedDate.year == date.year;
                final isToday = index == 0;
                
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDate = date;
                      _selectedTimeSlot = null;
                    });
                    _loadAvailableSlots();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 60,
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? const LinearGradient(colors: [primaryColor, primaryDark])
                          : null,
                      color: isSelected ? null : cardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? primaryColor : (isToday ? orangeAccent : Colors.grey.shade200),
                        width: isToday && !isSelected ? 2 : 1,
                      ),
                      boxShadow: isSelected
                          ? [BoxShadow(color: primaryColor.withValues(alpha: 0.3), blurRadius: 10)]
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          DateFormat('EEE').format(date),
                          style: TextStyle(
                            fontSize: 10,
                            color: isSelected ? Colors.white70 : textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "${date.day}",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : textPrimary,
                          ),
                        ),
                        Text(
                          DateFormat('MMM').format(date),
                          style: TextStyle(
                            fontSize: 9,
                            color: isSelected ? Colors.white70 : textSecondary,
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
    );
  }

  Widget _buildTimeSlotSelection() {
    // Check for past slots if today is selected
    List<String> pastSlots = [];
    if (_isToday(_selectedDate)) {
      final now = DateTime.now();
      pastSlots = _allTimeSlots.where((slot) {
        final slotTime = _parseTimeSlot(slot);
        return slotTime.isBefore(now);
      }).toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Select Time",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
            ),
            if (_selectedDoctorId != null && _availableSlots.isNotEmpty)
              Text(
                "${_availableSlots.length} slots available",
                style: const TextStyle(fontSize: 12, color: greenAccent, fontWeight: FontWeight.w600),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (_selectedDoctorId == null)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline_rounded, color: textSecondary.withValues(alpha: 0.5)),
                const SizedBox(width: 8),
                const Text("Please select a doctor first", style: TextStyle(color: textSecondary)),
              ],
            ),
          )
        else if (_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(color: primaryColor),
            ),
          )
        else if (_allTimeSlots.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Column(
              children: [
                Icon(Icons.event_busy_rounded, size: 40, color: Colors.orange.shade400),
                const SizedBox(height: 12),
                const Text(
                  "No Availability Set",
                  style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary),
                ),
                const SizedBox(height: 4),
                const Text(
                  "The doctor has not set their availability for this date yet.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: textSecondary),
                ),
              ],
            ),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _allTimeSlots.map((slot) {
              final isSelected = _selectedTimeSlot == slot;
              final isBooked = _bookedSlots.contains(slot);
              final isPast = pastSlots.contains(slot);
              final isUnavailable = isBooked || isPast;
              
              return GestureDetector(
                onTap: isUnavailable ? null : () => setState(() => _selectedTimeSlot = slot),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: isSelected 
                        ? const LinearGradient(colors: [primaryColor, primaryDark])
                        : null,
                    color: isSelected 
                        ? null 
                        : isUnavailable 
                            ? Colors.red.shade50 
                            : cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected 
                          ? primaryColor 
                          : isUnavailable 
                              ? Colors.red.shade300 
                              : Colors.grey.shade200,
                    ),
                    boxShadow: isSelected
                        ? [BoxShadow(color: primaryColor.withValues(alpha: 0.3), blurRadius: 8)]
                        : null,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        slot,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSelected 
                              ? Colors.white 
                              : isUnavailable 
                                  ? Colors.red.shade400
                                  : textPrimary,
                          decoration: isUnavailable ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      if (isBooked) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.block_rounded, size: 10, color: Colors.red.shade600),
                              const SizedBox(width: 3),
                              Text(
                                "Booked",
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                    ],
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildSymptomsInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Symptoms (Optional)",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
        ),
        const SizedBox(height: 8),
        const Text(
          "Briefly describe your symptoms or reason for visit",
          style: TextStyle(fontSize: 13, color: textSecondary),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: TextField(
            onChanged: (val) => _symptoms = val,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: "e.g., Skin rash, itching, acne...",
              hintStyle: TextStyle(color: Colors.grey.shade400),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppointmentSummary() {
    if (_selectedDoctorId == null || _selectedTimeSlot == null) {
      return const SizedBox.shrink();
    }
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor.withValues(alpha: 0.08), primaryDark.withValues(alpha: 0.04)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.calendar_month_rounded, color: primaryDark, size: 24),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  "Appointment Summary",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          _buildSummaryRow(Icons.person_rounded, "Doctor", "Dr. $_selectedDoctorName"),
          _buildSummaryRow(Icons.medical_services_rounded, "Specialization", _selectedSpecialization ?? ''),
          _buildSummaryRow(Icons.calendar_today_rounded, "Date", DateFormat('EEEE, MMM dd, yyyy').format(_selectedDate)),
          _buildSummaryRow(Icons.access_time_rounded, "Time", _selectedTimeSlot ?? ''),
          const Divider(height: 24),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: greenAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: greenAccent.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.payment_rounded, color: greenAccent, size: 20),
                    SizedBox(width: 10),
                    Text("Consultation Fee", style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: greenAccent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    "₹400",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: textSecondary),
          const SizedBox(width: 10),
          Text("$label: ", style: const TextStyle(color: textSecondary, fontSize: 13)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, color: textPrimary, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookButton() {
    final canBook = _selectedDoctorId != null && _selectedTimeSlot != null;
    
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: canBook && !_isBooking ? _bookAppointment : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: canBook ? primaryColor : Colors.grey.shade300,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: canBook ? 4 : 0,
          shadowColor: primaryColor.withValues(alpha: 0.4),
        ),
        child: _isBooking
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(canBook ? Icons.check_circle_rounded : Icons.lock_rounded, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    canBook ? "Confirm Appointment" : "Complete Selection",
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
      ),
    );
  }
}
