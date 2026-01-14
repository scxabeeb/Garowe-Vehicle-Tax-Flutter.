import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Switch this to false when you want to use localhost again
  static const bool isProduction = true;

  static const String _prodUrl =
      'https://garowe-vehicle-tax-system-production.up.railway.app/api';
  static const String _devUrl = 'http://localhost:5000/api';

  static const String baseUrl = isProduction ? _prodUrl : _devUrl;

  // LOGIN
  static Future<Map<String, dynamic>> login(
      String username, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        "username": username,
        "password": password,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    throw Exception(
      response.body.isNotEmpty ? response.body : "Invalid username or password",
    );
  }

  // GET VEHICLE BY PLATE
  static Future<Map<String, dynamic>?> getVehicle(String plate) async {
    final response = await http.get(
      Uri.parse('$baseUrl/vehicles/by-plate/$plate'),
      headers: {'Accept': 'application/json'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    return null;
  }

  // GET TAX AMOUNT
  static Future<double> getTaxAmount(int carTypeId, String movement) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/tax/amount?carTypeId=$carTypeId&movement=$movement',
      ),
      headers: {'Accept': 'application/json'},
    );

    if (response.statusCode == 200) {
      return (jsonDecode(response.body)['amount'] as num).toDouble();
    }

    return 0.0;
  }

  // PAY
  // returns:
  //   null -> success
  //   Map  -> backend error
  static Future<dynamic> pay(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/payments'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode(data),
    );

    final body = jsonDecode(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return null; // success
    }

    return body; // backend error
  }
}
