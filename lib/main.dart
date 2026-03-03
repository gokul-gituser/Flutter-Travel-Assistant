import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;  

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: LocationScreen(),
    );
  }
}

class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  String locationText = "Press button to get location";

  Future<void> getLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          locationText = "Location services are disabled.";
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          locationText = "Permission permanently denied.";
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        locationText =
            "Latitude: ${position.latitude}\nLongitude: ${position.longitude}";
      });
      //await sendLocationToBackend(position.latitude, position.longitude);

      print("Latitude: ${position.latitude}");
      print("Longitude: ${position.longitude}");

    } catch (e) {
      setState(() {
        locationText = "Error: $e";
      });
    }
  }

  Future<void> sendLocationToBackend(
    double lat,
    double lng,
    ) async {
  final url = Uri.parse(
    "https://ff49-2402-3a80-1cb3-3c33-bc83-a65d-9cca-ad88.ngrok-free.app/update_location",
  );

  final response = await http.post(
    url,
    headers: {"Content-Type": "application/json"},
    body: jsonEncode({
      "user_id": "user_123",   
      "lat": lat,
      "lng": lng,
      "city": null,
      "accuracy_m": null,
      "address_type": "current_location"
    }),
  );

  if (response.statusCode == 200) {
    setState(() {
      locationText += "\n\nSent to backend successfully.";
    });
  } else {
    setState(() {
      locationText +=
          "\n\nBackend error: ${response.statusCode}";
    });
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Location Test")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(locationText, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: getLocation,
              child: const Text("Get Location"),
            ),
          ],
        ),
      ),
    );
  }
}