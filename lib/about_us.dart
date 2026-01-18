import 'package:flutter/material.dart';
import 'landing_page.dart';

class AboutUsPage extends StatelessWidget {
  const AboutUsPage({super.key});

  // 🔹 LIGHT MEDICAL THEME (Related to Landing Page Drawer)
  final Color bgColor = const Color(0xFFF0FDFA); // Clean Mint White
  final Color cardColor = Colors.white;
  final Color primaryText = const Color(0xFF1F2937); // Dark Slate
  final Color secondaryText = const Color(0xFF4B5563); // Muted Grey
  final Color accentColor = const Color(0xFF0D9488); // Deep Teal
  final Color softAccent = const Color(0xFF4FD1C5); // Bright Teal (from Landing)

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        backgroundColor: softAccent,
        title: const Text(
          'About Dermascan',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      
      /// 🔹 DRAWER (Identical to Landing Page for consistency)
      drawer: _buildLightDrawer(context),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            /// 1. TOP ILLUSTRATION/ICON SECTION
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: softAccent.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.biotech_rounded, size: 80, color: accentColor),
            ),
            const SizedBox(height: 20),
            Text(
              "Intelligence in Skin Care",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: primaryText,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 30),

            /// 2. INFO CARDS
            _buildLightCard(
              title: "Who We Are",
              content:
                  "Dermascan is an AI-based skin disease pre-screening system developed to assist in the early identification of common dermatological conditions. The system aims to reduce consultation time and support dermatologists by providing preliminary analysis using artificial intelligence.",
            ),

            _buildLightCard(
              title: "Our Vision",
              content:
                  "Our vision is to make skin healthcare more accessible, efficient, and technology-driven by integrating AI-powered diagnostics into clinical workflows while maintaining accuracy and reliability.",
            ),

            _buildLightCard(
              title: "Core Capabilities",
              child: Column(
                children: [
                  _featureRow(Icons.auto_awesome, "AI Analysis", "State-of-the-art image recognition."),
                  _featureRow(Icons.speed, "Fast Results", "Instant pre-screening reports."),
                  _featureRow(Icons.security, "Data Privacy", "Encrypted patient data handling."),
                  _featureRow(Icons.group, "Expert Review", "Built to assist clinical specialists."),
                ],
              ),
            ),

            const SizedBox(height: 20),
            Text(
              "v1.0.0 • Dermascan AI",
              style: TextStyle(color: secondaryText.withOpacity(0.5), fontSize: 12),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  /// 🔹 CLEAN LIGHT CARD
  Widget _buildLightCard({required String title, String? content, Widget? child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 12),
          if (content != null)
            Text(
              content,
              style: TextStyle(fontSize: 15, color: secondaryText, height: 1.6),
            ),
          if (child != null) child,
        ],
      ),
    );
  }

  /// 🔹 FEATURE ROW HELPER
  Widget _featureRow(IconData icon, String label, String desc) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: softAccent, size: 24),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: primaryText)),
                Text(desc, style: TextStyle(fontSize: 13, color: secondaryText)),
              ],
            ),
          )
        ],
      ),
    );
  }

  /// 🔹 LIGHT THEME DRAWER (Matches Landing Page)
  Widget _buildLightDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: bgColor,
      child: Column(
        children: [
          DrawerHeader(
            margin: EdgeInsets.zero,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [softAccent, softAccent.withOpacity(0.8)]),
            ),
            child: const Center(
              child: Text(
                "Dermascan",
                style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          ListTile(
            leading: Icon(Icons.home_rounded, color: accentColor),
            title: Text("Home", style: TextStyle(color: primaryText, fontWeight: FontWeight.bold)),
            onTap: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LandingPage()),
                (route) => false,
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.info_outline_rounded, color: accentColor),
            title: Text("About Us", style: TextStyle(color: accentColor, fontWeight: FontWeight.bold)),
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}