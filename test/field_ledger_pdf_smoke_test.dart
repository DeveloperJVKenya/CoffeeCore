import 'package:coffeecore/screens/Farm%20Management/models/dds_readiness_model.dart';
import 'package:coffeecore/screens/Farm%20Management/models/farm_polygon_model.dart';
import 'package:coffeecore/screens/Farm%20Management/services/field_ledger_pdf_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

FarmPolygon _farm(String id, List<LatLng> coords, String name) {
  return FarmPolygon(
    farmId: id,
    userId: 'u1',
    farmName: name,
    coordinates: coords,
    areaHectares: 1.19,
    perimeterMeters: 450,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

void main() {
  test(
      'builds a multi-farm ledger PDF without throwing, for polygon/point/empty plots',
      () async {
    final polygonFarm = _farm(
        'jsbDAAD0bpsetb4Ckzow',
        const [
          LatLng(-1.2895, 36.7600),
          LatLng(-1.2890, 36.7615),
          LatLng(-1.2905, 36.7618),
          LatLng(-1.2908, 36.7602),
        ],
        'Kingara-Hatheru RPT');

    final pointFarm =
        _farm('KE-NYR-04471', const [LatLng(-0.4201, 36.9476)], 'Wanjiru M.');

    final emptyFarm = _farm('KE-NYR-04488', const [], 'Kamau P.');

    final readiness1 = DdsReadiness.evaluate(polygonFarm);
    final readiness2 = DdsReadiness.evaluate(pointFarm);
    final readiness3 = DdsReadiness.evaluate(emptyFarm);

    final bytes = await FieldLedgerPdfService.buildMultiFarmLedger(
      [polygonFarm, pointFarm, emptyFarm],
      {
        polygonFarm.farmId!: readiness1,
        pointFarm.farmId!: readiness2,
        emptyFarm.farmId!: readiness3,
      },
    );

    expect(bytes.length, greaterThan(1000));
    expect(bytes[0], '%'.codeUnitAt(0));
  });
}
