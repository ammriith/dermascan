import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DoctorSlotsPage extends StatefulWidget {
  const DoctorSlotsPage({super.key});

  @override
  State<DoctorSlotsPage> createState() => _DoctorSlotsPageState();
}

class DaySchedule {
  bool isEnabled;
  TimeOfDay startTime;
  TimeOfDay endTime;

  DaySchedule({
    this.isEnabled = false,
    this.startTime = const TimeOfDay(hour: 10, minute: 0),
    this.endTime = const TimeOfDay(hour: 16, minute: 0),
  });

  Map<String, dynamic> toMap() {
    return {
      'isEnabled': isEnabled,
      'startTime': '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
      'endTime': '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
    };
  }

  factory DaySchedule.fromMap(Map<String, dynamic> map) {
    final start = (map['startTime'] as String?)?.split(':') ?? ['10', '0'];
    final end = (map['endTime'] as String?)?.split(':') ?? ['16', '0'];
    return DaySchedule(
      isEnabled: map['isEnabled'] ?? false,
      startTime: TimeOfDay(hour: int.parse(start[0]), minute: int.parse(start[1])),
      endTime: TimeOfDay(hour: int.parse(end[0]), minute: int.parse(end[1])),
    );
  }

  int get totalSlots {
    if (!isEnabled) return 0;
    final startMinutes = startTime.hour * 60 + startTime.minute;
    final endMinutes = endTime.hour * 60 + endTime.minute;
    if (endMinutes <= startMinutes) return 0;
    return ((endMinutes - startMinutes) / 20).floor();
  }
}

