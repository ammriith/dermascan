import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class DoctorSlotsPage extends StatefulWidget {
  const DoctorSlotsPage({super.key});

  @override
  State<DoctorSlotsPage> createState() => _DoctorSlotsPageState();
}

class _DoctorSlotsPageState extends State<DoctorSlotsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Premium Colors
  static const Color primaryColor = Color(0xFF4FD1C5);
  static const Color primaryDark = Color(0xFF38B2AC);
  static const Color bgColor = Color(0xFFF8FAFC);
  static const Color cardColor = Colors.white;
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);

  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  bool _isSaving = false;

  // Weekly Schedule State
  Set<int> _selectedDays = {1, 2, 3, 4, 5};
  TimeOfDay _startTime = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 16, minute: 0);

  // Standard time slots (for visualization only in Daily tab)
  final List<String> _allTimeSlots = [
    "10:00 AM", "10:30 AM", "11:00 AM", "11:30 AM",
    "12:00 PM", "12:30 PM", "01:00 PM", "01:30 PM",
    "02:00 PM", "02:30 PM", "03:00 PM", "03:30 PM",
  ];

  Set<String> _enabledSlots = {};

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    setState(() => _isLoading = true);
    await Future.wait([
      _loadAvailability(),
      _loadWeeklySchedule(),
    ]);
    setState(() => _isLoading = false);
  }

  Future<void> _loadWeeklySchedule() async {
    final user = _auth.currentUser;
    try {
      final doc = await _firestore.collection('doctors').doc(user!.uid).get();
      final schedule = doc.data()?['weeklySchedule'] as Map<String, dynamic>?;
      if (schedule != null) {
        setState(() {
          _selectedDays = (schedule['days'] as List).cast<int>().toSet();
          final start = schedule['startTime'].split(':');
          final end = schedule['endTime'].split(':');
          _startTime = TimeOfDay(hour: int.parse(start[0]), minute: int.parse(start[1]));
          _endTime = TimeOfDay(hour: int.parse(end[0]), minute: int.parse(end[1]));
        });
      }
    } catch (e) {
      debugPrint('Error loading weekly schedule: $e');
    }
  }

  Future<void> _saveWeeklySchedule() async {
    final user = _auth.currentUser;
    if (user == null) return;
    setState(() => _isSaving = true);
    try {
      await _firestore.collection('doctors').doc(user.uid).update({
        'weeklySchedule': {
          'days': _selectedDays.toList(),
          'startTime': '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}',
          'endTime': '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}',
          'slotDuration': 20,
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Weekly schedule updated! (20min slots)"), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String get _dateStr => DateFormat('yyyy-MM-dd').format(_selectedDate);

  Future<void> _loadAvailability() async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final doc = await _firestore
          .collection('doctors')
          .doc(user.uid)
          .collection('availability')
          .doc(_dateStr)
          .get();

      if (doc.exists && doc.data()?['slots'] != null) {
        final List<dynamic> slots = doc.data()!['slots'];
        setState(() {
          _enabledSlots = slots.map((s) => s.toString()).toSet();
        });
      } else {
        // Default to all slots if none set yet
        setState(() {
          _enabledSlots = _allTimeSlots.toSet();
        });
      }
    } catch (e) {
      debugPrint('Error loading availability: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveAvailability() async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);

    try {
      await _firestore
          .collection('doctors')
          .doc(user.uid)
          .collection('availability')
          .doc(_dateStr)
          .set({
        'date': _dateStr,
        'slots': _enabledSlots.toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Availability saved successfully!"),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error saving: $e"),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          title: const Text("My Availability", style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          foregroundColor: textPrimary,
          elevation: 0,
          bottom: const TabBar(
            labelColor: primaryColor,
            unselectedLabelColor: textSecondary,
            indicatorColor: primaryColor,
            tabs: [
              Tab(text: "Daily Overrides"),
              Tab(text: "Weekly Template"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: Daily Overrides
            Column(
              children: [
                _buildDateSelector(),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: primaryColor))
                      : _buildSlotsGrid(),
                ),
                _buildBottomBar(label: "Save for this Date", onTap: _saveAvailability),
              ],
            ),
            // Tab 2: Weekly Template
            _isLoading 
              ? const Center(child: CircularProgressIndicator(color: primaryColor))
              : _buildWeeklyTemplateTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyTemplateTab() {
    final List<String> weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoBox(
            "Quick Tip", 
            "Changes here affect your general availability. You can still block specific dates in the 'Daily' tab.",
            Colors.blue,
          ),
          const SizedBox(height: 24),
          const Text("Default Working Days", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: List.generate(7, (index) {
              final dayIndex = index + 1;
              final isSelected = _selectedDays.contains(dayIndex);
              return FilterChip(
                label: Text(weekdays[index]),
                selected: isSelected,
                onSelected: (val) => setState(() => val ? _selectedDays.add(dayIndex) : _selectedDays.remove(dayIndex)),
                selectedColor: primaryColor,
                checkmarkColor: Colors.white,
                labelStyle: TextStyle(color: isSelected ? Colors.white : textPrimary),
              );
            }),
          ),
          const SizedBox(height: 32),
          const Text("Default Shift Window", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildTimePicker("Starts", _startTime, (t) => setState(() => _startTime = t))),
              const SizedBox(width: 16),
              Expanded(child: _buildTimePicker("Ends", _endTime, (t) => setState(() => _endTime = t))),
            ],
          ),
          const SizedBox(height: 24),
          const Center(
            child: Text(
              "Appointments will be booked in 20-minute intervals.",
              style: TextStyle(fontStyle: FontStyle.italic, color: textSecondary, fontSize: 12),
            ),
          ),
          const SizedBox(height: 40),
          _buildBottomBar(label: "Update Weekly Schedule", onTap: _saveWeeklySchedule),
        ],
      ),
    );
  }

  Widget _buildTimePicker(String label, TimeOfDay time, Function(TimeOfDay) onSelected) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: textSecondary)),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final picked = await showTimePicker(context: context, initialTime: time);
            if (picked != null) onSelected(picked);
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(time.format(context), style: const TextStyle(fontWeight: FontWeight.bold)),
                const Icon(Icons.access_time, size: 20, color: primaryColor),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoBox(String title, String message, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(15), border: Border.all(color: color.withAlpha(50))),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: TextStyle(fontSize: 12, color: color))),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: primaryColor),
                onPressed: () {
                  setState(() {
                    _selectedDate = _selectedDate.subtract(const Duration(days: 1));
                  });
                  _loadAvailability();
                },
              ),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 90)),
                  );
                  if (picked != null) {
                    setState(() => _selectedDate = picked);
                    _loadAvailability();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: primaryColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    DateFormat('EEEE, MMM dd').format(_selectedDate),
                    style: const TextStyle(fontWeight: FontWeight.bold, color: primaryDark),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: primaryColor),
                onPressed: () {
                  setState(() {
                    _selectedDate = _selectedDate.add(const Duration(days: 1));
                  });
                  _loadAvailability();
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            "Toggle slots you are available for this day",
            style: TextStyle(fontSize: 12, color: textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildSlotsGrid() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Time Slots",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
              ),
              Row(
                children: [
                   TextButton(
                    onPressed: () {
                      setState(() {
                        _enabledSlots = _allTimeSlots.toSet();
                      });
                    },
                    child: const Text("Select All", style: TextStyle(color: primaryColor, fontSize: 13)),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _enabledSlots.clear();
                      });
                    },
                    child: const Text("Clear All", style: TextStyle(color: Colors.red, fontSize: 13)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _allTimeSlots.map((slot) {
              final isEnabled = _enabledSlots.contains(slot);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isEnabled) {
                      _enabledSlots.remove(slot);
                    } else {
                      _enabledSlots.add(slot);
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isEnabled ? primaryColor : Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: isEnabled ? primaryColor : Colors.grey.shade300,
                      width: 1.5,
                    ),
                    boxShadow: isEnabled
                        ? [BoxShadow(color: primaryColor.withAlpha(76), blurRadius: 8, offset: const Offset(0, 4))]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isEnabled ? Icons.check_circle : Icons.circle_outlined,
                        size: 18,
                        color: isEnabled ? Colors.white : Colors.grey.shade400,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        slot,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isEnabled ? Colors.white : textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange.shade700),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    "Note: Disabling a slot will prevent patients from booking it for this specific date.",
                    style: TextStyle(fontSize: 12, color: Color(0xFF9A6E00)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar({required String label, required VoidCallback onTap}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: ElevatedButton(
        onPressed: _isSaving ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _isSaving
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
