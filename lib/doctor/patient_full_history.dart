import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class PatientFullHistoryPage extends StatefulWidget {
  final String patientId;
  final String patientName;

  const PatientFullHistoryPage({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  @override
  State<PatientFullHistoryPage> createState() => _PatientFullHistoryPageState();
}

class _PatientFullHistoryPageState extends State<PatientFullHistoryPage> with SingleTickerProviderStateMixin {
  // colors
  static const Color primaryColor = Color(0xFF4FD1C5);
  static const Color bgColor = Color(0xFFF8FAFC);
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);
  
  static const Color purpleAccent = Color(0xFF8B5CF6);
  static const Color blueAccent = Color(0xFF3B82F6);
  static const Color greenAccent = Color(0xFF10B981);
  static const Color orangeAccent = Color(0xFFF59E0B);

  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildHistoryList('prescriptions', 'Consultations & Prescriptions'),
                  _buildHistoryList('predictions', 'AI Scan Results'),
                  _buildHistoryList('lab_reports', 'Lab Reports'),
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
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: textPrimary),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Medical History",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textPrimary),
                ),
                Text(
                  widget.patientName,
                  style: const TextStyle(fontSize: 13, color: textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: primaryColor,
        unselectedLabelColor: textSecondary,
        indicatorColor: primaryColor,
        indicatorWeight: 3,
        tabs: const [
          Tab(text: "Visits"),
          Tab(text: "Scans"),
          Tab(text: "Labs"),
        ],
      ),
    );
  }

  Widget _buildHistoryList(String collection, String type) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(collection)
          .where('patientId', isEqualTo: widget.patientId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: primaryColor));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return _buildEmptyState(type);
        }

        // Sort by date
        final sortedDocs = docs.toList();
        sortedDocs.sort((a, b) {
          final aTime = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
          final bTime = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
          if (aTime == null || bTime == null) return 0;
          return bTime.compareTo(aTime);
        });

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: sortedDocs.length,
          itemBuilder: (context, index) {
            final data = sortedDocs[index].data() as Map<String, dynamic>;
            return _buildHistoryCard(data, collection);
          },
        );
      },
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> data, String collection) {
    final createdAt = data['createdAt'] as Timestamp?;
    String dateStr = 'N/A';
    if (createdAt != null) {
      dateStr = DateFormat('MMM dd, yyyy • hh:mm a').format(createdAt.toDate());
    }

    String title = data['title'] ?? data['diagnosis'] ?? data['prediction'] ?? 'Record';
    String? medications = data['medications'];
    String? notes = data['notes'] ?? data['description'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _buildTypeBadge(collection),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            dateStr,
            style: const TextStyle(fontSize: 12, color: textSecondary),
          ),
          if (notes != null && notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              notes,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.5),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (medications != null && medications.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: blueAccent.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: blueAccent.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.medication_rounded, size: 16, color: blueAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Medicine: $medications",
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: blueAccent),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypeBadge(String collection) {
    Color color;
    String label;
    IconData icon;

    switch (collection) {
      case 'prescriptions':
        color = purpleAccent;
        label = "Visit";
        icon = Icons.event_note_rounded;
        break;
      case 'predictions':
        color = greenAccent;
        label = "Scan";
        icon = Icons.biotech_rounded;
        break;
      case 'lab_reports':
        color = orangeAccent;
        label = "Lab";
        icon = Icons.science_rounded;
        break;
      default:
        color = Colors.grey;
        label = "Record";
        icon = Icons.description_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String type) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open_rounded, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            "No $type found",
            style: TextStyle(fontSize: 16, color: Colors.grey.shade400, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
