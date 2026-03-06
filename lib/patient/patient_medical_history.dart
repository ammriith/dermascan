import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class PatientMedicalHistoryPage extends StatefulWidget {
  const PatientMedicalHistoryPage({super.key});

  @override
  State<PatientMedicalHistoryPage> createState() => _PatientMedicalHistoryPageState();
}

class _PatientMedicalHistoryPageState extends State<PatientMedicalHistoryPage> {
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
  static const Color redAccent = Color(0xFFEF4444);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late bool _isLoading = true;
  
  List<Map<String, dynamic>> _scanResults = [];
  Map<String, dynamic> _stats = {};

  // Stream subscriptions for real-time updates
  StreamSubscription<QuerySnapshot>? _scansSubscription;

  @override
  void initState() {
    super.initState();
    _setupRealtimeListeners();
  }

  @override
  void dispose() {
    _scansSubscription?.cancel();
    super.dispose();
  }

  void _setupRealtimeListeners() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    // Set a timeout to stop loading if no data comes in (e.g. offline)
    Timer(const Duration(seconds: 5), () {
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    });

    // Real-time listener for scan results
    _scansSubscription = _firestore
        .collection('predictions')
        .where('patientId', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) {
      _scanResults = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      // Sort scans by date (newest first)
      _scanResults.sort((a, b) {
        final aDate = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        final bDate = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        return bDate.compareTo(aDate);
      });

      _updateStats();
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }, onError: (e) {
      debugPrint('Error listening to scans: $e');
      if (mounted) setState(() => _isLoading = false);
    });
  }



  void _updateStats() {
    _stats = {
      'totalScans': _scanResults.length,
      'latestScan': _scanResults.isNotEmpty ? _scanResults.first['condition'] : 'None',
      'severeCount': _scanResults.where((s) => s['severity']?.toString().toLowerCase() == 'severe').length,
    };
  }

  Future<void> _refreshData() async {
    // Force refresh by re-setting up listeners
    _scansSubscription?.cancel();
    setState(() => _isLoading = true);
    _setupRealtimeListeners();
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
                  : _buildReportsTab(),
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
                  "Medical History",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textPrimary),
                ),
                Text(
                  "Your scan reports",
                  style: TextStyle(fontSize: 12, color: textSecondary),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _refreshData,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.refresh_rounded, size: 20, color: primaryColor),
            ),
          ),
        ],
      ),
    );
  }




  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 1: APPOINTMENTS
  // ═══════════════════════════════════════════════════════════════════════════


  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 2: REPORTS (SCAN RESULTS)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildReportsTab() {
    if (_scanResults.isEmpty) {
      return _buildEmptyState(
        Icons.description_rounded,
        "No Reports",
        "Your medical reports will appear here",
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      color: primaryColor,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        itemCount: _scanResults.length,
        itemBuilder: (ctx, index) => _buildReportCard(_scanResults[index]),
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report) {
    final condition = report['prediction'] ?? report['condition'] ?? 'Unknown';
    final confidence = report['confidence'] ?? 0.0;
    final severity = report['severity'] ?? 'Unknown';
    final recommendations = report['recommendations'] as List<dynamic>? ?? [];
    
    final createdAt = report['createdAt'] as Timestamp?;
    String dateStr = 'N/A';
    if (createdAt != null) {
      dateStr = DateFormat('MMM dd, yyyy • hh:mm a').format(createdAt.toDate());
    }
    
    Color severityColor;
    switch (severity.toString().toLowerCase()) {
      case 'mild':
        severityColor = greenAccent;
        break;
      case 'moderate':
        severityColor = orangeAccent;
        break;
      case 'severe':
        severityColor = redAccent;
        break;
      default:
        severityColor = blueAccent;
    }

    return GestureDetector(
      onTap: () => _showReportDetails(report),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)],
        ),
        child: Column(
          children: [
            // Header with severity
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [severityColor.withValues(alpha: 0.1), severityColor.withValues(alpha: 0.05)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.biotech_rounded, color: severityColor, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          condition,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        Text(dateStr, style: const TextStyle(fontSize: 11, color: textSecondary)),
                      ],
                    ),
                  ),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: severityColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        severity,
                        style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Confidence meter
                  Row(
                    children: [
                      const Text("Confidence", style: TextStyle(fontSize: 12, color: textSecondary)),
                      const Spacer(),
                      Text(
                        "${(confidence * 100).toStringAsFixed(1)}%",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: severityColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: confidence,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(severityColor),
                      minHeight: 6,
                    ),
                  ),
                  if (recommendations.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.lightbulb_outline_rounded, size: 16, color: orangeAccent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            recommendations.first.toString(),
                            style: const TextStyle(fontSize: 12, color: textSecondary),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Spacer(),
                      Text("Tap to view details", style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right_rounded, size: 16, color: Colors.grey.shade400),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showReportDetails(Map<String, dynamic> report) {
    final condition = report['prediction'] ?? report['condition'] ?? 'Unknown';
    final confidence = report['confidence'] ?? 0.0;
    final severity = report['severity'] ?? 'Unknown';
    final recommendations = report['recommendations'] as List<dynamic>? ?? [];
    final description = report['description'] ?? 'No description available';
    
    final createdAt = report['createdAt'] as Timestamp?;
    String dateStr = 'N/A';
    if (createdAt != null) {
      dateStr = DateFormat('MMMM dd, yyyy • hh:mm a').format(createdAt.toDate());
    }

    Color severityColor;
    switch (severity.toString().toLowerCase()) {
      case 'mild':
        severityColor = greenAccent;
        break;
      case 'moderate':
        severityColor = orangeAccent;
        break;
      case 'severe':
        severityColor = redAccent;
        break;
      default:
        severityColor = blueAccent;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (ctx, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.all(24),
                  children: [
                    // Image Preview (if available)
                    if (report['imageUrl'] != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.network(
                          report['imageUrl'],
                          height: 250,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              height: 250,
                              color: Colors.grey.shade100,
                              child: const Center(child: CircularProgressIndicator()),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: severityColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(Icons.biotech_rounded, color: severityColor, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                condition,
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textPrimary),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              Text(dateStr, style: const TextStyle(fontSize: 12, color: textSecondary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Stats row
                    Row(
                      children: [
                        Expanded(
                          child: _buildReportStat(
                            "Severity",
                            severity,
                            severityColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildReportStat(
                            "Confidence",
                            "${(confidence * 100).toStringAsFixed(1)}%",
                            primaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Analysis Image
                    if (report['imageUrl'] != null) ...[
                      const Text("Uploaded Image", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary)),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: double.infinity,
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Image.network(
                            report['imageUrl'],
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                            },
                            errorBuilder: (context, error, stackTrace) => const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.broken_image_outlined, color: Colors.grey, size: 32),
                                  SizedBox(height: 8),
                                  Text("Image failed to load", style: TextStyle(color: Colors.grey, fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    
                    // Description
                    const Text("Description", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary)),
                    const SizedBox(height: 8),
                    Text(description, style: const TextStyle(fontSize: 14, color: textSecondary, height: 1.5)),
                    const SizedBox(height: 24),
                    
                    // Recommendations
                    if (recommendations.isNotEmpty) ...[
                      const Text("Recommendations", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary)),
                      const SizedBox(height: 12),
                      ...recommendations.map((rec) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: greenAccent.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: greenAccent.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: greenAccent, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                rec.toString(),
                                style: const TextStyle(fontSize: 13, color: textPrimary),
                              ),
                            ),
                          ],
                        ),
                      )),
                    ],
                    const SizedBox(height: 24),
                    
                    // Disclaimer
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: orangeAccent.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: orangeAccent.withValues(alpha: 0.2)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline_rounded, color: orangeAccent, size: 20),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "This is an AI-generated analysis. Please consult with your doctor for accurate diagnosis and treatment.",
                              style: TextStyle(fontSize: 12, color: textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportStat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: textSecondary)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 3: TIMELINE
  // ═══════════════════════════════════════════════════════════════════════════



  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary)),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(color: textSecondary)),
        ],
      ),
    );
  }
}
