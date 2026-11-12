import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:smartshop/core/constants.dart';
import 'package:smartshop/core/theme.dart';
import 'package:smartshop/core/utils/geo.dart';
import 'package:smartshop/l10n/strings.dart';
import 'package:smartshop/screens/common/shop_map_screen.dart';
import 'package:smartshop/services/location_service.dart';
import 'package:smartshop/viewmodels/shop_map_view_model.dart';

/// Stands in for the phone's GPS.
class FakeLocation implements LocationSource {
  FakeLocation(this.access);
  final LocationAccess access;
  final gps = StreamController<LatLng>.broadcast();

  @override
  Future<LocationAccess> requestAccess() async => access;

  @override
  Stream<LatLng> positions() => gps.stream;

  @override
  Future<void> openSettings(LocationAccess access) async {}
}

void main() {
  group('distances', () {
    test('formatted in m or km', () {
      expect(formatDistance(347), '350 m');
      expect(formatDistance(996), '1.0 km');
      expect(formatDistance(1234), '1.2 km');
    });

    test('walking time, at least a minute', () {
      expect(walkingMinutes(10), 1);
      expect(walkingMinutes(150), 2);
      expect(walkingMinutes(760), 11);
    });

    test('car park 1 is about 130 m from the koperasi', () {
      final meters = metersBetween(
        ShopMapViewModel.shop,
        const LatLng(2.340234, 111.845762),
      );
      expect(meters, inInclusiveRange(110, 150));
    });
  });

  group('Find the koperasi (MVVM)', () {
    test('follows the GPS and measures from you', () async {
      final gps = FakeLocation(LocationAccess.granted);
      final vm = ShopMapViewModel(gps);
      await vm.start();
      expect(vm.access, LocationAccess.granted);
      expect(vm.hasFix, isFalse);
      // Before a fix: measured from the koperasi, car park 1 is nearest.
      expect(vm.nearby.first.spot.number, 1);

      // Standing at motorcycle park 3, west of campus.
      gps.gps.add(const LatLng(2.341330, 111.839615));
      await Future<void>.delayed(Duration.zero);
      expect(vm.hasFix, isTrue);
      expect(vm.metersToShop, inInclusiveRange(650, 780));
      expect(vm.minutesToShop, greaterThanOrEqualTo(9));
      expect(vm.nearby.first.spot.number, 5); // car park 5 is the west one

      vm.showKind(ParkingKind.motorcycle);
      expect(vm.nearby.first.spot.number, 3);
      expect(vm.nearby.first.meters, lessThan(5));
      vm.dispose();
    });

    test('location refused: no position, still lists parking', () async {
      final vm = ShopMapViewModel(FakeLocation(LocationAccess.denied));
      await vm.start();
      expect(vm.access, LocationAccess.denied);
      expect(vm.metersToShop, isNull);
      expect(vm.nearby, hasLength(5));
      final distances = [for (final n in vm.nearby) n.meters];
      expect(distances, orderedEquals([...distances]..sort()));
      vm.dispose();
    });
  });

  testWidgets('map screen shows distance and nearest parking', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    final gps = FakeLocation(LocationAccess.granted);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(useGoogleFonts: false),
        supportedLocales: AppStrings.supportedLocales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: ShopMapScreen(locationSource: gps),
      ),
    );
    await tester.pump();
    expect(find.text('Finding your location…'), findsOneWidget);

    gps.gps.add(const LatLng(2.341977, 111.843623)); // Dewan Canselor
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('min walk'), findsOneWidget);
    expect(find.text('Nearest parking'), findsOneWidget);
    expect(find.textContaining('Nearest'), findsWidgets);

    await tester.tap(find.text('Motorcycle'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Motorcycle park 3'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox()); // stop the animations
  });
}
