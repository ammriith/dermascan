import 'package:dermascan/selection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'about_us.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  final Color textColor = const Color(0xFFF5F7FA);
  final Color subTextColor = const Color(0xFFC9D6DF);
  final Color accentColor = const Color(0xFF4FD1C5);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      drawer: _buildLightDrawer(context),
      body: Stack(
        children: [
          /// 1. BACKGROUND IMAGE
          Positioned.fill(
            child: Image.asset(
  'assets/image1.jpg', 
  fit: BoxFit.cover,
  errorBuilder: (context, error, stackTrace) => Container(color: Colors.black),
),
          ),

          /// 2. DARK GRADIENT OVERLAY
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.1),
                    Colors.black.withOpacity(0.85),
                  ],
                ),
              ),
            ),
          ),

          /// 3. MAIN CONTENT
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 60),
                  Text(
                    "Dermascan",
                    style: TextStyle(
                      color: textColor,
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "AI-powered skin health analysis\nin the palm of your hand",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: subTextColor, fontSize: 16, height: 1.4),
                  ),
                  const Spacer(),

                  /// 🔹 GET STARTED BUTTON (Glass removed)
                  InkWell(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AuthSelectionPage()),
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      height: 58,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withOpacity(0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          )
                        ],
                      ),
                      child: const Text(
                        "Get Started",
                        style: TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLightDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFFF0FDFA),
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: accentColor),
            child: const Center(
              child: Text("Dermascan", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home_rounded, color: Color(0xFF0D9488)),
            title: const Text("Home"),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded, color: Color(0xFF0D9488)),
            title: const Text("About Us"),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutUsPage()));
            },
          ),
        ],
      ),
    );
  }
}