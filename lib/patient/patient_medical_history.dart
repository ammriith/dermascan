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

class _PatientMedicalHistoryPageState extends State<PatientMedicalHistoryPage> with SingleTickerProviderStateMixin {
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

  late TabController _tabController;
  bool _isLoading = true;
  
  List<Map<String, dynamic>> _scanResults = [];
  Map<String, dynamic> _stats = {};

  // Stream subscriptions for real-time updates
  StreamSubscription<QuerySnapshot>? _scansSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _setupRealtimeListeners();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scansSubscription?.cancel();
    super.dispose();
  }

  void _setupRealtimeListeners() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }


    // Real-time listener for scan results
    _scansSubscription = _firestore
        .collection('scan_results')
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
      if (mounted) setState(() {});
    }, onError: (e) {
      debugPrint('Error listening to scans: $e');
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
            if (!_isLoading) _buildStatsCards(),
            _buildTabBar(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: primaryColor))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildReportsTab(),
                        _buildTimelineTab(),
                      ],
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
                  "Medical History",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textPrimary),
                ),
                Text(
                  "Your reports & timeline",
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

  Widget _buildStatsCards() {
    return Container(
      height: 100,
      margin: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        children: [
          _buildStatCard(
            "${_stats['totalScans'] ?? 0}",
            "Total Reports",
            Icons.description_rounded,
            primaryColor,
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            "${_stats['severeCount'] ?? 0}",
            "Severe Alerts",
            Icons.warning_amber_rounded,
            redAccent,
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            _stats['latestScan'] == 'None' ? 'N/A' : 'Latest',
            _stats['latestScan'] ?? 'None',
            Icons.history_toggle_off_rounded,
            purpleAccent,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 10)],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: const TextStyle(fontSize: 11, color: textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: primaryColor,
          borderRadius: BorderRadius.circular(14),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: textSecondary,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        tabs: const [
          Tab(text: "Reports"),
          Tab(text: "Timeline"),
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
    final condition = report['condition'] ?? 'Unknown';
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
                        ),
                        Text(dateStr, style: const TextStyle(fontSize: 11, color: textSecondary)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: severityColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      severity,
                      style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
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
    final condition = report['condition'] ?? 'Unknown';
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

  Widget _buildTimelineTab() {
    // Combine appointments and scans into a timeline
    List<Map<String, dynamic>> timeline = [];
    
    for (var scan in _scanResults) {
      timeline.add({
        'type': 'scan',
        'date': (scan['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        'data': scan,
      });
    }
    
    // Sort by date (newest first)
    timeline.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

    if (timeline.isEmpty) {
      return _buildEmptyState(
        Icons.timeline_rounded,
        "No History",
        "Your medical timeline will appear here",
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      color: primaryColor,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        itemCount: timeline.length,
        itemBuilder: (ctx, index) => _buildTimelineItem(timeline[index], index == timeline.length - 1),
      ),
    );
  }

  Widget _buildTimelineItem(Map<String, dynamic> item, bool isLast) {
    final type = item['type'] as String;
    final date = item['date'] as DateTime;
    final data = item['data'] as Map<String, dynamic>;
    
    final severity = (data['severity'] ?? 'Unknown').toString().toLowerCase();
    final Color dotColor = severity == 'mild' ? greenAccent : (severity == 'moderate' ? orangeAccent : redAccent);
    final IconData icon = Icons.biotech_rounded;
    final String title = data['condition'] ?? 'Skin Analysis';
    final String subtitle = "Severity: ${data['severity'] ?? 'Unknown'}";

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline line and dot
          SizedBox(
            width: 60,
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: dotColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: dotColor, width: 2),
                  ),
                  child: Icon(icon, color: dotColor, size: 18),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: Colors.grey.shade200,
                    ),
                  ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('MMM dd, yyyy • hh:mm a').format(date),
                    style: TextStyle(fontSize: 11, color: dotColor, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

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
