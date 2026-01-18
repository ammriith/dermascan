import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

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
  DateTime _selectedDate = DateTime.now();
  String? _selectedTimeSlot;
  bool _isLoading = false;

  // Time slots available for booking
  final List<String> _timeSlots = [
    "09:00 AM",
    "09:30 AM",
    "10:00 AM",
    "10:30 AM",
    "11:00 AM",
    "11:30 AM",
    "12:00 PM",
    "02:00 PM",
    "02:30 PM",
    "03:00 PM",
    "03:30 PM",
    "04:00 PM",
    "04:30 PM",
    "05:00 PM",
  ];

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

    final snapshot = await _firestore
        .collection('appointments')
        .where('doctor_id', isEqualTo: _selectedDoctorId)
        .where('appodate', isGreaterThanOrEqualTo: Timestamp.fromDate(dateOnly))
        .where('appodate', isLessThan: Timestamp.fromDate(tomorrow))
        .get();

    setState(() {
      _bookedSlots = snapshot.docs
          .map((doc) => doc.data()['time_slot'] as String? ?? '')
          .where((slot) => slot.isNotEmpty)
          .toList();
    });
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

      // 2. Create Appointment
      await _firestore.collection('appointments').add({
        'patient_id': _selectedPatientId,
        'doctor_id': _selectedDoctorId,
        'doctor_name': _selectedDoctorName,
        'patient_name': _selectedPatientName,
        'appodate': Timestamp.fromDate(dateOnly),
        'time_slot': _selectedTimeSlot,
        'tokenno': nextToken,
        'status': 'Booked',
        'createdAt': FieldValue.serverTimestamp(),
      });

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
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _timeSlots.map((slot) {
        final isBooked = _bookedSlots.contains(slot);
        final isSelected = _selectedTimeSlot == slot;
        
        return GestureDetector(
          onTap: isBooked ? null : () {
            setState(() => _selectedTimeSlot = slot);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isBooked 
                  ? Colors.grey.shade200 
                  : isSelected 
                      ? accentColor 
                      : inputFill,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isBooked 
                    ? Colors.grey.shade300 
                    : isSelected 
                        ? accentColor 
                        : Colors.transparent,
                width: 2,
              ),
            ),
            child: Text(
              slot,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isBooked 
                    ? Colors.grey.shade400 
                    : isSelected 
                        ? Colors.white 
                        : textColor,
                decoration: isBooked ? TextDecoration.lineThrough : null,
              ),
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
              hint: const Text("Choose Patient"),
              value: _selectedPatientId,
              isExpanded: true,
              items: items.map((doc) {
                return DropdownMenuItem(
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
              hint: const Text("Choose Doctor"),
              value: _selectedDoctorId,
              isExpanded: true,
              items: items.map((doc) {
                return DropdownMenuItem(
                  value: doc.id,
                  child: Text("Dr. ${doc['name']} (${doc['specialization']})"),
                );
              }).toList(),
              onChanged: (val) {
                setState(() {
                  _selectedDoctorId = val;
                  _selectedDoctorName = items.firstWhere((d) => d.id == val)['name'];
                  _selectedTimeSlot = null; // Reset time slot when doctor changes
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
