import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

class BackendService {
  // 🔴 CHANGE THIS TO YOUR NGROK URL
  static const String baseUrl =
      'https://7674-2402-3a80-4442-3749-6147-5a9f-5ff2-da5e.ngrok-free.app';

  //static final int userId = 555;
  static final String userId = _generateUserId();

  static String _generateUserId() {
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomSuffix = random.nextInt(99999).toString().padLeft(5, '0');
    return 'user_${timestamp}_$randomSuffix';
  }

  static Future<String> sendMessage(String message,
      {double? lat, double? lng}) async {
        // ---------------- DEBUG: USER MESSAGE ----------------
      print("\n================ USER MESSAGE =================");
      print("User ID: $userId");
      print("Message: $message");
      print("Latitude: $lat");
      print("Longitude: $lng");
      print("===============================================\n");
    final response = await http.post(
      Uri.parse('$baseUrl/chat'),
      headers: {
        'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': 'true',
      },
      body: jsonEncode({
        'user_id': userId,
        'message': message,
        'lat': lat,
        'lng': lng,
      }),
    ).timeout(const Duration(seconds: 60));

    // ---------------- DEBUG: SERVER RESPONSE ----------------
    print("\n================ SERVER RESPONSE ================");
    print("Status Code: ${response.statusCode}");
    print("Raw Body: ${response.body}");
    print("=================================================\n");

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      
      final reply = data['reply'] as String;

      // ---------------- DEBUG: BOT REPLY ----------------
      print("\n================ BOT REPLY =====================");
      print(reply);
      print("================================================\n");

      return reply;
    } else {
      throw Exception('Server error: ${response.statusCode}');
    }
  }

  static Future<void> updateLocation({
    required String userId,
    required double lat,
    required double lng,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/update_location'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({
          'user_id': userId,
          'lat': lat,
          'lng': lng,
          'address_type': 'current_location',
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        print("✅ Backend Location Sync: ${response.body}");
      } else {
        print("❌ Backend Sync Failed: ${response.statusCode}");
      }
    } catch (e) {
      print("⚠️ Network error during location sync: $e");
    }
  }
}