import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ViewPatientsPage extends StatefulWidget {
  const ViewPatientsPage({super.key});

  @override
  State<ViewPatientsPage> createState() => _ViewPatientsPageState();
}

class _ViewPatientsPageState extends State<ViewPatientsPage> {
  static const Color accentColor = Color(0xFF4FD1C5);
  static const Color bgColor = Color(0xFFF8FAFC);
  static const Color cardColor = Colors.white;
  static const Color textColor = Color(0xFF1F2937);
  
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

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
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: textColor),
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              "Patient Records",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
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
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('patients')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: accentColor));
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

        final patientsDocs = snapshot.data?.docs ?? [];
        
        // Convert to a list we can manipulate and sort client-side
        var patients = patientsDocs.toList();

        // Client-side sort by createdAt (descending)
        patients.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTime = (aData['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
          final bTime = (bData['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
          return bTime.compareTo(aTime);
        });
        
        // Apply search filter
        if (_searchQuery.isNotEmpty) {
          patients = patients.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final name = (data['name'] ?? '').toString().toLowerCase();
            final email = (data['email'] ?? '').toString().toLowerCase();
            final phone = (data['phone'] ?? '').toString().toLowerCase();
            return name.contains(_searchQuery) || 
                   email.contains(_searchQuery) || 
                   phone.contains(_searchQuery);
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
            // Stats Bar
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
            // Patient List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                itemCount: patients.length,
                itemBuilder: (context, index) {
                  final doc = patients[index];
                  final data = doc.data() as Map<String, dynamic>;
                  return _buildPatientCard(data, doc.id);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPatientCard(Map<String, dynamic> data, String patientId) {
    final name = data['name'] ?? 'Unknown';
    final email = data['email'] ?? 'N/A';
    final phone = data['phone'] ?? 'N/A';
    final gender = data['gender'] ?? 'N/A';

    return GestureDetector(
      onTap: () => _openPatientDetails(patientId, data),
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
            // Avatar
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_getGenderColor(gender), _getGenderColor(gender).withValues(alpha: 0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                _getGenderIcon(gender),
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.email_outlined, size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          email,
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Arrow
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: accentColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _openPatientDetails(String patientId, Map<String, dynamic> data) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PatientDetailsPage(patientId: patientId, patientData: data),
      ),
    );
  }

  Color _getGenderColor(String gender) {
    switch (gender.toLowerCase()) {
      case 'male':
        return const Color(0xFF3B82F6);
      case 'female':
        return const Color(0xFFEC4899);
      default:
        return accentColor;
    }
  }

  IconData _getGenderIcon(String gender) {
    switch (gender.toLowerCase()) {
      case 'male':
        return Icons.male_rounded;
      case 'female':
        return Icons.female_rounded;
      default:
        return Icons.person_rounded;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PATIENT DETAILS PAGE
// ═══════════════════════════════════════════════════════════════════════════

class PatientDetailsPage extends StatelessWidget {
  final String patientId;
  final Map<String, dynamic> patientData;
  
  const PatientDetailsPage({
    super.key, 
    required this.patientId, 
    required this.patientData,
  });

  static const Color accentColor = Color(0xFF4FD1C5);
  static const Color bgColor = Color(0xFFF8FAFC);
  static const Color cardColor = Colors.white;
  static const Color textColor = Color(0xFF1F2937);

  @override
  Widget build(BuildContext context) {
    final name = patientData['name'] ?? 'Unknown';
    final email = patientData['email'] ?? 'N/A';
    final phone = patientData['phone'] ?? 'N/A';
    final gender = patientData['gender'] ?? 'N/A';
    final dob = patientData['dateOfBirth'] ?? 'N/A';
    final createdAt = (patientData['createdAt'] as Timestamp?)?.toDate();
    final regDate = createdAt != null 
        ? "${createdAt.day}/${createdAt.month}/${createdAt.year}" 
        : "N/A";

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(context, name),
            
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Card
                    _buildProfileCard(name, email, phone, gender, dob, regDate),
                    
                    const SizedBox(height: 24),
                    
                    // Quick Actions
                    const Text(
                      "Medical Records",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    _buildRecordTile(
                      context,
                      "Prescriptions",
                      "View all prescriptions",
                      Icons.medication_rounded,
                      const Color(0xFF8B5CF6),
                      () => _showRecords(context, "Prescriptions"),
                    ),
                    const SizedBox(height: 12),
                    _buildRecordTile(
                      context,
                      "AI Scan Reports",
                      "View skin analysis results",
                      Icons.biotech_rounded,
                      const Color(0xFF10B981),
                      () => _showRecords(context, "AI Scans"),
                    ),
                    const SizedBox(height: 12),
                    _buildRecordTile(
                      context,
                      "Appointment History",
                      "Past visits and consultations",
                      Icons.history_rounded,
                      const Color(0xFFF59E0B),
                      () => _showRecords(context, "Appointments"),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildHeader(BuildContext context, String name) {
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
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: textColor),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildProfileCard(String name, String email, String phone, String gender, String dob, String regDate) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accentColor, accentColor.withValues(alpha: 0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.person_rounded, color: Colors.white, size: 40),
          ),
          const SizedBox(height: 16),
          Text(
            name,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            email,
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),
          
          // Info Grid
          Row(
            children: [
              Expanded(child: _buildInfoItem("Phone", phone)),
              Expanded(child: _buildInfoItem("Gender", gender)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildInfoItem("DOB", dob)),
              Expanded(child: _buildInfoItem("Registered", regDate)),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoItem(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildRecordTile(BuildContext context, String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
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
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
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
  
  void _showRecords(BuildContext context, String type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PatientRecordsPage(
          patientId: patientId,
          patientName: patientData['name'] ?? 'Patient',
          recordType: type,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PATIENT RECORDS PAGE (Prescriptions, AI Scans, Appointments)
// ═══════════════════════════════════════════════════════════════════════════

class PatientRecordsPage extends StatelessWidget {
  final String patientId;
  final String patientName;
  final String recordType;
  
  const PatientRecordsPage({
    super.key,
    required this.patientId,
    required this.patientName,
    required this.recordType,
  });

  static const Color accentColor = Color(0xFF4FD1C5);
  static const Color bgColor = Color(0xFFF8FAFC);
  static const Color cardColor = Colors.white;
  static const Color textColor = Color(0xFF1F2937);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(child: _buildRecordsList()),
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
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: textColor),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recordType,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                Text(
                  patientName,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildRecordsList() {
    String collection;
    String dateField;
    
    switch (recordType) {
      case 'Prescriptions':
        collection = 'prescriptions';
        dateField = 'createdAt';
        break;
      case 'AI Scans':
        collection = 'predictions';
        dateField = 'createdAt';
        break;
      case 'Appointments':
        collection = 'appointments';
        dateField = 'appodate';
        break;
      default:
        return const Center(child: Text("Unknown record type"));
    }
    
    // Filter based on collection-specific field names:
    // - 'predictions' uses 'patientId'
    // - 'appointments' uses 'patientId'
    // - 'prescriptions' uses 'patient_id'
    final idField = recordType == 'Prescriptions' ? 'patient_id' : 'patientId';

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(collection)
          .where(idField, isEqualTo: patientId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: accentColor));
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text("Error loading records", style: TextStyle(color: Colors.grey.shade600)),
                Text("${snapshot.error}", style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
              ],
            ),
          );
        }
        
        final recordsDocs = snapshot.data?.docs ?? [];
        var records = recordsDocs.toList();

        // Client-side sort by date
        records.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aDate = (aData['createdAt'] as Timestamp?)?.toDate() ?? 
                       (aData['appodate'] as Timestamp?)?.toDate() ?? 
                       DateTime(2000);
          final bDate = (bData['createdAt'] as Timestamp?)?.toDate() ?? 
                       (bData['appodate'] as Timestamp?)?.toDate() ?? 
                       DateTime(2000);
          return bDate.compareTo(aDate);
        });
        
        if (records.isEmpty) {
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
                  "No $recordType found",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 4),
                Text(
                  "Records will appear here once created",
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              ],
            ),
          );
        }
        
        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: records.length,
          itemBuilder: (context, index) {
            final data = records[index].data() as Map<String, dynamic>;
            return _buildRecordCard(context, data);
          },
        );
      },
    );
  }
  
  Widget _buildRecordCard(BuildContext context, Map<String, dynamic> data) {
    final date = (data['createdAt'] as Timestamp?)?.toDate() ?? 
                 (data['appodate'] as Timestamp?)?.toDate();
    final dateStr = date != null 
        ? "${date.day}/${date.month}/${date.year}" 
        : "N/A";
    
    String title;
    String subtitle;
    IconData icon;
    Color color;
    
    switch (recordType) {
      case 'Prescriptions':
        title = data['diagnosis'] ?? 'Prescription';
        subtitle = data['doctor_name'] ?? 'Doctor';
        icon = Icons.medication_rounded;
        color = const Color(0xFF8B5CF6);
        break;
      case 'AI Scans':
        title = data['prediction'] ?? 'Scan Result';
        subtitle = "Confidence: ${((data['confidence'] ?? 0) * 100).toStringAsFixed(1)}%";
        icon = Icons.biotech_rounded;
        color = const Color(0xFF10B981);
        break;
      case 'Appointments':
        title = "Dr. ${data['doctor_name'] ?? 'Unknown'}";
        subtitle = data['status'] ?? 'Booked';
        icon = Icons.event_rounded;
        color = const Color(0xFFF59E0B);
        break;
      default:
        title = 'Record';
        subtitle = '';
        icon = Icons.description_rounded;
        color = accentColor;
    }
    
    return GestureDetector(
      onTap: () => _showRecordDetails(context, data),
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
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  dateStr,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor),
                ),
                if (recordType == 'AI Scans')
                  const Icon(Icons.remove_red_eye_outlined, size: 14, color: accentColor),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showRecordDetails(BuildContext context, Map<String, dynamic> data) {
    if (recordType != 'AI Scans') return;

    final imgUrl = data['imageUrl'] ?? data['image_url'];
    final createdAt = data['createdAt'] as Timestamp?;
    final condition = data['prediction'] ?? data['condition'] ?? 'Unknown';
    final confidence = ((data['confidence'] ?? 0) as num) * 100;
    final severity = data['severity'] ?? 'N/A';
    
    // 'recommendations' is stored as a List<String>
    final rawRecs = data['recommendations'];
    String recommendationsText;
    if (rawRecs is List && rawRecs.isNotEmpty) {
      recommendationsText = rawRecs.map((r) => '• $r').join('\n');
    } else if (rawRecs is String && rawRecs.isNotEmpty) {
      recommendationsText = rawRecs;
    } else {
      recommendationsText = "Consult with a dermatologist for a professional diagnosis and treatment plan.";
    }

    // Severity color
    Color severityColor;
    final sevLower = severity.toString().toLowerCase();
    if (sevLower.contains('severe') || sevLower.contains('high') || sevLower.contains('critical')) {
      severityColor = Colors.red;
    } else if (sevLower.contains('moderate') || sevLower.contains('medium')) {
      severityColor = Colors.orange;
    } else {
      severityColor = const Color(0xFF10B981);
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Image Section — only show if we have a URL
              if (imgUrl != null)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  child: Image.network(
                    imgUrl,
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      child: const Icon(Icons.broken_image_outlined, size: 48, color: Colors.grey),
                    ),
                  ),
                )
              else
                // Nice colored header banner instead of grey placeholder
                Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: const Icon(Icons.biotech_rounded, size: 56, color: Color(0xFF10B981)),
                ),
              
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "AI Analysis Result",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
                    ),
                    const SizedBox(height: 20),
                    _buildDetailRow("Detected Condition", condition),
                    _buildDetailRow("Confidence Level", "${confidence.toStringAsFixed(1)}%"),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(
                          width: 130,
                          child: Text("Severity", style: TextStyle(fontSize: 13, color: Colors.grey)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: severityColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            severity,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: severityColor),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (createdAt != null) ...[
                      _buildDetailRow("Analysis Date", DateFormat('MMM dd, yyyy • hh:mm a').format(createdAt.toDate())),
                    ],
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 12),
                    const Text(
                      "Recommendations",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      recommendationsText,
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.7),
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text("Close", style: TextStyle(fontWeight: FontWeight.bold)),
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor),
            ),
          ),
        ],
      ),
    );
  }
}
