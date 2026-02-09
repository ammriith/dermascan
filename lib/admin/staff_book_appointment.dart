import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dermascan/services/email_service.dart';
import 'package:intl/intl.dart';

class StaffBookAppointmentPage extends StatefulWidget {
  const StaffBookAppointmentPage({super.key});

  @override
  State<StaffBookAppointmentPage> createState() => _StaffBookAppointmentPageState();
}

class _StaffBookAppointmentPageState extends State<StaffBookAppointmentPage> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const Color accentColor = Color(0xFF4FD1C5);
  static const Color textColor = Color(0xFF1F2937);
  static const Color inputFill = Color(0xFFF3F4F6);
  static const Color bgColor = Color(0xFFF8FAFC);

  String? _selectedPatientId;
  String? _selectedPatientName;
  String? _selectedPatientPhone;
  String? _selectedDoctorId;
  String? _selectedDoctorName;
  double _selectedDoctorFee = 0.0; // Will be updated when doctor is selected
  DateTime _selectedDate = DateTime.now();
  String? _selectedTimeSlot;
  bool _isLoading = false;

  // Doctor's working days (1=Mon, 7=Sun)
  List<int> _doctorWorkDays = [];

  // Time slots available for booking (dynamically populated based on doctor's schedule)
  final List<String> _timeSlots = [];

  List<String> _bookedSlots = [];

  @override
  void initState() {
    super.initState();
    _loadBookedSlots();
  }

  Future<void> _loadBookedSlots() async {
    if (_selectedDoctorId == null) return;
    
    final dateOnly = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final tomorrow = dateOnly.add(const Duration(days: 1));
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final weekday = _selectedDate.weekday; // 1 (Mon) to 7 (Sun)

    setState(() => _isLoading = true);

    try {
      // 1. Fetch Doctor's profile for weekly schedule
      final doctorDoc = await _firestore.collection('doctors').doc(_selectedDoctorId).get();
      final doctorData = doctorDoc.data();
      final weeklySchedule = doctorData?['weeklySchedule'] as Map<String, dynamic>?;

      // 2. Fetch Doctor's manual availability for this specific date
      final availabilityDoc = await _firestore
          .collection('doctors')
          .doc(_selectedDoctorId)
          .collection('availability')
          .doc(dateStr)
          .get();

      List<String> generatedSlots = [];
      
      debugPrint("Staff Booking: Doctor=${doctorData?['name']}, weeklySchedule=$weeklySchedule");
      
      if (availabilityDoc.exists && availabilityDoc.data()?['slots'] != null) {
        final List<dynamic> slots = availabilityDoc.data()!['slots'];
        generatedSlots = slots.map((s) => s.toString()).toList();
        debugPrint("Staff Booking: Using MANUAL OVERRIDE for date $dateStr");
      } else if (weeklySchedule != null) {
        // 1. Map weekday index to name
        final dayMap = {1: 'monday', 2: 'tuesday', 3: 'wednesday', 4: 'thursday', 5: 'friday', 6: 'saturday', 7: 'sunday'};
        final dayName = dayMap[weekday];
        
        // 2. Check for per-day schedule first
        if (weeklySchedule.containsKey('perDay') && dayName != null) {
          final perDay = weeklySchedule['perDay'] as Map<String, dynamic>;
          if (perDay.containsKey(dayName)) {
            final dayData = perDay[dayName] as Map<String, dynamic>;
            if (dayData['isEnabled'] == true) {
              final String startTimeStr = dayData['startTime'] ?? '10:00';
              final String endTimeStr = dayData['endTime'] ?? '16:00';
              final int duration = weeklySchedule['slotDuration'] ?? 20;
              debugPrint("Staff Booking: Using PER-DAY schedule for $dayName: $startTimeStr-$endTimeStr");
              generatedSlots = _generateTimeSlots(startTimeStr, endTimeStr, duration);
            } else {
              debugPrint("Staff Booking: Day $dayName is DISABLED in per-day schedule");
              generatedSlots = [];
            }
          }
        } else {
          // Fallback to legacy format
          final List<int> workDays = (weeklySchedule['days'] as List<dynamic>?)
              ?.map((d) => d is int ? d : int.tryParse(d.toString()) ?? 0)
              .toList() ?? [];
          
          if (workDays.contains(weekday)) {
            final String startTimeStr = weeklySchedule['startTime'] ?? '10:00';
            final String endTimeStr = weeklySchedule['endTime'] ?? '16:00';
            final int duration = weeklySchedule['slotDuration'] ?? 20;
            generatedSlots = _generateTimeSlots(startTimeStr, endTimeStr, duration);
          } else {
            debugPrint("Staff Booking: Doctor not working on this day (legacy check)");
            generatedSlots = [];
          }
        }
      } else {
        // Fallback: standard slots for legacy doctors without weeklySchedule
        debugPrint("Staff Booking: NO weeklySchedule found, using FALLBACK slots");
        generatedSlots = _generateTimeSlots('10:00', '16:00', 20);
      }

      // 3. Fetch booked slots - check both field naming variations
      final snapshots = await Future.wait([
        _firestore.collection('appointments').where('doctorId', isEqualTo: _selectedDoctorId).get(),
        _firestore.collection('appointments').where('doctor_id', isEqualTo: _selectedDoctorId).get(),
      ]);

      final allBookedDocs = [...snapshots[0].docs, ...snapshots[1].docs];
      final dateOnlyTimestamp = Timestamp.fromDate(dateOnly);
      final tomorrowTimestamp = Timestamp.fromDate(tomorrow);

      setState(() {
        _timeSlots.clear();
        _timeSlots.addAll(generatedSlots);
        
        _bookedSlots = allBookedDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final appodate = data['appodate'] as Timestamp?;
          final status = data['status'] as String? ?? 'Booked';

          if (appodate == null) return false;
          
          // ONLY count as booked if NOT cancelled
          if (status == 'Cancelled') return false;

          return appodate.compareTo(dateOnlyTimestamp) >= 0 && 
                 appodate.compareTo(tomorrowTimestamp) < 0;
        }).map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['timeSlot'] as String? ?? data['time_slot'] as String? ?? '';
        }).where((slot) => slot.isNotEmpty)
          .toList();

        // Sanitize selection
        if (_selectedTimeSlot != null && !_timeSlots.contains(_selectedTimeSlot)) {
          _selectedTimeSlot = null;
        }
      });
    } catch (e) {
      debugPrint("Error loading slots: $e");
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

  void _handleBooking() async {
    if (_selectedPatientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a patient")));
      return;
    }
    if (_selectedDoctorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a doctor")));
      return;
    }
    if (_selectedTimeSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a time slot")));
      return;
    }

    // Show payment confirmation
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
                color: accentColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.event_available_rounded, color: accentColor, size: 48),
            ),
            const SizedBox(height: 20),
            const Text(
              "Confirm Appointment",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor),
            ),
            const SizedBox(height: 12),
            Text(
              "Book appointment for $_selectedPatientName with Dr. $_selectedDoctorName?",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14, height: 1.4),
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
                    child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    key: const ValueKey('submit_staff_booking'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _processBooking();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("Confirm", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _processBooking() async {
    setState(() => _isLoading = true);
    try {
      // 1. Calculate Token Number for the selected date
      final dateOnly = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      final tomorrow = dateOnly.add(const Duration(days: 1));

      final countSnapshot = await _firestore
          .collection('appointments')
          .where('appodate', isGreaterThanOrEqualTo: Timestamp.fromDate(dateOnly))
          .where('appodate', isLessThan: Timestamp.fromDate(tomorrow))
          .get();

      final nextToken = countSnapshot.docs.length + 1;

      // 2. Create Appointment with consultation fee
      await _firestore.collection('appointments').add({
        'patientId': _selectedPatientId,
        'doctorId': _selectedDoctorId,
        'doctorName': _selectedDoctorName,
        'patientName': _selectedPatientName,
        'appodate': Timestamp.fromDate(dateOnly),
        'timeSlot': _selectedTimeSlot,
        'tokenno': nextToken,
        'status': 'Booked',
        'consultationFee': _selectedDoctorFee,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 3. Send automated email confirmation to patient
      if (_selectedPatientId != null) {
        final patientDoc = await _firestore.collection('patients').doc(_selectedPatientId).get();
        if (patientDoc.exists) {
          final patientData = patientDoc.data() as Map<String, dynamic>;
          final String? patientEmail = patientData['email'];
          if (patientEmail != null && patientEmail.isNotEmpty) {
            EmailService.sendAppointmentConfirmation(
              patientName: _selectedPatientName ?? 'Patient',
              patientEmail: patientEmail,
              doctorName: _selectedDoctorName ?? 'Doctor',
              tokenNumber: nextToken,
              date: "${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}",
              timeSlot: _selectedTimeSlot ?? '',
            );
          }
        }
      }

      if (!mounted) return;
      
      // Show success dialog with token info
      _showSuccessDialog(nextToken);
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog(int tokenNumber) {
    final dateStr = "${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}";
    final smsMessage = "Dear $_selectedPatientName, your appointment is confirmed!\n\n"
        "Token: #$tokenNumber\n"
        "Date: $dateStr\n"
        "Time: $_selectedTimeSlot\n"
        "Doctor: Dr. $_selectedDoctorName\n\n"
        "Please arrive 10 minutes early. - DermaScan Clinic";

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle_rounded, size: 56, color: Colors.green.shade600),
              ),
              const SizedBox(height: 20),
              
              const Text(
                "Appointment Booked!",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
              ),
              const SizedBox(height: 16),
              
              // Token Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    const Text("Token Number", style: TextStyle(color: Colors.grey, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(
                      "#$tokenNumber",
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "$dateStr • $_selectedTimeSlot",
                      style: const TextStyle(fontSize: 14, color: textColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Patient & Doctor Info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildInfoRow(Icons.person_rounded, "Patient", _selectedPatientName ?? ""),
                    const SizedBox(height: 8),
                    _buildInfoRow(Icons.medical_services_rounded, "Doctor", "Dr. $_selectedDoctorName"),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              // Send SMS Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _sendSMSToPatient(smsMessage),
                  icon: const Icon(Icons.sms_rounded, size: 20),
                  label: const Text("Send SMS to Patient", style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              
              // Done Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context, true);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: textColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Done", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendSMSToPatient(String message) async {
    if (_selectedPatientPhone == null || _selectedPatientPhone!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Patient phone number not available'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final Uri smsUri = Uri(
      scheme: 'sms',
      path: _selectedPatientPhone,
      queryParameters: {'body': message},
    );

    try {
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Opening SMS app...'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 1),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SMS app not available'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: accentColor),
        const SizedBox(width: 8),
        Text("$label: ", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: textColor),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      selectableDayPredicate: (DateTime date) {
        // If doctor has working days defined, only allow those days
        if (_doctorWorkDays.isEmpty) return true;
        return _doctorWorkDays.contains(date.weekday);
      },
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: accentColor)),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _selectedTimeSlot = null; // Reset time slot when date changes
      });
      _loadBookedSlots();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Book New Appointment",
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabel("Select Patient"),
              _buildPatientSelector(),
              
              const SizedBox(height: 24),
              _buildLabel("Select Specialist"),
              _buildDoctorSelector(),

              const SizedBox(height: 24),
              _buildLabel("Appointment Date"),
              InkWell(
                onTap: () => _selectDate(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: inputFill,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}",
                        style: const TextStyle(fontSize: 16, color: textColor),
                      ),
                      const Icon(Icons.calendar_month_outlined, color: accentColor),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),
              _buildLabel("Select Time Slot"),
              _buildTimeSlotSelector(),

              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleBooking,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Confirm Appointment", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
    );
  }

  Widget _buildTimeSlotSelector() {
    if (_selectedDoctorId == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: inputFill, borderRadius: BorderRadius.circular(12)),
        child: const Center(child: Text("Select a doctor to view slots", style: TextStyle(color: Colors.grey))),
      );
    }

    if (_isLoading) {
      return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: accentColor)));
    }

    if (_timeSlots.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: const Column(
          children: [
            Icon(Icons.event_busy_rounded, color: Colors.orange, size: 32),
            SizedBox(height: 8),
            Text("No Availability Set", style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
            Text("The doctor hasn't enabled any slots for this date.", textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      );
    }

    final now = DateTime.now();
    final isToday = _selectedDate.year == now.year && 
                    _selectedDate.month == now.month && 
                    _selectedDate.day == now.day;
    
    int slotIndex = 0;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      key: const ValueKey('time_slots_grid'),
      children: _timeSlots.map((slot) {
        final currentSlotIndex = slotIndex++;
        final isBooked = _bookedSlots.contains(slot);
        final isSelected = _selectedTimeSlot == slot;
        
        // Check if slot is in the past for today
        bool isPast = false;
        if (isToday) {
          final slotParts = slot.split(' ');
          final timeParts = slotParts[0].split(':');
          int hour = int.parse(timeParts[0]);
          final minute = int.parse(timeParts[1]);
          if (slotParts[1] == 'PM' && hour != 12) hour += 12;
          if (slotParts[1] == 'AM' && hour == 12) hour = 0;
          final slotTime = DateTime(now.year, now.month, now.day, hour, minute);
          isPast = slotTime.isBefore(now);
        }
        
        final isUnavailable = isBooked || isPast;
        
        return GestureDetector(
          key: ValueKey('slot_$currentSlotIndex'),
          onTap: isUnavailable ? null : () {
            setState(() => _selectedTimeSlot = slot);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isUnavailable 
                  ? Colors.red.shade50 
                  : isSelected 
                      ? accentColor 
                      : inputFill,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isUnavailable 
                    ? Colors.red.shade300 
                    : isSelected 
                        ? accentColor 
                        : Colors.transparent,
                width: 2,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  slot,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isUnavailable 
                        ? Colors.red.shade400 
                        : isSelected 
                            ? Colors.white 
                            : textColor,
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
    );
  }

  Widget _buildPatientSelector() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('patients').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();
        var items = snapshot.data!.docs;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: inputFill, borderRadius: BorderRadius.circular(12)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              key: const ValueKey('select_patient_dropdown'),
              hint: const Text("Choose Patient"),
              value: _selectedPatientId,
              isExpanded: true,
              items: items.asMap().entries.map((entry) {
                int idx = entry.key;
                var doc = entry.value;
                return DropdownMenuItem(
                  key: ValueKey('patient_option_$idx'),
                  value: doc.id,
                  child: Text(doc['name'] ?? 'Unknown'),
                );
              }).toList(),
              onChanged: (val) {
                final selectedDoc = items.firstWhere((d) => d.id == val);
                final data = selectedDoc.data() as Map<String, dynamic>;
                setState(() {
                  _selectedPatientId = val;
                  _selectedPatientName = data['name'] ?? 'Unknown';
                  _selectedPatientPhone = data['phone'] ?? '';
                });
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildDoctorSelector() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('doctors').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();
        var items = snapshot.data!.docs;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: inputFill, borderRadius: BorderRadius.circular(12)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              key: const ValueKey('select_doctor_dropdown'),
              hint: const Text("Choose Doctor"),
              value: _selectedDoctorId,
              isExpanded: true,
              items: items.asMap().entries.map((entry) {
                int idx = entry.key;
                var doc = entry.value;
                final data = doc.data() as Map<String, dynamic>;
                final fee = (data['consultationFee'] ?? 0).toDouble();
                return DropdownMenuItem(
                  key: ValueKey('doctor_option_$idx'),
                  value: doc.id,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text("Dr. ${doc['name']} (${doc['specialization']})"),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "₹${fee.toStringAsFixed(0)}",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) {
                final selectedDoc = items.firstWhere((d) => d.id == val);
                
                // Get doctor's working days from their schedule
                final weeklySchedule = selectedDoc['weeklySchedule'] as Map<String, dynamic>?;
                List<int> workDays = [];
                if (weeklySchedule != null && weeklySchedule['days'] != null) {
                  workDays = (weeklySchedule['days'] as List)
                      .map((d) => d is int ? d : int.tryParse(d.toString()) ?? 0)
                      .toList();
                }
                
                // Get doctor's consultation fee
                final doctorData = selectedDoc.data() as Map<String, dynamic>;
                final consultationFee = (doctorData['consultationFee'] ?? 0.0).toDouble();
                
                setState(() {
                  _selectedDoctorId = val;
                  _selectedDoctorName = selectedDoc['name'];
                  _selectedDoctorFee = consultationFee;
                  _selectedTimeSlot = null;
                  _doctorWorkDays = workDays;
                  
                  // Auto-select first available working day
                  if (workDays.isNotEmpty) {
                    for (int i = 0; i < 30; i++) {
                      final date = DateTime.now().add(Duration(days: i));
                      if (workDays.contains(date.weekday)) {
                        _selectedDate = date;
                        break;
                      }
                    }
                  }
                });
                _loadBookedSlots();
              },
            ),
          ),
        );
      },
    );
  }
}