class _DoctorSlotsPageState extends State<DoctorSlotsPage> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Premium Colors
  static const Color primaryColor = Color(0xFF4FD1C5);
  static const Color primaryDark = Color(0xFF38B2AC);
  static const Color bgColor = Color(0xFFF8FAFC);
  static const Color cardColor = Colors.white;
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);

  bool _isLoading = false;
  bool _isSaving = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  // Day-wise Schedule
  final Map<String, DaySchedule> _daySchedules = {
    'monday': DaySchedule(isEnabled: true),
    'tuesday': DaySchedule(isEnabled: true),
    'wednesday': DaySchedule(isEnabled: true),
    'thursday': DaySchedule(isEnabled: true),
    'friday': DaySchedule(isEnabled: true),
    'saturday': DaySchedule(isEnabled: false),
    'sunday': DaySchedule(isEnabled: false),
  };

  final List<Map<String, dynamic>> _weekdays = [
    {'key': 'monday', 'name': 'Mon', 'fullName': 'Monday', 'color': Colors.blue},
    {'key': 'tuesday', 'name': 'Tue', 'fullName': 'Tuesday', 'color': Colors.purple},
    {'key': 'wednesday', 'name': 'Wed', 'fullName': 'Wednesday', 'color': Colors.orange},
    {'key': 'thursday', 'name': 'Thu', 'fullName': 'Thursday', 'color': Colors.teal},
    {'key': 'friday', 'name': 'Fri', 'fullName': 'Friday', 'color': Colors.indigo},
    {'key': 'saturday', 'name': 'Sat', 'fullName': 'Saturday', 'color': Colors.pink},
    {'key': 'sunday', 'name': 'Sun', 'fullName': 'Sunday', 'color': Colors.red},
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _loadWeeklySchedule();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadWeeklySchedule() async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    setState(() => _isLoading = true);
    try {
      final doc = await _firestore.collection('doctors').doc(user.uid).get();
      final schedule = doc.data()?['weeklySchedule'] as Map<String, dynamic>?;
      
      if (schedule != null) {
        // Check if it's the new format (per-day schedule)
        if (schedule.containsKey('monday') || schedule.containsKey('perDay')) {
          final perDay = schedule['perDay'] as Map<String, dynamic>? ?? schedule;
          for (var day in _daySchedules.keys) {
            if (perDay.containsKey(day)) {
              _daySchedules[day] = DaySchedule.fromMap(perDay[day] as Map<String, dynamic>);
            }
          }
        } else {
          // Legacy format - convert to new format
          final days = (schedule['days'] as List?)?.cast<int>() ?? [];
          final start = (schedule['startTime'] as String?)?.split(':') ?? ['10', '0'];
          final end = (schedule['endTime'] as String?)?.split(':') ?? ['16', '0'];
          final startTime = TimeOfDay(hour: int.parse(start[0]), minute: int.parse(start[1]));
          final endTime = TimeOfDay(hour: int.parse(end[0]), minute: int.parse(end[1]));
          
          // Map day indices to day names
          final dayMap = {1: 'monday', 2: 'tuesday', 3: 'wednesday', 4: 'thursday', 5: 'friday', 6: 'saturday', 7: 'sunday'};
          for (var entry in _daySchedules.entries) {
            final dayIndex = dayMap.entries.firstWhere((e) => e.value == entry.key).key;
            _daySchedules[entry.key] = DaySchedule(
              isEnabled: days.contains(dayIndex),
              startTime: startTime,
              endTime: endTime,
            );
          }
        }
      }
      _animController.forward();
    } catch (e) {
      debugPrint('Error loading weekly schedule: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveWeeklySchedule() async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    final enabledDays = _daySchedules.entries.where((e) => e.value.isEnabled).toList();
    if (enabledDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enable at least one working day"), backgroundColor: Colors.orange),
      );
      return;
    }
    
    setState(() => _isSaving = true);
    try {
      // Build per-day schedule map
      final perDaySchedule = <String, dynamic>{};
      for (var entry in _daySchedules.entries) {
        perDaySchedule[entry.key] = entry.value.toMap();
      }
      
      // Also maintain legacy format for compatibility
      final dayIndices = <int>[];
      final dayMap = {'monday': 1, 'tuesday': 2, 'wednesday': 3, 'thursday': 4, 'friday': 5, 'saturday': 6, 'sunday': 7};
      for (var entry in _daySchedules.entries) {
        if (entry.value.isEnabled) {
          dayIndices.add(dayMap[entry.key]!);
        }
      }
      
      await _firestore.collection('doctors').doc(user.uid).update({
        'weeklySchedule': {
          'perDay': perDaySchedule,
          'days': dayIndices..sort(), // Legacy compatibility
          'slotDuration': 20,
        }
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 12),
                Text("Schedule saved successfully!"),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  int get _totalWeeklySlots {
    return _daySchedules.values.fold(0, (total, day) => total + day.totalSlots);
  }

  int get _enabledDaysCount {
    return _daySchedules.values.where((d) => d.isEnabled).length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: primaryColor))
        : CustomScrollView(
            slivers: [
              // Custom App Bar with Gradient
              SliverAppBar(
                expandedHeight: 160,
                floating: false,
                pinned: true,
                backgroundColor: primaryColor,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [primaryDark, primaryColor, Color(0xFF81E6D9)],
                      ),
                    ),
                    child: SafeArea(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(40),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.calendar_month_rounded, size: 36, color: Colors.white),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            "My Availability",
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Set different timings for each day",
                            style: TextStyle(fontSize: 13, color: Colors.white.withAlpha(200)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              
              // Content
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Summary Card
                        _buildSummaryCard(),
                        const SizedBox(height: 20),
                        
                        // Day-wise Schedule Cards
                        ..._weekdays.map((day) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildDayScheduleCard(day),
                        )),
                        
                        const SizedBox(height: 8),
                        
                        // Info Box
                        _buildInfoBox(),
                        const SizedBox(height: 24),
                        
                        // Save Button
                        _buildSaveButton(),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryColor.withAlpha(25), primaryDark.withAlpha(15)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryColor.withAlpha(50)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem(
            icon: Icons.calendar_today_rounded,
            value: "$_enabledDaysCount",
            label: "Working Days",
            color: Colors.blue,
          ),
          Container(height: 50, width: 1, color: Colors.grey.shade300),
          _buildSummaryItem(
            icon: Icons.event_available_rounded,
            value: "$_totalWeeklySlots",
            label: "Weekly Slots",
            color: Colors.green,
          ),
          Container(height: 50, width: 1, color: Colors.grey.shade300),
          _buildSummaryItem(
            icon: Icons.timer_outlined,
            value: "20",
            label: "Min/Slot",
            color: Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withAlpha(25),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textPrimary),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: textSecondary),
        ),
      ],
    );
  }

  Widget _buildDayScheduleCard(Map<String, dynamic> dayInfo) {
    final String dayKey = dayInfo['key'];
    final String fullName = dayInfo['fullName'];
    final Color color = dayInfo['color'];
    final DaySchedule schedule = _daySchedules[dayKey]!;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: schedule.isEnabled ? cardColor : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: schedule.isEnabled ? color.withAlpha(100) : Colors.grey.shade300,
          width: schedule.isEnabled ? 2 : 1,
        ),
        boxShadow: schedule.isEnabled
            ? [BoxShadow(color: color.withAlpha(30), blurRadius: 12, offset: const Offset(0, 4))]
            : null,
      ),
      child: Column(
        children: [
          // Day Header Row
          Row(
            children: [
              // Day icon and name
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: schedule.isEnabled ? color.withAlpha(25) : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.calendar_today_rounded,
                  size: 20,
                  color: schedule.isEnabled ? color : Colors.grey,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: schedule.isEnabled ? textPrimary : Colors.grey,
                      ),
                    ),
                    if (schedule.isEnabled)
                      Text(
                        "${schedule.totalSlots} slots available",
                        style: TextStyle(fontSize: 12, color: color),
                      )
                    else
                      const Text(
                        "Day off",
                        style: TextStyle(fontSize: 12, color: textSecondary),
                      ),
                  ],
                ),
              ),
              // Toggle Switch
              Transform.scale(
                scale: 0.9,
                child: Switch(
                  value: schedule.isEnabled,
                  onChanged: (value) {
                    setState(() {
                      _daySchedules[dayKey]!.isEnabled = value;
                    });
                  },
                  activeColor: color,
                  activeTrackColor: color.withAlpha(100),
                ),
              ),
            ],
          ),
          
          // Time Selectors (only if enabled)
          if (schedule.isEnabled) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildCompactTimePicker(
                    label: "Start",
                    time: schedule.startTime,
                    color: Colors.green,
                    onTap: () => _selectTime(dayKey, true),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(Icons.arrow_forward_rounded, size: 20, color: Colors.grey.shade400),
                ),
                Expanded(
                  child: _buildCompactTimePicker(
                    label: "End",
                    time: schedule.endTime,
                    color: Colors.red,
                    onTap: () => _selectTime(dayKey, false),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactTimePicker({
    required String label,
    required TimeOfDay time,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withAlpha(15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(50)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              label == "Start" ? Icons.play_circle_outline : Icons.stop_circle_outlined,
              size: 18,
              color: color,
            ),
            const SizedBox(width: 8),
            Text(
              time.format(context),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectTime(String dayKey, bool isStart) async {
    final schedule = _daySchedules[dayKey]!;
    final initialTime = isStart ? schedule.startTime : schedule.endTime;
    
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: primaryColor),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        if (isStart) {
          _daySchedules[dayKey]!.startTime = picked;
        } else {
          _daySchedules[dayKey]!.endTime = picked;
        }
      });
    }
  }

  Widget _buildInfoBox() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.lightbulb_rounded, size: 18, color: Colors.blue.shade700),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Set different working hours for each day. Toggle days on/off and adjust timings as needed.",
              style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(colors: [primaryDark, primaryColor]),
        boxShadow: [
          BoxShadow(color: primaryColor.withAlpha(100), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveWeeklySchedule,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: _isSaving
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.save_rounded, color: Colors.white),
                  SizedBox(width: 10),
                  Text(
                    "Save Schedule",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
      ),
    );
  }
}
