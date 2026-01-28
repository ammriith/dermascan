import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PatientReportsPage extends StatefulWidget {
  const PatientReportsPage({super.key});

  @override
  State<PatientReportsPage> createState() => _PatientReportsPageState();
}

class _PatientReportsPageState extends State<PatientReportsPage> {
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

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void dispose() {
    _searchController.dispose();
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
            _buildSearchBar(),
            Expanded(child: _buildPatientsList()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
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
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Patient Reports",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                Text(
                  "View & send reports to clinic staff",
                  style: TextStyle(fontSize: 12, color: textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
        decoration: InputDecoration(
          hintText: "Search patients...",
          hintStyle: TextStyle(color: Colors.grey.shade400),
          border: InputBorder.none,
          icon: Icon(Icons.search_rounded, color: Colors.grey.shade400),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildPatientsList() {
    final doctorId = _auth.currentUser?.uid;
    if (doctorId == null) {
      return const Center(child: Text("Not authenticated"));
    }
    
    // Get all appointments and filter for this doctor on client side
    // to support both doctorId and doctor_id field naming conventions
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .orderBy('appodate', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: primaryColor));
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 50, color: Colors.red.shade300),
                const SizedBox(height: 10),
                Text("Error loading patients", style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
          );
        }

        // Filter for this doctor's appointments (support both doctorId and doctor_id)
        final allDocs = snapshot.data?.docs ?? [];
        final appointments = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final docId = data['doctorId'] ?? data['doctor_id'];
          return docId == doctorId;
        }).toList();
        
        // Extract unique patients (support both patientId and patient_id)
        final Map<String, Map<String, dynamic>> uniquePatients = {};
        for (var doc in appointments) {
          final data = doc.data() as Map<String, dynamic>;
          final patientId = (data['patientId'] ?? data['patient_id']) as String?;
          final patientName = (data['patientName'] ?? data['patient_name']) as String?;
          
          if (patientId != null && !uniquePatients.containsKey(patientId)) {
            uniquePatients[patientId] = {
              'patientId': patientId,
              'patientName': patientName ?? 'Unknown Patient',
              'lastVisit': data['appodate'],
            };
          }
        }
        
        var patients = uniquePatients.values.toList();
        
        // Apply search filter
        if (_searchQuery.isNotEmpty) {
          patients = patients.where((p) {
            final name = (p['patientName'] ?? '').toString().toLowerCase();
            return name.contains(_searchQuery);
          }).toList();
        }

