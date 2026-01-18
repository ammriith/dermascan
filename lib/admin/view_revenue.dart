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

      // Fetch all completed appointments with payment info
      final allPaymentsSnapshot = await firestore
          .collection('payments')
          .orderBy('createdAt', descending: true)
          .get();

      double todayTotal = 0;
      double weekTotal = 0;
      double monthTotal = 0;
      double allTimeTotal = 0;
      List<Map<String, dynamic>> transactions = [];

      for (var doc in allPaymentsSnapshot.docs) {
        final data = doc.data();
        final amount = (data['amount'] ?? 0).toDouble();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

        allTimeTotal += amount;

        if (createdAt != null) {
          if (createdAt.isAfter(todayStart)) {
            todayTotal += amount;
          }
          if (createdAt.isAfter(weekStart)) {
            weekTotal += amount;
          }
          if (createdAt.isAfter(monthStart)) {
            monthTotal += amount;
          }
        }

        // Add to recent transactions (limit to 10)
        if (transactions.length < 10) {
          String patientName = "Unknown";
          if (data['patientId'] != null) {
            final patientDoc = await firestore.collection('patients').doc(data['patientId']).get();
            if (patientDoc.exists) {
              patientName = patientDoc.data()?['name'] ?? "Unknown";
            }
          }
          transactions.add({
            'patientName': patientName,
            'amount': amount,
            'date': createdAt,
            'type': data['type'] ?? 'Consultation',
          });
        }
      }

      // Get appointment stats
      final appointmentsSnapshot = await firestore.collection('appointments').get();
      final completedSnapshot = await firestore
          .collection('appointments')
          .where('status', isEqualTo: 'Completed')
          .get();

      setState(() {
        _todayRevenue = todayTotal;
        _weeklyRevenue = weekTotal;
        _monthlyRevenue = monthTotal;
        _totalRevenue = allTimeTotal;
        _totalAppointments = appointmentsSnapshot.docs.length;
        _completedAppointments = completedSnapshot.docs.length;
        _recentTransactions = transactions;
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
