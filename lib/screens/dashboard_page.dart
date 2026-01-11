import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import 'payment_page.dart';
import 'todays_payments_page.dart';
import 'login_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool loading = true;

  int totalVehicles = 0;
  int totalPayments = 0;
  double todayTotal = 0;

  List<dynamic> todaysPayments = [];

  int currentPage = 1;
  final int pageSize = 3; // <<< SHOW 3 PAYMENTS PER PAGE

  @override
  void initState() {
    super.initState();
    loadDashboard();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  Future<void> loadDashboard() async {
    try {
      final url = '${ApiService.baseUrl}/Dashboard';

      final res = await http.get(Uri.parse(url));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        setState(() {
          totalVehicles = data['totalVehicles'];
          totalPayments = data['totalPayments'];
          todayTotal = (data['todayTotal'] as num).toDouble();
          todaysPayments = data['todaysPayments'];
          currentPage = 1;
          loading = false;
        });
      } else {
        setState(() => loading = false);
      }
    } catch (e) {
      setState(() => loading = false);
    }
  }

  List<dynamic> get pagedPayments {
    final start = (currentPage - 1) * pageSize;
    final end = start + pageSize;
    return todaysPayments.sublist(
      start,
      end > todaysPayments.length ? todaysPayments.length : end,
    );
  }

  int get totalPages =>
      todaysPayments.isEmpty ? 1 : (todaysPayments.length / pageSize).ceil();

  List<Widget> buildPageButtons() {
    return List.generate(totalPages, (index) {
      final page = index + 1;
      final isActive = page == currentPage;

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isActive ? Colors.blue : Colors.grey.shade300,
            foregroundColor: isActive ? Colors.white : Colors.black,
            minimumSize: const Size(40, 36),
          ),
          onPressed: () {
            setState(() {
              currentPage = page;
            });
          },
          child: Text("$page"),
        ),
      );
    });
  }

  Widget statCard(String title, String value, Color color, IconData icon) {
    return Expanded(
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: color.withOpacity(0.15),
                child: Icon(icon, color: color),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard"),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle),
            onSelected: (value) {
              if (value == 'logout') logout();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'profile',
                child: ListTile(
                  leading: Icon(Icons.person),
                  title: Text('Profile'),
                ),
              ),
              PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  leading: Icon(Icons.logout),
                  title: Text('Logout'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      statCard(
                        "Total Vehicles",
                        "$totalVehicles",
                        Colors.blue,
                        Icons.directions_car,
                      ),
                      const SizedBox(width: 12),
                      statCard(
                        "Total Payments",
                        "$totalPayments",
                        Colors.green,
                        Icons.receipt_long,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      statCard(
                        "Today Collected",
                        "\$${todayTotal.toStringAsFixed(2)}",
                        Colors.orange,
                        Icons.today,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TodaysPaymentsPage(
                                    payments: todaysPayments,
                                  ),
                                ),
                              );
                            },
                            child: Row(
                              children: const [
                                Icon(Icons.list_alt, color: Colors.blue),
                                SizedBox(width: 8),
                                Text(
                                  "Today's Payments",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (todaysPayments.isEmpty)
                            const Center(child: Text("No payments today"))
                          else
                            Column(
                              children: [
                                ...pagedPayments.map((p) {
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(Icons.directions_car),
                                    title: Text(
                                      p['plate'],
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    subtitle:
                                        Text("${p['movement']} • ${p['time']}"),
                                    trailing: Text(
                                      "\$${(p['amount'] as num).toStringAsFixed(2)}",
                                      style: const TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  );
                                }).toList(),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: buildPageButtons(),
                                ),
                              ],
                            ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.payment),
                              label: const Text(
                                "Go to Vehicle Payment",
                                style: TextStyle(fontSize: 16),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const PaymentPage(),
                                  ),
                                ).then((_) => loadDashboard());
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
