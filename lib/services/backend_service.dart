import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

class BackendService {
  // 🔴 CHANGE THIS TO YOUR NGROK URL
  static const String baseUrl =
      'https://55b6-2402-3a80-1e1b-f9ef-9daf-1adf-64d9-5a43.ngrok-free.app';

  //static final int userId = 555;

  /*
  static final String userId = _generateUserId();

  static String _generateUserId() {
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomSuffix = random.nextInt(99999).toString().padLeft(5, '0');
    return 'user_${timestamp}_$randomSuffix';
  }
*/
  static String _userId = '';

  static String get userId {
      return _userId.isNotEmpty ? _userId : 'user_anonymous';
  }

  static void setUserId(String fbUserId) {
      _userId = 'fb_$fbUserId';
  }
  /// Sync Facebook places + friends to backend after login
  static Future<void> syncFacebookData({
    required String fbUserId,
    required List<Map<String, dynamic>> posts,
    required List<Map<String, dynamic>> friends,
    Map<String, dynamic>? locationData, 
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/sync_fb_data'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({
          'user_id':    userId,    // your app's internal user_id
          'fb_user_id': fbUserId, // facebook's user id
          'posts':     posts,
          'friends':    friends,
          'location_data': locationData, 
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        print('✅ FB sync complete: ${response.body}');
      } else {
        print('❌ FB sync failed: ${response.statusCode}');
      }
    } catch (e) {
      print('⚠️ FB sync network error: $e');
    }
  }

  static Future<String> sendMessage(String message,
      {double? lat,
       double? lng,
       String? fbUserId,
      }) async {
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
        'fb_user_id': fbUserId, //for backend to find friend places
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