        if (patients.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.person_off_outlined, size: 48, color: Colors.grey.shade400),
                ),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isEmpty ? "No patients found" : "No results for \"$_searchQuery\"",
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    "${patients.length} patients",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                itemCount: patients.length,
                itemBuilder: (context, index) {
                  final patient = patients[index];
                  return _buildPatientCard(patient);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPatientCard(Map<String, dynamic> patient) {
    final name = patient['patientName'] ?? 'Unknown';
    final patientId = patient['patientId'];
    final lastVisit = patient['lastVisit'];
    String lastVisitStr = 'N/A';
    
    if (lastVisit != null && lastVisit is Timestamp) {
      final dt = lastVisit.toDate();
      lastVisitStr = '${dt.day}/${dt.month}/${dt.year}';
    }

    return GestureDetector(
      onTap: () => _openPatientReports(patientId, name),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [primaryColor, primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'P',
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 6),
                      Text(
                        "Last visit: $lastVisitStr",
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.description_rounded,
                size: 20,
                color: primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openPatientReports(String patientId, String patientName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PatientReportDetailsPage(
          patientId: patientId,
          patientName: patientName,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PATIENT REPORT DETAILS PAGE
// ═══════════════════════════════════════════════════════════════════════════

class PatientReportDetailsPage extends StatefulWidget {
  final String patientId;
  final String patientName;

  const PatientReportDetailsPage({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  @override
  State<PatientReportDetailsPage> createState() => _PatientReportDetailsPageState();
}

class _PatientReportDetailsPageState extends State<PatientReportDetailsPage> {
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

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPatientInfo(),
                    const SizedBox(height: 24),
                    _buildReportTypesSection(),
                    const SizedBox(height: 24),
                    _buildCreateReportButton(),
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
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
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
                Text(
                  widget.patientName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const Text(
                  "Patient Reports",
                  style: TextStyle(fontSize: 12, color: textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientInfo() {
    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('patients').doc(widget.patientId).get(),
      builder: (context, snapshot) {
        String email = 'N/A';
        String phone = 'N/A';
        String gender = 'N/A';
        
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          email = data['email'] ?? 'N/A';
          phone = data['phone'] ?? 'N/A';
          gender = data['gender'] ?? 'N/A';
        }
        
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [primaryColor, primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    widget.patientName.isNotEmpty ? widget.patientName[0].toUpperCase() : 'P',
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.patientName,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      phone,
                      style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.9)),
                    ),
                    Text(
                      email,
                      style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReportTypesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Reports",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
        ),
        const SizedBox(height: 16),
        _buildReportTypeTile(
          "Consultation Notes",
          "Doctor's notes & diagnosis",
          Icons.note_alt_rounded,
          purpleAccent,
          'consultation_notes',
        ),
        const SizedBox(height: 12),
        _buildReportTypeTile(
          "Prescriptions",
          "Medications & treatments",
          Icons.medication_rounded,
          blueAccent,
          'prescriptions',
        ),
        const SizedBox(height: 12),
        _buildReportTypeTile(
          "AI Scan Results",
          "Skin analysis results",
          Icons.biotech_rounded,
          greenAccent,
          'predictions',
        ),
        const SizedBox(height: 12),
        _buildReportTypeTile(
          "Lab Reports",
          "Test results & findings",
          Icons.science_rounded,
          orangeAccent,
          'lab_reports',
        ),
      ],
    );
  }

  Widget _buildReportTypeTile(String title, String subtitle, IconData icon, Color color, String collection) {
    return GestureDetector(
      onTap: () => _viewReports(title, collection),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateReportButton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Actions",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => _showCreateReportDialog(),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor.withValues(alpha: 0.1), primaryDark.withValues(alpha: 0.1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_rounded, color: primaryColor, size: 24),
                SizedBox(width: 10),
                Text(
                  "Create New Report",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryColor),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _viewReports(String title, String collection) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ViewPatientReportsPage(
          patientId: widget.patientId,
          patientName: widget.patientName,
          reportType: title,
          collection: collection,
        ),
      ),
    );
  }

  void _showCreateReportDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CreateReportSheet(
        patientId: widget.patientId,
        patientName: widget.patientName,
        doctorId: _auth.currentUser?.uid ?? '',
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// VIEW PATIENT REPORTS PAGE
// ═══════════════════════════════════════════════════════════════════════════

class ViewPatientReportsPage extends StatelessWidget {
  final String patientId;
  final String patientName;
  final String reportType;
  final String collection;

  const ViewPatientReportsPage({
    super.key,
    required this.patientId,
    required this.patientName,
    required this.reportType,
    required this.collection,
  });

  static const Color primaryColor = Color(0xFF4FD1C5);
  static const Color bgColor = Color(0xFFF8FAFC);
  static const Color cardColor = Colors.white;
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color greenAccent = Color(0xFF10B981);
  static const Color orangeAccent = Color(0xFFF59E0B);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(child: _buildReportsList(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
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
                Text(
                  reportType,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textPrimary),
                ),
                Text(
                  patientName,
                  style: const TextStyle(fontSize: 12, color: textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportsList(BuildContext context) {
    String patientField = collection == 'predictions' ? 'userId' : 'patientId';
    
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(collection)
          .where(patientField, isEqualTo: patientId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: primaryColor));
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text("Error loading reports", style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
          );
        }

        final reports = snapshot.data?.docs ?? [];

        if (reports.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.folder_open_rounded, size: 48, color: Colors.grey.shade400),
                ),
                const SizedBox(height: 16),
                Text(
                  "No $reportType found",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: reports.length,
          itemBuilder: (context, index) {
            final doc = reports[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildReportCard(context, data, doc.id);
          },
        );
      },
    );
  }

  Widget _buildReportCard(BuildContext context, Map<String, dynamic> data, String reportId) {
    final createdAt = data['createdAt'] as Timestamp?;
    String dateStr = 'N/A';
    if (createdAt != null) {
      final dt = createdAt.toDate();
      dateStr = '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    }
    
    final sentToStaff = data['sentToStaff'] ?? false;
    String title = data['title'] ?? data['diagnosis'] ?? data['prediction'] ?? 'Report';
    String description = data['notes'] ?? data['description'] ?? data['medications'] ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (sentToStaff)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: greenAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, size: 14, color: greenAccent),
                      SizedBox(width: 4),
                      Text("Sent", style: TextStyle(fontSize: 11, color: greenAccent, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.access_time_rounded, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Text(dateStr, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                ],
              ),
              
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Give Suggestion Button
                  GestureDetector(
                    onTap: () => _showSuggestionDialog(context, data),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: orangeAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: orangeAccent.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lightbulb_rounded, size: 14, color: orangeAccent),
                          SizedBox(width: 4),
                          Text("Suggest", style: TextStyle(fontSize: 11, color: orangeAccent, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),

                  if (!sentToStaff) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _sendToStaff(context, reportId),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: primaryColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.send_rounded, size: 14, color: Colors.white),
                            SizedBox(width: 4),
                            Text("To Staff", style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSuggestionDialog(BuildContext context, Map<String, dynamic> reportData) {
    final TextEditingController suggestionController = TextEditingController();
    final TextEditingController medsController = TextEditingController();
    final reportTitle = reportData['title'] ?? reportData['diagnosis'] ?? 'Report';
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            top: 24,
            left: 24,
            right: 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: orangeAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.lightbulb_rounded, color: orangeAccent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Give Suggestion",
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          "Based on: $reportTitle",
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text("Doctor's Suggestion", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: suggestionController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: "Enter your advice or suggestions for the patient...",
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text("Recommended Medications (Optional)", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: medsController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: "e.g. Paracetamol 500mg daily...",
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: isSaving ? null : () async {
                    if (suggestionController.text.isEmpty && medsController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Please enter a suggestion or medication")),
                      );
                      return;
                    }

                    setState(() => isSaving = true);
                    try {
                      final docId = FirebaseAuth.instance.currentUser?.uid;
                      final docSnap = await FirebaseFirestore.instance.collection('doctors').doc(docId).get();
                      final doctorName = docSnap.exists ? (docSnap.data()?['name'] ?? 'Doctor') : 'Doctor';

                      await FirebaseFirestore.instance.collection('doctor_suggestions').add({
                        'patientId': patientId,
                        'patientName': patientName,
                        'doctorId': docId,
                        'doctorName': doctorName,
                        'reportTitle': reportTitle,
                        'suggestion': suggestionController.text.trim(),
                        'medication': medsController.text.trim(),
                        'createdAt': FieldValue.serverTimestamp(),
                      });

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Suggestion sent to patient!"),
                            backgroundColor: greenAccent,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
                        );
                      }
                    } finally {
                      setState(() => isSaving = false);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: orangeAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Send to Patient", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _sendToStaff(BuildContext context, String reportId) async {
    try {
      // Update the report to mark as sent
      await FirebaseFirestore.instance.collection(collection).doc(reportId).update({
        'sentToStaff': true,
        'sentAt': FieldValue.serverTimestamp(),
      });
      
      // Create a notification for clinic staff
      await FirebaseFirestore.instance.collection('staff_notifications').add({
        'type': 'report_shared',
        'reportType': reportType,
        'reportId': reportId,
        'collection': collection,
        'patientId': patientId,
        'patientName': patientName,
        'sentBy': FirebaseAuth.instance.currentUser?.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Report sent to clinic staff'),
            ],
          ),
          backgroundColor: greenAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
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
}

// ═══════════════════════════════════════════════════════════════════════════
// CREATE REPORT SHEET
// ═══════════════════════════════════════════════════════════════════════════

class CreateReportSheet extends StatefulWidget {
  final String patientId;
  final String patientName;
  final String doctorId;

  const CreateReportSheet({
    super.key,
    required this.patientId,
    required this.patientName,
    required this.doctorId,
  });

  @override
  State<CreateReportSheet> createState() => _CreateReportSheetState();
}

class _CreateReportSheetState extends State<CreateReportSheet> {
  static const Color primaryColor = Color(0xFF4FD1C5);
  static const Color textPrimary = Color(0xFF1F2937);
  
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  final _diagnosisController = TextEditingController();
  final _medicationsController = TextEditingController();
  
  String _selectedType = 'consultation_notes';
  bool _sendToStaff = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _diagnosisController.dispose();
    _medicationsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
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
              const SizedBox(height: 20),
              
              // Title
              const Text(
                "Create Report",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textPrimary),
              ),
              Text(
                "For ${widget.patientName}",
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
              
              // Report Type Dropdown
              const Text("Report Type", style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedType,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'consultation_notes', child: Text('Consultation Notes')),
                      DropdownMenuItem(value: 'prescriptions', child: Text('Prescription')),
                      DropdownMenuItem(value: 'lab_reports', child: Text('Lab Report')),
                    ],
                    onChanged: (value) => setState(() => _selectedType = value!),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Title field
              const Text("Title", style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                validator: (v) => v!.isEmpty ? 'Title is required' : null,
                decoration: InputDecoration(
                  hintText: "Report title",
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Diagnosis field
              const Text("Diagnosis", style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _diagnosisController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: "Primary diagnosis",
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Notes field
              const Text("Notes", style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: "Detailed notes...",
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Medications (for prescription)
              if (_selectedType == 'prescriptions') ...[
                const Text("Medications", style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _medicationsController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: "List medications...",
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              // Send to staff checkbox
              Row(
                children: [
                  Checkbox(
                    value: _sendToStaff,
                    onChanged: (v) => setState(() => _sendToStaff = v!),
                    activeColor: primaryColor,
                  ),
                  const Expanded(
                    child: Text(
                      "Send to clinic staff immediately",
                      style: TextStyle(color: textPrimary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Submit button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createReport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Create Report", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createReport() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final reportData = {
        'patientId': widget.patientId,
        'patientName': widget.patientName,
        'doctorId': widget.doctorId,
        'title': _titleController.text.trim(),
        'diagnosis': _diagnosisController.text.trim(),
        'notes': _notesController.text.trim(),
        'medications': _medicationsController.text.trim(),
        'type': _selectedType,
        'sentToStaff': _sendToStaff,
        'createdAt': FieldValue.serverTimestamp(),
      };
      
      final docRef = await FirebaseFirestore.instance.collection(_selectedType).add(reportData);
      
      // If send to staff is enabled, create notification
      if (_sendToStaff) {
        await FirebaseFirestore.instance.collection('staff_notifications').add({
          'type': 'report_shared',
          'reportType': _selectedType,
          'reportId': docRef.id,
          'collection': _selectedType,
          'patientId': widget.patientId,
          'patientName': widget.patientName,
          'title': _titleController.text.trim(),
          'sentBy': widget.doctorId,
          'createdAt': FieldValue.serverTimestamp(),
          'isRead': false,
        });
      }
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text(_sendToStaff ? 'Report created & sent to staff' : 'Report created successfully'),
              ],
            ),
            backgroundColor: Colors.green,
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
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
