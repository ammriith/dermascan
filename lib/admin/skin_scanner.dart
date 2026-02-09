import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dermascan/services/ai_service.dart';

class SkinScannerPage extends StatefulWidget {
  final String? patientId;
  final String? patientName;
  final bool openCamera;
  final bool openGallery;
  
  const SkinScannerPage({
    super.key,
    this.patientId,
    this.patientName,
    this.openCamera = false,
    this.openGallery = false,
  });

  @override
  State<SkinScannerPage> createState() => _SkinScannerPageState();
}

class _SkinScannerPageState extends State<SkinScannerPage> with TickerProviderStateMixin {
  // 🎨 Premium Color Palette
  static const Color primaryColor = Color(0xFF4FD1C5);
  static const Color primaryDark = Color(0xFF319795);
  static const Color bgColor = Color(0xFFF7FAFC);
  static const Color cardColor = Colors.white;
  static const Color textPrimary = Color(0xFF1A202C);
  static const Color textSecondary = Color(0xFF718096);
  
  static const Color purpleAccent = Color(0xFF805AD5);
  static const Color blueAccent = Color(0xFF4299E1);
  static const Color greenAccent = Color(0xFF48BB78);
  static const Color orangeAccent = Color(0xFFED8936);
  static const Color redAccent = Color(0xFFFC8181);
  static const Color pinkAccent = Color(0xFFED64A6);

  final ImagePicker _picker = ImagePicker();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AIService _aiService = AIService();

  File? _selectedImage;
  bool _isAnalyzing = false;
  Map<String, dynamic>? _analysisResult;
  String? _selectedPatientId;
  String? _selectedPatientName;
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Check if running on mobile (Android/iOS)
  bool get _isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  void initState() {
    super.initState();
    _selectedPatientId = widget.patientId;
    _selectedPatientName = widget.patientName;
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    // Auto-open camera or gallery if specified
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.openCamera) {
        _openCamera();
      } else if (widget.openGallery) {
        _openGallery();
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _openCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 90,
      );
      
      if (image != null && mounted) {
        setState(() {
          _selectedImage = File(image.path);
          _analysisResult = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Camera error: ${e.toString()}')),
              ],
            ),
            backgroundColor: redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _openGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 90,
      );
      
      if (image != null && mounted) {
        setState(() {
          _selectedImage = File(image.path);
          _analysisResult = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Gallery error: ${e.toString()}')),
              ],
            ),
            backgroundColor: redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }


