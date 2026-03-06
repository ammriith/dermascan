import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class PatientPaymentsPage extends StatefulWidget {
  const PatientPaymentsPage({super.key});

  @override
  State<PatientPaymentsPage> createState() => _PatientPaymentsPageState();
}

class _PatientPaymentsPageState extends State<PatientPaymentsPage> {
  ThemeData get theme => Theme.of(context);
  bool get isDark => theme.brightness == Brightness.dark;
  // 🎨 Premium Color Palette
  static const Color primaryColor = Color(0xFF4FD1C5);
  static const Color primaryDark = Color(0xFF38B2AC);
  
  static const Color greenAccent = Color(0xFF10B981);
  static const Color orangeAccent = Color(0xFFF59E0B);
  static const Color blueAccent = Color(0xFF3B82F6);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = true;
  List<Map<String, dynamic>> _pendingPayments = [];
  List<Map<String, dynamic>> _paidPayments = [];

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      final snapshot = await _firestore
          .collection('appointments')
          .where('patientId', isEqualTo: userId)
          .get();

      final allPayments = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      setState(() {
        _pendingPayments = allPayments.where((a) {
          final status = a['paymentStatus'] ?? 'Pending';
          final fee = (a['consultationFee'] ?? 0).toDouble();
          final appStatus = a['status'] ?? 'Booked';
          // Only show pending payments for appointments that aren't cancelled
          return status == 'Pending' && fee > 0 && appStatus != 'Cancelled';
        }).toList();

        _paidPayments = allPayments.where((a) {
          return a['paymentStatus'] == 'Paid';
        }).toList();

        // Sort by date (newest first)
        _pendingPayments.sort((a, b) {
          final aDate = (a['appodate'] as Timestamp?)?.toDate() ?? DateTime.now();
          final bDate = (b['appodate'] as Timestamp?)?.toDate() ?? DateTime.now();
          return bDate.compareTo(aDate);
        });
        
        _paidPayments.sort((a, b) {
          final aDate = (a['appodate'] as Timestamp?)?.toDate() ?? DateTime.now();
          final bDate = (b['appodate'] as Timestamp?)?.toDate() ?? DateTime.now();
          return bDate.compareTo(aDate);
        });

        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading payments: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: theme.cardColor,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.colorScheme.onSurface, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            "Payments & Billing",
            style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          bottom: TabBar(
            indicatorColor: primaryColor,
            labelColor: primaryColor,
            unselectedLabelColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
            tabs: const [
              Tab(text: "Pending"),
              Tab(text: "Paid History"),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: primaryColor))
            : TabBarView(
                children: [
                  _buildPaymentsList(_pendingPayments, isPending: true),
                  _buildPaymentsList(_paidPayments, isPending: false),
                ],
              ),
      ),
    );
  }

  Widget _buildPaymentsList(List<Map<String, dynamic>> payments, {required bool isPending}) {
    if (payments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: (isPending ? orangeAccent : greenAccent).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPending ? Icons.payments_outlined : Icons.check_circle_outline_rounded,
                size: 64,
                color: isPending ? orangeAccent : greenAccent,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isPending ? "No Pending Payments" : "No Payment History",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
            ),
            const SizedBox(height: 8),
            Text(
              isPending ? "You're all caught up with your bills" : "Your past payments will appear here",
              style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: payments.length,
      itemBuilder: (ctx, index) => _buildPaymentCard(payments[index], isPending: isPending),
    );
  }

  Widget _buildPaymentCard(Map<String, dynamic> payment, {required bool isPending}) {
    final doctorName = payment['doctorName'] ?? 'Doctor';
    final fee = (payment['consultationFee'] ?? 0).toDouble();
    final appodate = payment['appodate'] as Timestamp?;
    final dateStr = appodate != null ? DateFormat('MMM dd, yyyy').format(appodate.toDate()) : 'N/A';
    final timeSlot = payment['timeSlot'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (isPending ? orangeAccent : greenAccent).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isPending ? Icons.pending_actions_rounded : Icons.verified_rounded,
                  color: isPending ? orangeAccent : greenAccent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Consultation Fee",
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontWeight: FontWeight.w500),
                    ),
                    Text(
                      "Dr. $doctorName",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                    ),
                  ],
                ),
              ),
              Text(
                "₹${fee.toStringAsFixed(0)}",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
              ),
            ],
          ),
          const Divider(height: 32),
          Row(
            children: [
              _buildInfoColumn(Icons.calendar_today_rounded, "Date", dateStr),
              const SizedBox(width: 24),
              _buildInfoColumn(Icons.access_time_rounded, "Time", timeSlot),
              const Spacer(),
              if (isPending)
                ElevatedButton(
                  onPressed: () => _processPayment(payment),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text("Pay Now", style: TextStyle(fontWeight: FontWeight.bold)),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: greenAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    "PAID",
                    style: TextStyle(color: greenAccent, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoColumn(IconData icon, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
          ],
        ),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
      ],
    );
  }

  void _processPayment(Map<String, dynamic> payment) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _PaymentGatewaySheet(
        payment: payment,
        onSuccess: () {
          _loadPayments();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Payment Successful!"),
              backgroundColor: greenAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }
}

class _PaymentGatewaySheet extends StatefulWidget {
  final Map<String, dynamic> payment;
  final VoidCallback onSuccess;

  const _PaymentGatewaySheet({required this.payment, required this.onSuccess});

  @override
  State<_PaymentGatewaySheet> createState() => _PaymentGatewaySheetState();
}

class _PaymentGatewaySheetState extends State<_PaymentGatewaySheet> {
  ThemeData get theme => Theme.of(context);
  bool get isDark => theme.brightness == Brightness.dark;
  bool _isProcessing = false;
  String _selectedMethod = 'UPI';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const Text("Complete Payment", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            "Final amount to pay for Dr. ${widget.payment['doctorName']}",
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF4FD1C5).withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF4FD1C5).withOpacity(0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Total Payable", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(
                  "₹${(widget.payment['consultationFee'] ?? 0).toStringAsFixed(0)}",
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF38B2AC)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text("Select Payment Method", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          _buildMethodTile("UPI", Icons.account_balance_wallet_rounded, "Google Pay, PhonePe, etc."),
          _buildMethodTile("Card", Icons.credit_card_rounded, "Credit or Debit Card"),
          _buildMethodTile("Net Banking", Icons.account_balance_rounded, "Pay via your Bank"),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _handlePay,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4FD1C5),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isProcessing
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text("Pay ₹${(widget.payment['consultationFee'] ?? 0).toStringAsFixed(0)}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildMethodTile(String title, IconData icon, String subtitle) {
    final isSelected = _selectedMethod == title;
    return GestureDetector(
      onTap: () => setState(() => _selectedMethod = title),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4FD1C5).withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? const Color(0xFF4FD1C5) : Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? const Color(0xFF4FD1C5) : Colors.grey),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? const Color(0xFF4FD1C5) : Colors.black)),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                ],
              ),
            ),
            if (isSelected) const Icon(Icons.check_circle_rounded, color: Color(0xFF4FD1C5)),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePay() async {
    setState(() => _isProcessing = true);
    
    try {
      // Simulate network delay
      await Future.delayed(const Duration(seconds: 2));
      
      // Update Firestore
      await FirebaseFirestore.instance.collection('appointments').doc(widget.payment['id']).update({
        'paymentStatus': 'Paid',
        'paymentMethod': _selectedMethod,
        'paidAt': FieldValue.serverTimestamp(),
      });
      
      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
      }
    } catch (e) {
      debugPrint('Payment error: $e');
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Payment failed: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }
}
