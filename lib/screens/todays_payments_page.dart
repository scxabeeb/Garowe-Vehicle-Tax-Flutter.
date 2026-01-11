import 'package:flutter/material.dart';

class TodaysPaymentsPage extends StatelessWidget {
  final List<dynamic> payments;

  const TodaysPaymentsPage({
    super.key,
    required this.payments,
  });

  // 🔴 Ignore reverted payments at UI level as a safety net
  List<dynamic> get validPayments =>
      payments.where((p) => p['isReverted'] != true).toList();

  double get totalCollected {
    double sum = 0;
    for (final p in validPayments) {
      final amount = (p['amount'] as num?)?.toDouble() ?? 0;
      sum += amount;
    }
    return sum;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Today's Payments")),
      body: validPayments.isEmpty
          ? const Center(
              child: Text(
                "No payments recorded today",
                style: TextStyle(fontSize: 16),
              ),
            )
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    "Total collected: \$${totalCollected.toStringAsFixed(2)}",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
                const Divider(height: 0),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: validPayments.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      final p = validPayments[index];

                      final plate = p['plate'] ?? '';
                      final movement = p['movement'] ?? '';
                      final time = p['time'] ?? '';
                      final amount =
                          (p['amount'] as num?)?.toStringAsFixed(2) ?? '0.00';

                      return ListTile(
                        leading: const Icon(Icons.directions_car),
                        title: Text(
                          plate,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text("$movement • $time"),
                        trailing: Text(
                          "\$$amount",
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
