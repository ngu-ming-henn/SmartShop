import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' show LatLng;

enum LocationAccess { granted, serviceOff, denied, deniedForever }

/// Where the phone is. An interface so tests can use a fake position.
abstract class LocationSource {
  /// Asks for permission when needed.
  Future<LocationAccess> requestAccess();

  /// Live position while someone listens (stops when they cancel).
  Stream<LatLng> positions();

  /// Location turned off -> phone location settings; blocked -> app settings.
  Future<void> openSettings(LocationAccess access);
}

/// The phone's GPS through geolocator. Used only while the map is open.
class GpsLocationSource implements LocationSource {
  @override
  Future<LocationAccess> requestAccess() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationAccess.serviceOff;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return switch (permission) {
      LocationPermission.always ||
      LocationPermission.whileInUse => LocationAccess.granted,
      LocationPermission.deniedForever => LocationAccess.deniedForever,
      _ => LocationAccess.denied,
    };
  }

  @override
  Stream<LatLng> positions() => Geolocator.getPositionStream(
    // A new position every 5 m walked.
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    ),
  ).map((p) => LatLng(p.latitude, p.longitude));

  @override
  Future<void> openSettings(LocationAccess access) async {
    if (access == LocationAccess.serviceOff) {
      await Geolocator.openLocationSettings();
    } else {
      await Geolocator.openAppSettings();
    }
  }
}
