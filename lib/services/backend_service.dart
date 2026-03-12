import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

class BackendService {
  // 🔴 CHANGE THIS TO YOUR NGROK URL
  static const String baseUrl =
      'https://cc46-2402-3a80-4228-8372-753e-6107-b97b-6b7a.ngrok-free.app';

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
}