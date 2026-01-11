import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';

class PaymentPage extends StatefulWidget {
  const PaymentPage({super.key});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  final plateCtrl = TextEditingController();
  final ownerCtrl = TextEditingController();
  final mobileCtrl = TextEditingController();
  final qtyCtrl = TextEditingController(text: "1");
  final refCtrl = TextEditingController();

  bool loading = false;
  bool showRegister = false;
  bool refValid = false;

  String? refStatus;
  String? successLabel;

  double unitAmount = 0;
  double totalAmount = 0;

  Map<String, dynamic>? vehicle;

  List<Map<String, dynamic>> carTypes = [];
  List<Map<String, dynamic>> movements = [];

  int? selectedCarTypeId;
  int? selectedMovementId;

  void showMsg(String msg, {bool isError = true}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: isError ? Colors.red : Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
  }

  void resetAfterPayment() {
    ownerCtrl.clear();
    mobileCtrl.clear();
    qtyCtrl.text = "1";
    refCtrl.clear();

    setState(() {
      vehicle = null;
      showRegister = false;
      refValid = false;
      refStatus = null;
      unitAmount = 0;
      totalAmount = 0;
      selectedMovementId = null;
    });
  }

  void backToSearch() {
    ownerCtrl.clear();
    mobileCtrl.clear();

    setState(() {
      showRegister = false;
      vehicle = null;
      refStatus = null;
      refValid = false;
      unitAmount = 0;
      totalAmount = 0;
    });
  }

  Future<void> loadCarTypes() async {
    final res = await http.get(Uri.parse('${ApiService.baseUrl}/cartypes'));
    if (res.statusCode == 200) {
      carTypes = List<Map<String, dynamic>>.from(jsonDecode(res.body));
      if (carTypes.isNotEmpty) selectedCarTypeId = carTypes.first['id'];
    }
  }

  Future<void> loadMovements() async {
    final res = await http.get(Uri.parse('${ApiService.baseUrl}/movements'));
    if (res.statusCode == 200) {
      movements = List<Map<String, dynamic>>.from(jsonDecode(res.body));
      if (movements.isNotEmpty) selectedMovementId = movements.first['id'];
    }
  }

  Future<void> searchVehicle() async {
    final plate = plateCtrl.text.trim().toUpperCase();

    if (plate.isEmpty) {
      showMsg("Enter plate number");
      return;
    }

    try {
      setState(() {
        loading = true;
        successLabel = null;
      });

      await loadMovements();

      final result = await ApiService.getVehicle(plate);

      if (result == null) {
        await loadCarTypes();
        setState(() {
          showRegister = true;
          loading = false;
        });
        showMsg("Vehicle not found. Please register.");
        return;
      }

      final movementName =
          movements.firstWhere((m) => m['id'] == selectedMovementId)['name'];

      unitAmount =
          await ApiService.getTaxAmount(result['carTypeId'], movementName);

      calcTotal();

      setState(() {
        vehicle = result;
        mobileCtrl.text = result['mobile'] ?? "";
        loading = false;
      });
    } catch (_) {
      setState(() => loading = false);
      showMsg("Failed loading payment screen");
    }
  }

  Future<void> registerVehicle() async {
    if (ownerCtrl.text.trim().isEmpty ||
        mobileCtrl.text.trim().isEmpty ||
        selectedCarTypeId == null) {
      showMsg("Fill all fields");
      return;
    }

    if (selectedMovementId == null) {
      showMsg("Select movement");
      return;
    }

    setState(() => loading = true);

    final res = await http.post(
      Uri.parse('${ApiService.baseUrl}/vehicles'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "plateNumber": plateCtrl.text.trim(),
        "ownerName": ownerCtrl.text.trim(),
        "mobile": mobileCtrl.text.trim(),
        "carTypeId": selectedCarTypeId,
      }),
    );

    if (res.statusCode != 200 && res.statusCode != 201) {
      showMsg("Registration failed");
      setState(() => loading = false);
      return;
    }

    final v = jsonDecode(res.body);

    final movementName =
        movements.firstWhere((m) => m['id'] == selectedMovementId)['name'];

    unitAmount = await ApiService.getTaxAmount(v['carTypeId'], movementName);

    calcTotal();

