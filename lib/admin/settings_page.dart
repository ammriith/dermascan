import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:dermascan/landing_page.dart';
import 'package:dermascan/admin/change_password_page.dart';
import 'package:dermascan/providers/theme_provider.dart';


class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const Color accentColor = Color(0xFF4FD1C5);
  static const Color textColor = Color(0xFF1F2937);
  static const Color bgColor = Colors.white;
  static const Color cardColor = Color(0xFFF3F4F6);

  bool _notificationsEnabled = true;

  void _handleLogout() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Logout", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancel", style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LandingPage()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Logout", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
    );
  }

  void _showClearDatabaseDialog() {
    final confirmController = TextEditingController();
    bool isDeleting = false;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text("Clear All Data", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "⚠️ WARNING: This will permanently delete:",
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
              ),
              const SizedBox(height: 12),
              _buildDeleteItem("All Patients"),
              _buildDeleteItem("All Doctors"),
              _buildDeleteItem("All User Accounts"),
              _buildDeleteItem("All Appointments"),
              const SizedBox(height: 16),
              const Text(
                "Type 'DELETE' to confirm:",
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: confirmController,
                decoration: InputDecoration(
                  hintText: "Type DELETE here",
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (_) => setDialogState(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isDeleting ? null : () => Navigator.pop(ctx),
              child: Text("Cancel", style: TextStyle(color: Colors.grey[600])),
            ),
            ElevatedButton(
              onPressed: confirmController.text == 'DELETE' && !isDeleting
                  ? () async {
                      setDialogState(() => isDeleting = true);
                      await _clearAllData();
                      if (mounted) Navigator.pop(ctx);
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: isDeleting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text("Delete All", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeleteItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.remove_circle, color: Colors.red, size: 16),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Future<void> _clearAllData() async {
    final firestore = FirebaseFirestore.instance;
    
    try {
      // Delete all patients
      final patients = await firestore.collection('patients').get();
      for (var doc in patients.docs) {
        await doc.reference.delete();
      }
      
      // Delete all doctors
      final doctors = await firestore.collection('doctors').get();
      for (var doc in doctors.docs) {
        await doc.reference.delete();
      }
      
      // Delete all users (except current admin)
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      final users = await firestore.collection('users').get();
      for (var doc in users.docs) {
        if (doc.id != currentUserId) {
          await doc.reference.delete();
        }
      }
      
      // Delete all appointments
      final appointments = await firestore.collection('appointments').get();
      for (var doc in appointments.docs) {
        await doc.reference.delete();
      }
      
      // Delete all scan results
      final scans = await firestore.collection('scan_results').get();
      for (var doc in scans.docs) {
        await doc.reference.delete();
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text('All data has been cleared successfully!')),
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
            content: Text('Error clearing data: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false, // No back button
        title: const Text(
          "Settings",
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 100), // Extra bottom padding for nav
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Profile Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: accentColor,
                    child: Icon(Icons.person, color: Colors.white, size: 30),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.displayName ?? "Admin Staff",
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                        ),
                        Text(
                          user?.email ?? "admin@dermascan.com",
                          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: accentColor),
                    onPressed: () {
                      // Logic for editing profile
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            Text(
              "Account Settings",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 16),
            
            // Change Password - Navigate to full page
            _buildSettingTile(
              icon: Icons.lock_outline_rounded,
              title: "Change Password",
              subtitle: "Update your account password",
              onTap: _showChangePasswordPage,
            ),
            _buildSettingTile(
              icon: Icons.notifications_none_rounded,
              title: "Notifications",
              trailing: Switch(
                value: _notificationsEnabled,
                activeColor: accentColor,
                onChanged: (val) => setState(() => _notificationsEnabled = val),
              ),
            ),
            _buildSettingTile(
              icon: Icons.dark_mode_outlined,
              title: "Dark Mode",
              trailing: Consumer<ThemeProvider>(
                builder: (context, themeProvider, _) => Switch(
                  value: themeProvider.isDarkMode,
                  activeColor: accentColor,
                  onChanged: (val) => themeProvider.setDarkMode(val),
                ),
              ),
            ),
            _buildSettingTile(
              icon: Icons.language_rounded,
              title: "Language",
              subtitle: "English (US)",
              onTap: () {},
            ),

            const SizedBox(height: 32),
            Text(
              "Support & Legal",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 16),
            _buildSettingTile(
              icon: Icons.info_outline_rounded,
              title: "About Dermascan",
              onTap: () {},
            ),
            _buildSettingTile(
              icon: Icons.description_outlined,
              title: "Privacy Policy",
              onTap: () {},
            ),
            _buildSettingTile(
              icon: Icons.help_outline_rounded,
              title: "Help & Support",
              onTap: () {},
            ),

            const SizedBox(height: 32),
            Text(
              "Database Management",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red.withOpacity(0.7)),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red.withOpacity(0.2)),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.delete_forever_rounded, color: Colors.red, size: 20),
                ),
                title: const Text("Clear All Data", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red)),
                subtitle: Text("Delete all patients, doctors & appointments", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                trailing: Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
                onTap: _showClearDatabaseDialog,
              ),
            ),

            const SizedBox(height: 32),
            // Logout

            Container(
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                title: const Text(
                  "Logout",
                  style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                ),
                onTap: _handleLogout,
              ),
            ),
            const SizedBox(height: 40),
            Center(
              child: Text(
                "v1.0.0",
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: accentColor, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: textColor)),
        subtitle: subtitle != null ? Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])) : null,
        trailing: trailing ?? Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
        onTap: onTap,
      ),
    );
  }
}
