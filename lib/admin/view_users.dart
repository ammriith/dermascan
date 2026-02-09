import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';


class ViewUsersPage extends StatefulWidget {
  const ViewUsersPage({super.key});

  @override
  State<ViewUsersPage> createState() => _ViewUsersPageState();
}

class _ViewUsersPageState extends State<ViewUsersPage> with SingleTickerProviderStateMixin {
  static const Color primaryColor = Color(0xFF4FD1C5);
  static const Color primaryDark = Color(0xFF38B2AC);
  static const Color bgColor = Color(0xFFF8FAFC);
  static const Color cardColor = Colors.white;
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);
  
  static const Color purpleAccent = Color(0xFF8B5CF6);
  static const Color blueAccent = Color(0xFF3B82F6);
  static const Color greenAccent = Color(0xFF10B981);
  static const Color orangeAccent = Color(0xFFF59E0B);
  static const Color pinkAccent = Color(0xFFEC4899);

  late TabController _tabController;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
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
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildUsersList('all'),
                  _buildUsersList('patient'),
                  _buildUsersList('doctor'),
                  _buildUsersList('admin'),
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
            color: Colors.black.withOpacity(0.04),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "All Users",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textPrimary),
                ),
                Text(
                  "View all registered users in the system",
                  style: TextStyle(fontSize: 12, color: textSecondary),
                ),
              ],
            ),
          ),
          _buildUserCount(),
        ],
      ),
    );
  }

  Widget _buildUserCount() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.people_rounded, color: primaryColor, size: 16),
              const SizedBox(width: 6),
              Text(
                "$count",
                style: const TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
          decoration: InputDecoration(
            hintText: "Search users by name or email...",
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade400),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.close_rounded, color: Colors.grey.shade400),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: primaryColor,
          borderRadius: BorderRadius.circular(12),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: textSecondary,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        padding: const EdgeInsets.all(4),
        tabs: const [
          Tab(text: "All"),
          Tab(text: "Patients"),
          Tab(text: "Doctors"),
          Tab(text: "Admin"),
        ],
      ),
    );
  }

  Widget _buildUsersList(String roleFilter) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
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
                Icon(Icons.error_outline_rounded, size: 48, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text("Error: ${snapshot.error}", style: const TextStyle(color: textSecondary)),
              ],
            ),
          );
        }

        var users = snapshot.data?.docs ?? [];

        // Filter by role
        if (roleFilter != 'all') {
          users = users.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final role = (data['userRole'] ?? data['role'] ?? '').toString().toLowerCase();
            return role == roleFilter;
          }).toList();
        }

        // Filter by search query
        if (_searchQuery.isNotEmpty) {
          users = users.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final name = (data['name'] ?? '').toString().toLowerCase();
            final email = (data['email'] ?? '').toString().toLowerCase();
            return name.contains(_searchQuery) || email.contains(_searchQuery);
          }).toList();
        }

        if (users.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_off_rounded, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(
                  roleFilter == 'all' ? "No users found" : "No ${roleFilter}s found",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  _searchQuery.isNotEmpty ? "Try a different search term" : "Users will appear here",
                  style: const TextStyle(color: textSecondary),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {},
          color: primaryColor,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            itemCount: users.length,
            itemBuilder: (ctx, index) => _buildUserCard(users[index]),
          ),
        );
      },
    );
  }

  Widget _buildUserCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final name = data['name'] ?? 'Unknown';
    final email = data['email'] ?? 'No email';
    final role = (data['userRole'] ?? data['role'] ?? 'user').toString();
    final phone = data['phone'] ?? '';
    final createdAt = data['createdAt'] as Timestamp?;
    final userId = doc.id;
    
    String dateStr = 'N/A';
    if (createdAt != null) {
      final dt = createdAt.toDate();
      dateStr = '${dt.day}/${dt.month}/${dt.year}';
    }

    Color roleColor;
    IconData roleIcon;
    switch (role.toLowerCase()) {
      case 'doctor':
        roleColor = blueAccent;
        roleIcon = Icons.medical_services_rounded;
        break;
      case 'admin':
      case 'staff':
        roleColor = purpleAccent;
        roleIcon = Icons.admin_panel_settings_rounded;
        break;
      case 'patient':
      default:
        roleColor = greenAccent;
        roleIcon = Icons.person_rounded;
    }

    // Check if this is the current user
    final isCurrentUser = FirebaseAuth.instance.currentUser?.uid == userId;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [roleColor.withOpacity(0.2), roleColor.withOpacity(0.1)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(color: roleColor, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: roleColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(roleIcon, size: 12, color: roleColor),
                                const SizedBox(width: 4),
                                Text(
                                  role.toUpperCase(),
                                  style: TextStyle(fontSize: 9, color: roleColor, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.email_rounded, size: 14, color: textSecondary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              email,
                              style: const TextStyle(fontSize: 12, color: textSecondary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (phone.isNotEmpty) ...[
                            Icon(Icons.phone_rounded, size: 14, color: textSecondary),
                            const SizedBox(width: 6),
                            Text(
                              phone,
                              style: const TextStyle(fontSize: 12, color: textSecondary),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Icon(Icons.calendar_today_rounded, size: 12, color: textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            "Joined: $dateStr",
                            style: TextStyle(fontSize: 11, color: textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Delete button row
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isCurrentUser)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_rounded, size: 14, color: textSecondary),
                        SizedBox(width: 4),
                        Text("Current User", style: TextStyle(fontSize: 11, color: textSecondary)),
                      ],
                    ),
                  )
                else
                  TextButton.icon(
                    onPressed: () => _showDeleteDialog(userId, name, role),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                    label: const Text("Remove", style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600, fontSize: 13)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      backgroundColor: Colors.red.withOpacity(0.05),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(String userId, String userName, String role) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text("Remove User", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Are you sure you want to remove \"$userName\"?",
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withOpacity(0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: Colors.red, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "This will remove ALL user data (profile, appointments, records). Due to security, their login account will remain in Firebase Auth, but they will be blocked from logging back into this app.",
                      style: TextStyle(fontSize: 12, color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancel", style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _deleteUser(userId, role);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Remove", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteUser(String userId, String role) async {
    final firestore = FirebaseFirestore.instance;
    
    try {
      // Delete from users collection
      await firestore.collection('users').doc(userId).delete();
      
      // Delete from role-specific collection
      if (role.toLowerCase() == 'patient') {
        await firestore.collection('patients').doc(userId).delete();
      } else if (role.toLowerCase() == 'doctor') {
        await firestore.collection('doctors').doc(userId).delete();
      }
      
      // Delete related appointments
      final appointments = await firestore
          .collection('appointments')
          .where('patientId', isEqualTo: userId)
          .get();
      for (var doc in appointments.docs) {
        await doc.reference.delete();
      }
      
      // Delete prescriptions
      final prescriptions = await firestore
          .collection('prescriptions')
          .where('patient_id', isEqualTo: userId)
          .get();
      for (var doc in prescriptions.docs) {
        await doc.reference.delete();
      }

      // Delete predictions (AI Scans)
      final predictions = await firestore
          .collection('predictions')
          .where('patient_id', isEqualTo: userId)
          .get();
      for (var doc in predictions.docs) {
        await doc.reference.delete();
      }
      
      // Also check for doctor's records if role is doctor
      if (role.toLowerCase() == 'doctor') {
        final doctorAppointments = await firestore
            .collection('appointments')
            .where('doctorId', isEqualTo: userId)
            .get();
        for (var doc in doctorAppointments.docs) {
          await doc.reference.delete();
        }
        
        final doctorPrescriptions = await firestore
            .collection('prescriptions')
            .where('doctor_id', isEqualTo: userId)
            .get();
        for (var doc in doctorPrescriptions.docs) {
          await doc.reference.delete();
        }
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('User removed successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing user: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