  Future<void> _analyzeImage() async {
    if (_selectedImage == null) return;
    
    setState(() => _isAnalyzing = true);
    
    try {
      final result = await _aiService.analyzeSkinImage(_selectedImage!);
      
      setState(() {
        _analysisResult = result;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Analysis failed: $e'),
          backgroundColor: redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() => _isAnalyzing = false);
    }
  }

  // Recommendations and Condition logic moved to AIService

  Future<void> _saveResult() async {
    if (_analysisResult == null) return;
    
    if (_selectedPatientId == null) {
      _showPatientSelector();
      return;
    }
    
    try {
      await _firestore.collection('predictions').add({
        'patientId': _selectedPatientId,
        'patientName': _selectedPatientName,
        'prediction': _analysisResult!['condition'],
        'confidence': _analysisResult!['confidence'],
        'severity': _analysisResult!['severity'],
        'recommendations': _analysisResult!['recommendations'],
        'analyzedBy': _auth.currentUser?.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'sentToStaff': false,
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                const Flexible(child: Text('Result saved successfully!')),
              ],
            ),
            backgroundColor: greenAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        
        // Reset for new scan
        setState(() {
          _selectedImage = null;
          _analysisResult = null;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving: $e'), backgroundColor: redAccent),
      );
    }
  }

  void _showPatientSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PatientSelectorSheet(
        onPatientSelected: (id, name) {
          setState(() {
            _selectedPatientId = id;
            _selectedPatientName = name;
          });
          Navigator.pop(ctx);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Selected: $name'),
              backgroundColor: primaryColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
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
              child: _selectedImage == null
                  ? _buildCaptureView()
                  : _buildAnalysisView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
          _buildBackButton(),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Skin Scanner",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textPrimary),
                ),
                Text(
                  _selectedPatientName ?? "Select a patient",
                  style: TextStyle(
                    fontSize: 12,
                    color: _selectedPatientName != null ? primaryDark : orangeAccent,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          _buildPatientButton(),
        ],
      ),
    );
  }

  Widget _buildBackButton() {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: textPrimary),
      ),
    );
  }

  Widget _buildPatientButton() {
    return GestureDetector(
      onTap: _showPatientSelector,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [primaryColor, primaryDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_add_rounded, size: 18, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              _selectedPatientId != null ? "Change" : "Select",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CAPTURE VIEW - Initial screen with camera/gallery options
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildCaptureView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          
          // Hero illustration
          _buildHeroSection(),
          
          const SizedBox(height: 40),
          
          // Capture options
          _buildCaptureOptions(),
          
          const SizedBox(height: 30),
          
          // Info cards
          _buildInfoCards(),
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primaryColor.withValues(alpha: 0.2),
                      primaryDark.withValues(alpha: 0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [primaryColor, primaryDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.document_scanner_rounded, size: 44, color: Colors.white),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        const Text(
          "AI Skin Analysis",
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: textPrimary),
        ),
        const SizedBox(height: 8),
        Text(
          "Capture or upload a skin image for\ninstant AI-powered analysis",
          style: TextStyle(fontSize: 15, color: textSecondary, height: 1.5),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildCaptureOptions() {
    return Row(
      children: [
        // Camera Button
        Expanded(
          child: _buildCaptureButton(
            icon: Icons.camera_alt_rounded,
            label: "Camera",
            subtitle: "Take a photo",
            gradient: [blueAccent, const Color(0xFF3182CE)],
            onTap: _openCamera,
            enabled: true,
          ),
        ),
        const SizedBox(width: 16),
        // Gallery Button
        Expanded(
          child: _buildCaptureButton(
            icon: Icons.photo_library_rounded,
            label: "Gallery",
            subtitle: "Choose photo",
            gradient: [purpleAccent, const Color(0xFF6B46C1)],
            onTap: _openGallery,
            enabled: true,
          ),
        ),
      ],
    );
  }

  Widget _buildCaptureButton({
    required IconData icon,
    required String label,
    required String subtitle,
    required List<Color> gradient,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    final effectiveGradient = enabled ? gradient : [Colors.grey.shade400, Colors.grey.shade500];
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: effectiveGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: effectiveGradient[0].withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: Colors.white),
            ),
            const SizedBox(height: 14),
            Text(
              label,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.85)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCards() {
    return Column(
      children: [
        _buildInfoCard(
          icon: Icons.security_rounded,
          title: "Private & Secure",
          description: "Your images are processed securely and not stored on external servers",
          color: greenAccent,
        ),
        const SizedBox(height: 12),
        _buildInfoCard(
          icon: Icons.speed_rounded,
          title: "Instant Results",
          description: "Get AI-powered analysis in seconds with detailed recommendations",
          color: blueAccent,
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
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
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: textPrimary)),
                const SizedBox(height: 2),
                Text(description, style: TextStyle(fontSize: 12, color: textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ANALYSIS VIEW - After image is selected
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildAnalysisView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image preview
          _buildImagePreview(),
          
          const SizedBox(height: 20),
          
          // Analyze button (if no result yet)
          if (_analysisResult == null && !_isAnalyzing)
            _buildAnalyzeButton(),
          
          // Loading state
          if (_isAnalyzing)
            _buildLoadingState(),
          
          // Results
          if (_analysisResult != null)
            _buildResultsSection(),
          
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: 300,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.file(
              _selectedImage!,
              fit: BoxFit.cover,
            ),
          ),
        ),
        // Close button
        Positioned(
          top: 12,
          right: 12,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedImage = null;
                _analysisResult = null;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
            ),
          ),
        ),
        // Retake button
        Positioned(
          bottom: 12,
          left: 12,
          child: GestureDetector(
            onTap: _openCamera,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 6),
                  Text("Retake", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyzeButton() {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: _analyzeImage,
        icon: const Icon(Icons.biotech_rounded, size: 24),
        label: const Text("Analyze Skin Condition", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 70,
            height: 70,
            child: CircularProgressIndicator(
              strokeWidth: 4,
              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "Analyzing Image...",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            "AI is examining the skin condition",
            style: TextStyle(color: textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsSection() {
    final condition = _analysisResult!['condition'] as String;
    final confidence = (_analysisResult!['confidence'] as double) * 100;
    final severity = _analysisResult!['severity'] as String;
    final description = _analysisResult!['description'] as String? ?? '';
    final recommendations = _analysisResult!['recommendations'] as List<String>;
    final symptoms = _analysisResult!['symptoms'] as List<String>? ?? [];
    
    Color severityColor = severity.toLowerCase().contains('high') || severity.toLowerCase().contains('critical') ? redAccent : 
                          severity.toLowerCase().contains('moderate') ? orangeAccent : greenAccent;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main result card
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                primaryColor.withValues(alpha: 0.08),
                primaryDark.withValues(alpha: 0.04),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, color: primaryDark, size: 40),
              ),
              const SizedBox(height: 16),
              const Text("Detected Condition", style: TextStyle(fontSize: 13, color: textSecondary)),
              const SizedBox(height: 4),
              Text(
                condition,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: primaryDark),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _buildResultStat("Confidence", "${confidence.toStringAsFixed(0)}%", blueAccent)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildResultStat("Severity", severity, severityColor)),
                ],
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        // About the condition
        if (description.isNotEmpty) ...[
          const Text("About the condition", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: Text(
              description,
              style: const TextStyle(fontSize: 14, color: textSecondary, height: 1.5),
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Common Symptoms
        if (symptoms.isNotEmpty) ...[
          const Text("Common Symptoms", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: symptoms.map((s) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: blueAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: blueAccent.withValues(alpha: 0.2)),
              ),
              child: Text(
                s,
                style: const TextStyle(fontSize: 13, color: blueAccent, fontWeight: FontWeight.w600),
              ),
            )).toList(),
          ),
          const SizedBox(height: 24),
        ],
        
        // Recommendations
        const Text(
          "Care Plan & Recommendations",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Column(
            children: recommendations.asMap().entries.map((entry) {
              return Padding(
                padding: EdgeInsets.only(bottom: entry.key < recommendations.length - 1 ? 14 : 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: greenAccent.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, color: greenAccent, size: 14),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        entry.value,
                        style: const TextStyle(fontSize: 14, color: textPrimary, height: 1.4),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        
        const SizedBox(height: 32),
        
        // Action buttons
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 54,
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedImage = null;
                      _analysisResult = null;
                    });
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text("New Scan"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryDark,
                    side: BorderSide(color: primaryColor, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                height: 54,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [greenAccent, const Color(0xFF38A169)]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: greenAccent.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: _saveResult,
                  icon: const Icon(Icons.save_rounded),
                  label: const Text("Save Result"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildResultStat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PATIENT SELECTOR SHEET
// ═══════════════════════════════════════════════════════════════════════════

class _PatientSelectorSheet extends StatefulWidget {
  final Function(String id, String name) onPatientSelected;

  const _PatientSelectorSheet({required this.onPatientSelected});

  @override
  State<_PatientSelectorSheet> createState() => _PatientSelectorSheetState();
}

class _PatientSelectorSheetState extends State<_PatientSelectorSheet> {
  static const Color primaryColor = Color(0xFF4FD1C5);
  static const Color textPrimary = Color(0xFF1A202C);
  
  String _search = '';
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Select Patient",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textPrimary),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _controller,
                  onChanged: (v) => setState(() => _search = v.toLowerCase()),
                  decoration: InputDecoration(
                    hintText: "Search by name...",
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('patients').orderBy('name').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: primaryColor));
                }
                
                var patients = snapshot.data!.docs;
                if (_search.isNotEmpty) {
                  patients = patients.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return (data['name'] ?? '').toString().toLowerCase().contains(_search);
                  }).toList();
                }
                
                if (patients.isEmpty) {
                  return const Center(child: Text("No patients found"));
                }
                
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: patients.length,
                  itemBuilder: (ctx, i) {
                    final doc = patients[i];
                    final data = doc.data() as Map<String, dynamic>;
                    final name = data['name'] ?? 'Unknown';
                    final phone = data['phone'] ?? '';
                    
                    return GestureDetector(
                      onTap: () => widget.onPatientSelected(doc.id, name),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [primaryColor, const Color(0xFF319795)]),
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
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: textPrimary),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (phone.isNotEmpty)
                                    Text(
                                      phone, 
                                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                                      overflow: TextOverflow.ellipsis,
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
                              child: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: primaryColor),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
