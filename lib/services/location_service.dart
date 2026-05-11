import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../config.dart';

class ResolvedLocation {
  final double latitude;
  final double longitude;
  final String address;

  const ResolvedLocation({
    required this.latitude,
    required this.longitude,
    required this.address,
  });
}

class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  /// Ensures location services are on and the user has granted permission.
  /// Throws a [StateError] with a human-readable reason if not.
  Future<void> ensurePermission() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw StateError('Location services are disabled on this device.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw StateError('Location permission was denied.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw StateError(
        'Location permission is permanently denied. Enable it in settings.',
      );
    }
  }

  Future<ResolvedLocation> getCurrentLocation() async {
    await ensurePermission();

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );

    String address = AppConfig.defaultCity;
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = <String>[
          if ((p.street ?? '').isNotEmpty) p.street!,
          if ((p.subLocality ?? '').isNotEmpty) p.subLocality!,
          if ((p.locality ?? '').isNotEmpty) p.locality!,
          if ((p.administrativeArea ?? '').isNotEmpty) p.administrativeArea!,
        ];
        if (parts.isNotEmpty) {
          address = parts.toSet().join(', ');
        }
      }
    } catch (_) {
      // Reverse geocoding is best-effort; fall back to default city.
    }

    return ResolvedLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      address: address,
    );
  }
}
