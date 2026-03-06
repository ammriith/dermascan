import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:dermascan/services/notification_service.dart';

class PatientRemindersPage extends StatefulWidget {
  const PatientRemindersPage({super.key});

  @override
  State<PatientRemindersPage> createState() => _PatientRemindersPageState();
}

class _PatientRemindersPageState extends State<PatientRemindersPage> {
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
  static const Color pinkAccent = Color(0xFFEC4899);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = true;
  
  // Medications, Suggestions & Reminders
  List<Map<String, dynamic>> _medications = [];
  List<Map<String, dynamic>> _doctorSuggestions = [];
  List<Map<String, dynamic>> _consultationReminders = [];

  @override
  void initState() {
    super.initState();
    _loadMedicationsAndSuggestions();
  }

  Future<void> _loadMedicationsAndSuggestions() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Load all appointments to check for completions and upcoming reminders
      final appointmentsSnapshot = await _firestore
          .collection('appointments')
          .where('patientId', isEqualTo: userId)
          .get();

      _medications = [];
      _doctorSuggestions = [];
      _consultationReminders = [];

      for (var doc in appointmentsSnapshot.docs) {
        final data = doc.data();
        final status = data['status'] ?? '';
        
        // 1. Process Completed Appointments (Medications & Suggestions)
        if (status == 'Completed') {
          if (data['medications'] != null && (data['medications'] as String).isNotEmpty) {
            _medications.add({
              'id': doc.id,
              'medication': data['medications'],
              'doctorName': data['doctorName'] ?? 'Doctor',
              'date': data['appodate'],
            });
          }
          if (data['doctorNotes'] != null && (data['doctorNotes'] as String).isNotEmpty) {
            _doctorSuggestions.add({
              'id': doc.id,
              'suggestion': data['doctorNotes'],
              'doctorName': data['doctorName'] ?? 'Doctor',
              'date': data['appodate'],
            });
          }
        }

        // 2. Process Upcoming Reminders (Only show future dates)
        final appoDate = (data['appodate'] as Timestamp?)?.toDate();
        if ((status == 'Booked' || status == 'Waiting') && 
            data['reminderSent'] == true && 
            appoDate != null && 
            appoDate.isAfter(DateTime.now())) {
          _consultationReminders.add({
            'id': doc.id,
            'type': 'Appointment Reminder',
            'doctorName': data['doctorName'] ?? 'Doctor',
            'date': data['appodate'],
            'timeSlot': data['timeSlot'] ?? '',
            'reminderAt': data['reminderAt'],
          });

          // Proximity notification for appointment
          NotificationService().checkAndNotifyProximity(
            id: doc.id,
            title: '📅 Appointment Tomorrow',
            body: 'You have an appointment with Dr. ${data['doctorName'] ?? 'Doctor'} at ${data['timeSlot'] ?? 'scheduled time'}',
            scheduledTime: appoDate,
          );
        }
      }

      // Sort consultation reminders by original appointment date
      _consultationReminders.sort((a, b) {
        final aDate = (a['date'] as Timestamp?)?.toDate() ?? DateTime.now();
        final bDate = (b['date'] as Timestamp?)?.toDate() ?? DateTime.now();
        return aDate.compareTo(bDate); // Newest appointment first if you want, or soonest
      });

      // Also load from prescriptions (New report type)
      final prescriptionsSnapshot = await _firestore
          .collection('prescriptions')
          .where('patientId', isEqualTo: userId)
          .get();

      for (var doc in prescriptionsSnapshot.docs) {
        final data = doc.data();
        if (data['medications'] != null && (data['medications'] as String).trim().isNotEmpty) {
          _medications.add({
            'id': doc.id,
            'medication': data['medications'],
            'doctorName': data['doctorName'] ?? 'Doctor',
            'date': data['createdAt'],
            'diagnosis': data['diagnosis'],
            'notes': data['notes'],
          });
        }
      }

      // Also load from doctor_suggestions (Direct from doctor feedback)
      final suggestionsSnapshot = await _firestore
          .collection('doctor_suggestions')
          .where('patientId', isEqualTo: userId)
          .get();

