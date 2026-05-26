import 'dart:convert';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:http/http.dart' as http;

class FacebookService {
  static const String _graphBase = 'https://graph.facebook.com/v19.0';


  

  /// Fetch logged-in user's posts that have a place tagged
  // static Future<List<Map<String, dynamic>>> getUserPlacesFromPosts() async {
  //   final token = await FacebookAuth.instance.accessToken;
  //   if (token == null) return [];

  //   try {
  //     final url = Uri.parse(
  //       '$_graphBase/me/feed'
  //       '?fields=place{name,id,location},created_time,message'
  //       '&limit=100'
  //       '&access_token=${token.tokenString}',
  //     );
  //     final response = await http.get(url);
  //     if (response.statusCode != 200) return [];

  //     final data = jsonDecode(response.body);
  //     final posts = data['data'] as List? ?? [];

  //     return posts
  //         .where((post) => post['place'] != null)
  //         .map<Map<String, dynamic>>((post) => {
  //               'place_fb_id': post['place']['id'] ?? '',
  //               'place_name': post['place']['name'] ?? '',
  //               'city': post['place']['location']?['city'] ?? '',
  //               'country': post['place']['location']?['country'] ?? '',
  //               'lat': post['place']['location']?['latitude'],
  //               'lng': post['place']['location']?['longitude'],
  //               'visited_at': post['created_time'] ?? '',
  //             })
  //         .toList();
  //   } catch (e) {
  //     print('❌ FacebookService.getUserPlacesFromPosts error: $e');
  //     return [];
  //   }
  // }
    static Future<List<Map<String, dynamic>>> getUserPosts() async {
      final token = await FacebookAuth.instance.accessToken;
      if (token == null) return [];

      try {
        final url = Uri.parse(
          '$_graphBase/me/feed'
          '?fields=message,story,place{name,location},created_time'  // fixed ?? → ? and added place
          '&limit=100'
          '&access_token=${token.tokenString}',
        );

        final response = await http.get(url);
        if (response.statusCode != 200) return [];

        final data = jsonDecode(response.body);
        final posts = data['data'] as List? ?? [];

        return posts.map<Map<String, dynamic>>((post) {
          String text = post['message']?.toString().trim() ?? 
                        post['story']?.toString().trim() ?? '';

          // Extract tagged place if present
          final place = post['place'];
          String? placeName;
          String? placeCity;
          String? placeCountry;
          double? placeLat;
          double? placeLng;

          if (place != null) {
            placeName = place['name'];
            placeCity = place['location']?['city'];
            placeCountry = place['location']?['country'];
            placeLat = place['location']?['latitude']?.toDouble();
            placeLng = place['location']?['longitude']?.toDouble();
          }

          return {
            'message': text,
            'created_time': post['created_time'] ?? '',
            'place_name': placeName,
            'place_city': placeCity,
            'place_country': placeCountry,
            'place_lat': placeLat,
            'place_lng': placeLng,
          };
        })
        .where((p) => p['message'].toString().trim().isNotEmpty || p['place_name'] != null)
        .toList();

      } catch (e) {
        print('❌ getUserPosts error: $e');
        return [];
      }
}

  /// Friends who also use your app (Facebook only returns app-users)
  static Future<List<Map<String, dynamic>>> getAppFriends() async {
    try {
      final userData = await FacebookAuth.instance.getUserData(
        fields: 'friends{name,id}',
      );
      return ((userData['friends']?['data']) as List? ?? [])
          .cast<Map<String, dynamic>>();
    } catch (e) {
      print('❌ FacebookService.getAppFriends error: $e');
      return [];
    }
  }

  /// Get Facebook user ID of the logged-in user
  static Future<String?> getFacebookUserId() async {
    try {
      final data = await FacebookAuth.instance.getUserData(fields: 'id');
      return data['id'] as String?;
    } catch (e) {
      print('❌ FacebookService.getFacebookUserId error: $e');
      return null;
    }
  }