    setState(() {
      vehicle = v;
      showRegister = false;
      loading = false;
    });
  }

  Future<void> checkReference() async {
    final ref = refCtrl.text.trim();
    if (ref.isEmpty) return;

    final res =
        await http.get(Uri.parse('${ApiService.baseUrl}/references/$ref'));

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      setState(() {
        if (!data['exists']) {
          refStatus = "not_found";
          refValid = false;
        } else if (data['isUsed']) {
          refStatus = "used";
          refValid = false;
        } else {
          refStatus = "available";
          refValid = true;
        }
      });
    }
  }

  void calcTotal() {
    final q = int.tryParse(qtyCtrl.text) ?? 1;
    totalAmount = unitAmount * q;
  }

  // =======================
  // SAFE PAYMENT HANDLER
  // =======================
  Future<void> payNow() async {
    if (!refValid || vehicle == null) {
      showMsg("Invalid reference number");
      return;
    }

    if (selectedMovementId == null) {
      showMsg("Select movement");
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final collectorId = prefs.getInt('collectorId');

    if (collectorId == null) {
      showMsg("Login required");
      return;
    }

    final movementName =
        movements.firstWhere((m) => m['id'] == selectedMovementId)['name'];

    setState(() => loading = true);

    final error = await ApiService.pay({
      "vehicleId": vehicle!['id'],
      "movement": movementName,
      "amount": totalAmount,
      "referenceNumber": refCtrl.text.trim(),
      "collectorId": collectorId
    });

    setState(() => loading = false);

    // ===== SUCCESS =====
    if (error == null) {
      setState(() => successLabel = "Payment saved successfully");

      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) setState(() => successLabel = null);
      });

      showMsg("Payment saved", isError: false);
      resetAfterPayment();
      return;
    }

    // ===== BACKEND JSON ERROR =====
    if (error is Map<String, dynamic>) {
      final message = error['message']?.toString() ?? "Payment failed";

      if (message.toLowerCase().contains("duplicate")) {
        showMsg("Payment already made in the last 10 minutes");
        return;
      }

      showMsg(message);
      return;
    }

    // ===== STRING ERROR (NETWORK / UNEXPECTED) =====
    if (error is String) {
      if (error.toLowerCase().contains("duplicate")) {
        showMsg("Payment already made in the last 10 minutes");
        return;
      }

      showMsg(error);
      return;
    }

    // ===== FALLBACK =====
    showMsg("Payment failed");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Vehicle Tax Payment")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (successLabel != null) ...[
              Text(
                successLabel!,
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
            ],
            TextField(
              controller: plateCtrl,
              readOnly: showRegister,
              decoration: const InputDecoration(
                labelText: "Plate Number",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: loading ? null : searchVehicle,
              child: loading
                  ? const CircularProgressIndicator()
                  : const Text("Search"),
            ),
            if (showRegister && carTypes.isNotEmpty) ...[
              const SizedBox(height: 20),
              TextField(
                controller: ownerCtrl,
                decoration: const InputDecoration(
                  labelText: "Owner Name",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: mobileCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: "Mobile Number",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: selectedCarTypeId,
                decoration: const InputDecoration(
                  labelText: "Car Type",
                  border: OutlineInputBorder(),
                ),
                items: carTypes
                    .map((c) => DropdownMenuItem<int>(
                          value: c['id'],
                          child: Text(c['name']),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => selectedCarTypeId = v),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.arrow_back),
                      label: const Text("Back to Search"),
                      onPressed: loading ? null : backToSearch,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: loading ? null : registerVehicle,
                      child: const Text("Register & Continue"),
                    ),
                  ),
                ],
              ),
            ],
            if (vehicle != null && movements.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text("Owner: ${vehicle!['ownerName']}"),
              Text("Mobile: ${mobileCtrl.text}"),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                value: selectedMovementId,
                decoration: const InputDecoration(
                  labelText: "Movement",
                  border: OutlineInputBorder(),
                ),
                items: movements
                    .map((m) => DropdownMenuItem<int>(
                          value: m['id'],
                          child: Text(m['name']),
                        ))
                    .toList(),
                onChanged: (v) async {
                  if (v == null) return;
                  setState(() => loading = true);

                  selectedMovementId = v;

                  final name =
                      movements.firstWhere((x) => x['id'] == v)['name'];

                  unitAmount = await ApiService.getTaxAmount(
                      vehicle!['carTypeId'], name);

                  setState(() {
                    calcTotal();
                    loading = false;
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Quantity",
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(calcTotal),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: refCtrl,
                decoration: InputDecoration(
                  labelText: "Reference Number",
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: checkReference,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              if (refStatus != null)
                Text(
                  refStatus == "available"
                      ? "Reference Available"
                      : refStatus == "used"
                          ? "Already Used"
                          : "Not Found",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: refStatus == "available"
                        ? Colors.green
                        : refStatus == "used"
                            ? Colors.red
                            : Colors.grey,
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                "Total Amount: \$${totalAmount.toStringAsFixed(2)}",
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: (!refValid || loading) ? null : payNow,
                child: const Text("PAY NOW"),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
