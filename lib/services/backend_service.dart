import 'dart:convert';
import 'package:http/http.dart' as http;

class NearbyPlace {
  final String name;
  final String type;
  final double lat;
  final double lng;
  final double distance;
  final Map<String, dynamic>? tags;

  NearbyPlace({
    required this.name,
    required this.type,
    required this.lat,
    required this.lng,
    required this.distance,
    this.tags,
  });

  factory NearbyPlace.fromBackendJson(Map<String, dynamic> json) {
    return NearbyPlace(
      name: json['name'] ?? 'Unknown',
      type: json['type'] ?? 'place',
      lat: json['lat'].toDouble(),
      lng: json['lng'].toDouble(),
      distance: json['distance'].toDouble(),
      tags: json['tags'],
    );
  }
}

class BackendService {
  // 🔴 CHANGE THIS TO YOUR NGROK URL
  static const String baseUrl = 'https://7487-2402-3a80-4468-bc7f-a462-50b9-6026-5c2c.ngrok-free.app';
  
  static const String userId = 'user_123'; // Or get from auth system

  // Send location to backend
  static Future<bool> updateLocation({
    required double lat,
    required double lng,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/update_location'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'lat': lat,
          'lng': lng,
        }),
      );

      if (response.statusCode == 200) {
        print('✅ Location sent to backend');
        return true;
      } else {
        print('❌ Backend error: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Network error: $e');
      return false;
    }
  }

  // Get user's last location from backend
  static Future<Map<String, dynamic>?> getLastLocation() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/last_location?user_id=$userId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['location'];
      } else {
        print('No location found');
        return null;
      }
    } catch (e) {
      print('Error: $e');
      return null;
    }
  }

  // Search nearby places using backend
  static Future<List<NearbyPlace>> searchNearbyPlaces({
    required double lat,
    required double lng,
    required String category,
    int radiusMeters = 1000,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/nearby_places'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'lat': lat,
          'lng': lng,
          'category': category,
          'radius': radiusMeters,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final places = (data['places'] as List)
            .map((p) => NearbyPlace.fromBackendJson(p))
            .toList();
        
        print('✅ Found ${places.length} places from backend');
        return places;
      } else {
        print('❌ Backend error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Error: $e');
      return [];
    }
  }

  // Auto-search using user's saved location
  static Future<List<NearbyPlace>> searchNearbyAuto({
    required String category,
    int radiusMeters = 1000,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl/nearby_places_auto?user_id=$userId&category=$category&radius=$radiusMeters',
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final places = (data['places'] as List)
            .map((p) => NearbyPlace.fromBackendJson(p))
            .toList();
        
        return places;
      } else {
        print('Backend error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error: $e');
      return [];
    }
  }
}