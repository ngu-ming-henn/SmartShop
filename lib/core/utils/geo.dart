import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

const _distance = Distance();

/// Straight-line distance in metres.
double metersBetween(LatLng a, LatLng b) =>
    _distance.as(LengthUnit.Meter, a, b);

/// Walking at about 4.5 km/h (75 m a minute); at least 1 minute.
int walkingMinutes(double meters) => math.max(1, (meters / 75).ceil());

/// 347 -> "350 m", 1234 -> "1.2 km".
String formatDistance(double meters) {
  final rounded = (meters / 10).round() * 10;
  return rounded < 1000
      ? '$rounded m'
      : '${(meters / 1000).toStringAsFixed(1)} km';
}
