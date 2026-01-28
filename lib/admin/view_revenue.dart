import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ViewRevenuePage extends StatefulWidget {
  const ViewRevenuePage({super.key});

  @override
  State<ViewRevenuePage> createState() => _ViewRevenuePageState();
}

class _ViewRevenuePageState extends State<ViewRevenuePage> {
  final Color accentColor = const Color(0xFF4FD1C5);
  final Color bgColor = Colors.white;
  final Color inputFill = const Color(0xFFF3F4F6);
  final Color textColor = const Color(0xFF1F2937);

  bool _isLoading = true;
  double _todayRevenue = 0.0;
  double _weeklyRevenue = 0.0;
  double _monthlyRevenue = 0.0;
  double _totalRevenue = 0.0;
  int _totalAppointments = 0;
  int _completedAppointments = 0;
  List<Map<String, dynamic>> _recentTransactions = [];

  @override
  void initState() {
    super.initState();
    _fetchRevenueData();
  }

  Future<void> _fetchRevenueData() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
      final monthStart = DateTime(now.year, now.month, 1);

      double todayTotal = 0;
      double weekTotal = 0;
      double monthTotal = 0;
      double allTimeTotal = 0;
      List<Map<String, dynamic>> transactions = [];

      // 1. Fetch registration fees from patients/users
      final patientsSnapshot = await firestore.collection('patients').get();
      for (var doc in patientsSnapshot.docs) {
        final data = doc.data();
        final fee = (data['registrationFee'] ?? 0).toDouble();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

        if (fee > 0) {
          allTimeTotal += fee;

          if (createdAt != null) {
            if (createdAt.isAfter(todayStart)) todayTotal += fee;
            if (createdAt.isAfter(weekStart)) weekTotal += fee;
            if (createdAt.isAfter(monthStart)) monthTotal += fee;

            // Add to transactions
            if (transactions.length < 10) {
              transactions.add({
                'patientName': data['name'] ?? 'Unknown',
                'amount': fee,
                'date': createdAt,
                'type': 'Registration',
              });
            }
          }
        }
      }

      // 2. Fetch consultation fees from appointments
      final appointmentsSnapshot = await firestore
          .collection('appointments')
          .orderBy('createdAt', descending: true)
          .get();
      
      int totalAppts = appointmentsSnapshot.docs.length;
      int completedAppts = 0;

      for (var doc in appointmentsSnapshot.docs) {
        final data = doc.data();
        final fee = (data['consultationFee'] ?? 0).toDouble();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        final status = data['status']?.toString() ?? '';
        
        if (status == 'Completed') completedAppts++;

        // Skip cancelled appointments - don't count their revenue
        if (status == 'Cancelled') continue;

        if (fee > 0) {
          allTimeTotal += fee;

          if (createdAt != null) {
            if (createdAt.isAfter(todayStart)) todayTotal += fee;
            if (createdAt.isAfter(weekStart)) weekTotal += fee;
            if (createdAt.isAfter(monthStart)) monthTotal += fee;

            // Add to transactions
            if (transactions.length < 10) {
              transactions.add({
                'patientName': data['patient_name'] ?? 'Unknown',
                'amount': fee,
                'date': createdAt,
                'type': 'Consultation',
              });
            }
          }
        }
      }

      // Sort transactions by date (newest first)
      transactions.sort((a, b) {
        final dateA = a['date'] as DateTime?;
        final dateB = b['date'] as DateTime?;
        if (dateA == null || dateB == null) return 0;
        return dateB.compareTo(dateA);
      });

      setState(() {
        _todayRevenue = todayTotal;
        _weeklyRevenue = weekTotal;
        _monthlyRevenue = monthTotal;
        _totalRevenue = allTimeTotal;
        _totalAppointments = totalAppts;
        _completedAppointments = completedAppts;
        _recentTransactions = transactions.take(10).toList();
        _isLoading = false;
      });
    } catch (e) {
      print("Error fetching revenue: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Revenue Dashboard",
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: accentColor))
          : RefreshIndicator(
              onRefresh: _fetchRevenueData,
              color: accentColor,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Total Revenue Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [accentColor, accentColor.withOpacity(0.7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Total Revenue",
                            style: TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "₹${_totalRevenue.toStringAsFixed(2)}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildMiniStat("Appointments", "$_totalAppointments"),
                              _buildMiniStat("Completed", "$_completedAppointments"),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Revenue Period Cards
                    Text(
                      "Revenue Breakdown",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildRevenueCard("Today", _todayRevenue, Icons.today)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildRevenueCard("This Week", _weeklyRevenue, Icons.date_range)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildRevenueCard("This Month", _monthlyRevenue, Icons.calendar_month)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildRevenueCard("All Time", _totalRevenue, Icons.all_inclusive)),
                      ],
                    ),
                    const SizedBox(height: 30),

                    // Recent Transactions
                    Text(
                      "Recent Transactions",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                    ),
                    const SizedBox(height: 16),
                    if (_recentTransactions.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(30),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.receipt_long_outlined, size: 50, color: Colors.grey[300]),
                              const SizedBox(height: 10),
                              Text(
                                "No transactions yet",
                                style: TextStyle(color: Colors.grey[500], fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ..._recentTransactions.map((tx) => _buildTransactionItem(tx)),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildRevenueCard(String title, double amount, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: inputFill,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: accentColor, size: 22),
              Text(
                "₹${amount.toStringAsFixed(0)}",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: textColor.withOpacity(0.7)),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> tx) {
    final date = tx['date'] as DateTime?;
    final dateStr = date != null
        ? "${date.day}/${date.month}/${date.year}"
        : "N/A";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: inputFill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.receipt_outlined, color: accentColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx['patientName'],
                  style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
                ),
                Text(
                  "${tx['type']} • $dateStr",
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          Text(
            "+₹${tx['amount'].toStringAsFixed(0)}",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.green[600],
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}
