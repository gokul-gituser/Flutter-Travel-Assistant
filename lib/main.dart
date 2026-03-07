import 'package:flutter/material.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'services/backend_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Location Tracker',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const LocationScreen(),
    );
  }
}

class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  String locationText = "Press Start to track location";
  StreamSubscription<Position>? _positionStream;
  
  // Current position
  double? currentLat;
  double? currentLng;
  
  // Nearby places
  List<NearbyPlace> nearbyPlaces = [];
  bool isLoadingPlaces = false;
  String selectedCategory = 'restaurant';

  // Categories
  final categories = [
    'restaurant',
    'cafe',
    'bar',
    'fast_food',
    'park',
    'cinema',
    'theatre',
    'hospital',
    'pharmacy',
    'atm',
    'fuel',
    'hotel',
    'supermarket',
  ];

  Future<void> startTracking() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnackBar('❌ Location services are disabled');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        _showSnackBar('❌ Permission permanently denied');
        return;
      }

      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // update every 10 meters
        ),
      ).listen((Position position) async {
        final timestamp = DateTime.now();

        setState(() {
          currentLat = position.latitude;
          currentLng = position.longitude;
          locationText =
              "📍 Current Location\n"
              "Lat: ${position.latitude.toStringAsFixed(6)}\n"
              "Lng: ${position.longitude.toStringAsFixed(6)}\n"
              "Accuracy: ${position.accuracy.toStringAsFixed(1)}m\n"
              "Updated: ${timestamp.hour}:${timestamp.minute}:${timestamp.second}";
        });

        // Send to backend (happens in background)
        BackendService.updateLocation(
          lat: position.latitude,
          lng: position.longitude,
        );
      });

      _showSnackBar('✅ Tracking started');
    } catch (e) {
      _showSnackBar('❌ Error: $e');
    }
  }

  void stopTracking() {
    _positionStream?.cancel();
    setState(() {
      locationText = "Tracking stopped.";
    });
    _showSnackBar('⏹️ Tracking stopped');
  }

  Future<void> fetchNearbyPlaces() async {
    if (currentLat == null || currentLng == null) {
      _showSnackBar('⚠️ Start tracking first to get your location');
      return;
    }

    setState(() {
      isLoadingPlaces = true;
    });

    try {
      // Call backend API
      final places = await BackendService.searchNearbyPlaces(
        lat: currentLat!,
        lng: currentLng!,
        category: selectedCategory,
        radiusMeters: 1000,
      );

      setState(() {
        nearbyPlaces = places;
        isLoadingPlaces = false;
      });

      if (places.isEmpty) {
        _showSnackBar('😕 No $selectedCategory found nearby');
      } else {
        _showSnackBar('✅ Found ${places.length} places');
      }
    } catch (e) {
      setState(() {
        isLoadingPlaces = false;
      });
      _showSnackBar('❌ Error: $e');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Location Tracker"),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // Show if tracking is active
          if (_positionStream != null)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Icon(Icons.circle, color: Colors.red, size: 12),
            ),
        ],
      ),
      body: Column(
        children: [
          // Location display card
          Card(
            margin: const EdgeInsets.all(16),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    locationText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _positionStream == null ? startTracking : null,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text("Start"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _positionStream != null ? stopTracking : null,
                        icon: const Icon(Icons.stop),
                        label: const Text("Stop"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Search controls
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Search Nearby Places',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedCategory,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: categories.map((category) {
                            return DropdownMenuItem(
                              value: category,
                              child: Text(
                                category.replaceAll('_', ' ').toUpperCase(),
                                style: const TextStyle(fontSize: 14),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedCategory = value!;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: isLoadingPlaces ? null : fetchNearbyPlaces,
                        icon: isLoadingPlaces
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.search),
                        label: const Text('Search'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Results header
          if (nearbyPlaces.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Found ${nearbyPlaces.length} places',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        nearbyPlaces.clear();
                      });
                    },
                    icon: const Icon(Icons.clear, size: 16),
                    label: const Text('Clear'),
                  ),
                ],
              ),
            ),

          const Divider(),

          // Nearby places list
          Expanded(
            child: nearbyPlaces.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isLoadingPlaces ? Icons.hourglass_empty : Icons.explore,
                          size: 64,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          isLoadingPlaces
                              ? 'Searching nearby places...'
                              : 'No places to show.\nStart tracking and search!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: nearbyPlaces.length,
                    itemBuilder: (context, index) {
                      final place = nearbyPlaces[index];
                      final distanceKm = place.distance / 1000;
                      
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            child: Icon(_getCategoryIcon(place.type)),
                          ),
                          title: Text(
                            place.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            '${place.type.toUpperCase()} • ${distanceKm < 1 ? "${place.distance.toStringAsFixed(0)}m" : "${distanceKm.toStringAsFixed(2)}km"} away',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          trailing: Text(
                            '#${index + 1}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          onTap: () => _showPlaceDetails(place),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showPlaceDetails(NearbyPlace place) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(place.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Type', place.type),
            _buildDetailRow('Distance', '${(place.distance).toStringAsFixed(0)}m'),
            _buildDetailRow('Latitude', place.lat.toStringAsFixed(6)),
            _buildDetailRow('Longitude', place.lng.toStringAsFixed(6)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String type) {
    switch (type.toLowerCase()) {
      case 'restaurant':
        return Icons.restaurant;
      case 'cafe':
        return Icons.local_cafe;
      case 'bar':
        return Icons.local_bar;
      case 'fast_food':
        return Icons.fastfood;
      case 'park':
        return Icons.park;
      case 'cinema':
      case 'theatre':
        return Icons.theaters;
      case 'hospital':
        return Icons.local_hospital;
      case 'pharmacy':
        return Icons.local_pharmacy;
      case 'atm':
        return Icons.atm;
      case 'fuel':
        return Icons.local_gas_station;
      case 'hotel':
        return Icons.hotel;
      case 'supermarket':
        return Icons.shopping_cart;
      default:
        return Icons.place;
    }
  }
}
