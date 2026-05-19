import 'package:geolocator/geolocator.dart';

class LocationService {
  /// Fetches the current user position, handling permission checks and location service status.
  /// Throws custom user-friendly error messages if fetching is unsuccessful.
  static Future<Position> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 1. Check if location services are enabled globally on the device
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception(
        'Location services are disabled on your device. Please enable location/GPS in your system settings.',
      );
    }

    // 2. Check current location permission state
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // Request permission
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission was denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permissions are permanently denied. Please enable them manually in your device settings.',
      );
    }

    // 3. Retrieve and return current high-accuracy position
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 15),
    );
  }
}
