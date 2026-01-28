import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

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
  
  // Medications & Suggestions
  List<Map<String, dynamic>> _medications = [];
  List<Map<String, dynamic>> _doctorSuggestions = [];

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
      // Load medications from completed appointments
      final appointmentsSnapshot = await _firestore
          .collection('appointments')
          .where('patientId', isEqualTo: userId)
          .where('status', isEqualTo: 'Completed')
          .get();

      _medications = [];
      _doctorSuggestions = [];

      for (var doc in appointmentsSnapshot.docs) {
        final data = doc.data();
        
        // Check for medications
        if (data['medications'] != null && (data['medications'] as String).isNotEmpty) {
          _medications.add({
            'id': doc.id,
            'medication': data['medications'],
            'doctorName': data['doctorName'] ?? 'Doctor',
            'date': data['appodate'],
          });
        }

        // Check for doctor suggestions/notes
        if (data['doctorNotes'] != null && (data['doctorNotes'] as String).isNotEmpty) {
          _doctorSuggestions.add({
            'id': doc.id,
            'suggestion': data['doctorNotes'],
            'doctorName': data['doctorName'] ?? 'Doctor',
            'date': data['appodate'],
          });
        }
      }

      // Also load from scan_results for AI suggestions
      final scansSnapshot = await _firestore
          .collection('scan_results')
          .where('patientId', isEqualTo: userId)
          .get();

      for (var doc in scansSnapshot.docs) {
        final data = doc.data();
        if (data['recommendations'] != null && (data['recommendations'] as String).isNotEmpty) {
          _doctorSuggestions.add({
            'id': doc.id,
            'suggestion': data['recommendations'],
            'doctorName': 'AI Analysis',
            'date': data['createdAt'],
            'isAI': true,
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
                  "Medications & Doctor Suggestions",
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
            child: Badge(
              label: Text('${_medications.length + _doctorSuggestions.length}'),
              isLabelVisible: _medications.isNotEmpty || _doctorSuggestions.isNotEmpty,
              child: const Icon(Icons.medical_services_rounded, size: 20, color: pinkAccent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_medications.isEmpty && _doctorSuggestions.isEmpty) {
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
            // Quick Stats
            _buildQuickStats(),
            const SizedBox(height: 24),

            // Medications Section
            if (_medications.isNotEmpty) ...[
              _buildSectionHeader("💊 Medication Reminders", _medications.length, pinkAccent),
              const SizedBox(height: 12),
              ..._medications.map((m) => _buildMedicationCard(m)),
              const SizedBox(height: 24),
            ],

            // Doctor Suggestions Section
            if (_doctorSuggestions.isNotEmpty) ...[
              _buildSectionHeader("💬 Doctor's Suggestions", _doctorSuggestions.length, blueAccent),
              const SizedBox(height: 12),
              ..._doctorSuggestions.map((s) => _buildSuggestionCard(s)),
              const SizedBox(height: 24),
            ],

            _buildHealthTipsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats() {
    return Container(
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
          Expanded(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.medication_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(height: 8),
                Text(
                  "${_medications.length}",
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                Text(
                  "Medications",
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 60, color: Colors.white.withValues(alpha: 0.3)),
          Expanded(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.lightbulb_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(height: 8),
                Text(
                  "${_doctorSuggestions.length}",
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                Text(
                  "Suggestions",
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11),
                ),
              ],
            ),
          ),
        ],
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

    return Container(
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
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  dateStr,
                  style: const TextStyle(fontSize: 11, color: textSecondary),
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