      for (var doc in suggestionsSnapshot.docs) {
        final data = doc.data();
        if (data['suggestion'] != null && (data['suggestion'] as String).trim().isNotEmpty) {
          _doctorSuggestions.add({
            'id': doc.id,
            'suggestion': data['suggestion'],
            'doctorName': data['doctorName'] ?? 'Doctor',
            'date': data['createdAt'],
          });
        }
        if (data['medication'] != null && (data['medication'] as String).trim().isNotEmpty) {
          _medications.add({
            'id': doc.id,
            'medication': data['medication'],
            'doctorName': data['doctorName'] ?? 'Doctor',
            'date': data['createdAt'],
          });
        }
        
        // Add follow-up reminders if doctor set a date (Only show future dates)
        final followUp = (data['followUpDate'] as Timestamp?)?.toDate();
        if (followUp != null && followUp.isAfter(DateTime.now())) {
          String timeStr = data['followUpTime'] ?? '';
          if (timeStr.isEmpty) {
            timeStr = DateFormat('hh:mm a').format(followUp);
          }

          _consultationReminders.add({
            'id': doc.id,
            'doctorName': data['doctorName'] ?? 'Doctor',
            'date': data['followUpDate'],
            'type': 'Follow-up Recommendation',
            'notes': data['suggestion'] ?? 'Recommended follow-up visit',
            'timeSlot': timeStr,
          });

          // Proximity notification for follow-up
          NotificationService().checkAndNotifyProximity(
            id: doc.id,
            title: '🔔 Consultation Reminder',
            body: 'Recommended follow-up visit with Dr. ${data['doctorName'] ?? 'Doctor'} tomorrow',
            scheduledTime: followUp,
          );
        }
      }

      // Sort by date (newest first)
      _medications.sort((a, b) {
        final aDate = (a['date'] as Timestamp?)?.toDate() ?? DateTime.now();
        final bDate = (b['date'] as Timestamp?)?.toDate() ?? DateTime.now();
        return bDate.compareTo(aDate);
      });

