import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../core/constants.dart';
import '../core/utils/geo.dart';
import '../services/location_service.dart';

/// A parking spot and how far away it is.
typedef NearbySpot = ({ParkingSpot spot, double meters});

/// MVVM: the state and logic behind "Find the koperasi". The screen only
/// draws what this exposes and calls its methods; it never touches the GPS
/// itself. Distances are measured from you once the GPS has a fix, and from
/// the koperasi before that (or when location is off).
class ShopMapViewModel extends ChangeNotifier {
  ShopMapViewModel(this._source, [this._spots = parkingSpots]);

  static const shop = LatLng(ShopLocation.latitude, ShopLocation.longitude);

  final LocationSource _source;
  final List<ParkingSpot> _spots;
  StreamSubscription<LatLng>? _gps;
  bool _disposed = false;

  /// Null while asking for permission.
  LocationAccess? access;

  /// Your position; null until the GPS has a fix.
  LatLng? me;

  /// Which parking the finder lists.
  ParkingKind kind = ParkingKind.car;

  bool get hasFix => me != null;

  /// Asks for location (again) and follows your position.
  Future<void> start() async {
    await _gps?.cancel();
    _gps = null;
    access = null;
    _notify();
    final result = await _source.requestAccess();
    if (_disposed) return;
    access = result;
    if (result == LocationAccess.granted) {
      _gps = _source.positions().listen((position) {
        me = position;
        _notify();
      });
    }
    _notify();
  }

  Future<void> openSettings() async {
    if (access != null) await _source.openSettings(access!);
  }

  void showKind(ParkingKind value) {
    kind = value;
    _notify();
  }

  double? get metersToShop => me == null ? null : metersBetween(me!, shop);

  int? get minutesToShop =>
      metersToShop == null ? null : walkingMinutes(metersToShop!);

  /// Parking of [kind], nearest first.
  List<NearbySpot> get nearby {
    final from = me ?? shop;
    return [
      for (final spot in _spots)
        if (spot.kind == kind)
          (
            spot: spot,
            meters: metersBetween(from, LatLng(spot.latitude, spot.longitude)),
          ),
    ]..sort((a, b) => a.meters.compareTo(b.meters));
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _gps?.cancel();
    super.dispose();
  }
}