  /// Debug: fetch raw posts and print to console
  static Future<void> debugPrintUserPosts() async {
    final token = await FacebookAuth.instance.accessToken;
    if (token == null) {
      print('❌ No access token found');
      return;
    }

    print('\n========== ACCESS TOKEN ==========');
    print('Token: ${token.tokenString.substring(0, 20)}...');
  
    print('==================================\n');

    try {
      // First: check what permissions we actually have
      final permUrl = Uri.parse(
        '$_graphBase/me/permissions?access_token=${token.tokenString}',
      );
      final permResponse = await http.get(permUrl);
      print('📋 PERMISSIONS RESPONSE: ${permResponse.body}\n');

      // Then: try fetching posts
      final url = Uri.parse(
        '$_graphBase/me/feed'
        '?fields=message,place,created_time,story'
        '&limit=20'
        '&access_token=${token.tokenString}',
      );
      final response = await http.get(url);

      print('========== RAW POSTS RESPONSE ==========');
      print('Status: ${response.statusCode}');
      print('Body: ${response.body}');
      print('========================================\n');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final posts = data['data'] as List? ?? [];
        print('✅ Got ${posts.length} posts');
        // for (int i = 0; i < posts.length; i++) {
        //   print('--- Post $i ---');
        //   print('  message : ${posts[i]['message'] ?? '(no text)'}');
        //   print('  story   : ${posts[i]['story'] ?? '(no story)'}');
        //   print('  place   : ${posts[i]['place'] ?? '(no place)'}');
        //   print('  time    : ${posts[i]['created_time']}');
        // }
        for (int i = 0; i < posts.length; i++) {
          print('--- Post $i (RAW) ---');
          print(jsonEncode(posts[i]));  // print EVERYTHING Facebook returns
        }
      }
    } catch (e) {
      print('❌ debugPrintUserPosts error: $e');
    }
  }

  /// Fetch ALL location data available from Facebook
  static Future<Map<String, dynamic>> getAllLocationData() async {
    final token = await FacebookAuth.instance.accessToken;
    if (token == null) return {};

    Map<String, dynamic> result = {
      'profile_location': null,   // current city from profile
      'hometown': null,           // hometown from profile
      'tagged_places': [],        // check-ins / tagged places
      'posts_with_places': [],    // posts that have a place tagged
    };

    try {
      // 1. Profile location + hometown
      final profileUrl = Uri.parse(
        '$_graphBase/me'
        '?fields=location,hometown'
        '&access_token=${token.tokenString}',
      );
      final profileRes = await http.get(profileUrl);
      if (profileRes.statusCode == 200) {
        final data = jsonDecode(profileRes.body);
        result['profile_location'] = data['location']?['name'];
        result['hometown'] = data['hometown']?['name'];
      }

      // 2. Tagged places / check-ins
      final taggedUrl = Uri.parse(
        '$_graphBase/me/tagged_places'
        '?fields=place{name,location},created_time'
        '&limit=50'
        '&access_token=${token.tokenString}',
      );
      final taggedRes = await http.get(taggedUrl);
      if (taggedRes.statusCode == 200) {
        final data = jsonDecode(taggedRes.body);
        final places = data['data'] as List? ?? [];
        result['tagged_places'] = places.map((p) => {
          'place_name': p['place']?['name'] ?? '',
          'city': p['place']?['location']?['city'] ?? '',
          'country': p['place']?['location']?['country'] ?? '',
          'lat': p['place']?['location']?['latitude'],
          'lng': p['place']?['location']?['longitude'],
          'visited_at': p['created_time'] ?? '',
        }).toList();
      }

      // 3. Posts with places tagged
      final postsUrl = Uri.parse(
        '$_graphBase/me/feed'
        '?fields=message,place{name,id,location},created_time'
        '&limit=100'
        '&access_token=${token.tokenString}',
      );
      final postsRes = await http.get(postsUrl);
      if (postsRes.statusCode == 200) {
        final data = jsonDecode(postsRes.body);
        final posts = data['data'] as List? ?? [];
        result['posts_with_places'] = posts
            .where((p) => p['place'] != null)
            .map((p) => {
              'message': p['message'] ?? '',
              'place_name': p['place']['name'] ?? '',
              'city': p['place']['location']?['city'] ?? '',
              'country': p['place']['location']?['country'] ?? '',
              'lat': p['place']['location']?['latitude'],
              'lng': p['place']['location']?['longitude'],
              'visited_at': p['created_time'] ?? '',
            }).toList();
      }

    } catch (e) {
      print('❌ getAllLocationData error: $e');
    }

    return result;
  }
}