      _doctorSuggestions.sort((a, b) {
        final aDate = (a['date'] as Timestamp?)?.toDate() ?? DateTime.now();
        final bDate = (b['date'] as Timestamp?)?.toDate() ?? DateTime.now();
        return bDate.compareTo(aDate);
      });

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error loading medications: $e');
      if (mounted) setState(() => _isLoading = false);
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
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: primaryColor))
                  : _buildContent(),
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
                  "Reminders",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textPrimary),
                ),
                Text(
                  "Medications & Treatment Reminders",
                  style: TextStyle(fontSize: 12, color: textSecondary),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: pinkAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.medical_services_rounded, size: 20, color: pinkAccent),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_medications.isEmpty && _doctorSuggestions.isEmpty && _consultationReminders.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _isLoading = true);
        await _loadMedicationsAndSuggestions();
      },
      color: primaryColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // Medications Section (High Priority)
            if (_medications.isNotEmpty) ...[
              _buildSectionHeader("💊 Medication Reminders", _medications.length, pinkAccent),
              const SizedBox(height: 12),
              ..._medications.map((m) => _buildMedicationCard(m)),
              const SizedBox(height: 24),
            ],

            // Consultation Reminders
            if (_consultationReminders.isNotEmpty) ...[
              _buildSectionHeader("🔔 Upcoming Consultations", _consultationReminders.length, primaryColor),
              const SizedBox(height: 12),
              ..._consultationReminders.map((r) => _buildUpcomingReminderCard(r)),
              const SizedBox(height: 24),
            ],


            _buildHealthTipsCard(),
          ],
        ),
      ),
    );
  }


  Widget _buildSectionHeader(String title, int count, Color color) {
    return Row(
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text("$count", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        ),
      ],
    );
  }

  Widget _buildMedicationCard(Map<String, dynamic> medication) {
    final date = (medication['date'] as Timestamp?)?.toDate();
    final dateStr = date != null ? DateFormat('MMM dd, yyyy').format(date) : '';

    return GestureDetector(
      onTap: () => _showMedicationDetailsDialog(medication),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: pinkAccent.withValues(alpha: 0.2)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: pinkAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.medication_rounded, color: pinkAccent, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          "Prescribed by Dr. ${medication['doctorName']}",
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary),
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: textSecondary, size: 20),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(dateStr, style: const TextStyle(fontSize: 11, color: textSecondary)),
                      if (medication['diagnosis'] != null && (medication['diagnosis'] as String).isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text("•", style: TextStyle(color: Colors.grey.shade400)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            medication['diagnosis'],
                            style: const TextStyle(fontSize: 11, color: pinkAccent, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: pinkAccent.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: pinkAccent.withValues(alpha: 0.1)),
                    ),
                    child: Text(
                      medication['medication'],
                      style: const TextStyle(fontSize: 14, color: textPrimary, height: 1.5),
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

  void _showMedicationDetailsDialog(Map<String, dynamic> med) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          top: 24,
          left: 24,
          right: 24,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: pinkAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.medication_rounded, color: pinkAccent, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Consultation Details",
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textPrimary),
                        ),
                        Text(
                          "Dr. ${med['doctorName']}",
                          style: const TextStyle(fontSize: 14, color: textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              const Text("DIAGNOSIS", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textSecondary, letterSpacing: 1)),
              const SizedBox(height: 8),
              Text(
                med['diagnosis'] ?? 'No primary diagnosis recorded',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary),
              ),
              const SizedBox(height: 20),

              const Text("CONSULTATION NOTES", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textSecondary, letterSpacing: 1)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  med['notes'] ?? 'No clinical notes were recorded for this visit.',
                  style: const TextStyle(fontSize: 14, color: textPrimary, height: 1.6),
                ),
              ),
              const SizedBox(height: 20),

              const Text("MEDICINES PRESCRIBED", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textSecondary, letterSpacing: 1)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: pinkAccent.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: pinkAccent.withValues(alpha: 0.1)),
                ),
                child: Text(
                  med['medication'],
                  style: const TextStyle(fontSize: 15, color: textPrimary, fontWeight: FontWeight.w500, height: 1.6),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: pinkAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text("Close", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionCard(Map<String, dynamic> suggestion) {
    final date = (suggestion['date'] as Timestamp?)?.toDate();
    final dateStr = date != null ? DateFormat('MMM dd, yyyy').format(date) : '';
    final isAI = suggestion['isAI'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: (isAI ? purpleAccent : blueAccent).withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (isAI ? purpleAccent : blueAccent).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isAI ? Icons.smart_toy_rounded : Icons.lightbulb_rounded, 
              color: isAI ? purpleAccent : blueAccent, 
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isAI ? "AI Analysis" : "Dr. ${suggestion['doctorName']}",
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary),
                    ),
                    if (isAI) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [purpleAccent, purpleAccent.withValues(alpha: 0.7)],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_awesome, size: 10, color: Colors.white),
                            SizedBox(width: 4),
                            Text("AI", style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(dateStr, style: const TextStyle(fontSize: 11, color: textSecondary)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (isAI ? purpleAccent : blueAccent).withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: (isAI ? purpleAccent : blueAccent).withValues(alpha: 0.1)),
                  ),
                  child: Text(
                    suggestion['suggestion'],
                    style: const TextStyle(fontSize: 14, color: textPrimary, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingReminderCard(Map<String, dynamic> reminder) {
    final appoDate = (reminder['date'] as Timestamp?)?.toDate();
    final dateStr = appoDate != null ? DateFormat('MMM dd, yyyy').format(appoDate) : '';
    final timeStr = reminder['timeSlot'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor.withValues(alpha: 0.1), bgColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: primaryColor.withValues(alpha: 0.2), blurRadius: 8)],
            ),
            child: const Icon(Icons.notifications_active_rounded, color: primaryColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reminder['type'] ?? "Consultation Reminder",
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  "Dr. ${reminder['doctorName']} is expecting you",
                  style: const TextStyle(fontSize: 13, color: textSecondary),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_month_rounded, size: 14, color: primaryColor),
                      const SizedBox(width: 6),
                      Text(dateStr, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
                      const SizedBox(width: 12),
                      const Icon(Icons.access_time_rounded, size: 14, color: primaryColor),
                      const SizedBox(width: 6),
                      Text(timeStr, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
                color: greenAccent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: greenAccent, size: 60),
            ),
            const SizedBox(height: 24),
            const Text(
              "No Reminders Yet",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              "Your medication reminders and\ndoctor's suggestions will appear here\nafter your consultations",
              textAlign: TextAlign.center,
              style: TextStyle(color: textSecondary, height: 1.5),
            ),
            const SizedBox(height: 32),
            _buildHealthTipsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthTipsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [greenAccent.withValues(alpha: 0.1), primaryColor.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: greenAccent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: greenAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.favorite_rounded, color: greenAccent, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                "Daily Health Tips",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTipItem("💧", "Stay hydrated - Drink 8 glasses of water daily"),
          _buildTipItem("🌞", "Get 15-20 minutes of morning sunlight for Vitamin D"),
          _buildTipItem("😴", "Aim for 7-8 hours of quality sleep every night"),
          _buildTipItem("🏃", "Exercise at least 30 minutes daily"),
          _buildTipItem("🥗", "Eat a balanced diet with fruits and vegetables"),
        ],
      ),
    );
  }

  Widget _buildTipItem(String emoji, String tip) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(tip, style: const TextStyle(fontSize: 13, color: textSecondary, height: 1.4)),
          ),
        ],
      ),
    );
  }
}
