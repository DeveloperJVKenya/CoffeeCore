import 'package:cloud_functions/cloud_functions.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:logger/logger.dart';
import 'package:coffeecore/screens/Farm%20Management/models/planetek_analysis_model.dart';
import 'package:coffeecore/screens/Farm%20Management/services/service_exceptions.dart';

/// Client for Planetek's certified EUDR Deforestation Analysis API — a
/// second, independent deforestation check alongside the Global Forest
/// Watch screening in [EudrComplianceService]. Everything sensitive
/// (client credentials, token exchange, Prefect flow polling, Ed25519
/// signature verification) happens inside the `runPlanetekDeforestationAnalysis`
/// Cloud Function (see functions/index.js) — this service only builds the
/// GeoJSON request and calls that one callable.
///
/// DEMO STATUS: Planetek's `clientSecret` has not been configured yet
/// (functions/.env secret `PLANETEK_CLIENT_SECRET` is unset as of writing —
/// see docs/planetek_eudr/README.md). Until it is, every call here fails
/// closed with a clear message via [_mapError], the same "never fabricate
/// a result" contract [EudrComplianceService] follows.
class PlanetekDeforestationService {
  final Logger _log = Logger(printer: PrettyPrinter());

  /// A flow run can take a while (submit → poll → complete); the Cloud
  /// Function itself is configured for up to 300s, so the client timeout
  /// must be at least that long or callers see a false "unavailable".
  static const Duration _callableTimeout = Duration(seconds: 320);

  Future<PlanetekAnalysisData> runCertifiedAnalysis({
    required List<LatLng> coordinates,
    String aoiName = 'aoi_4326',
  }) async {
    if (coordinates.length < 3) {
      throw const ServiceUnavailableException(
        "This farm's boundary doesn't have enough points to run a "
        'certified deforestation analysis. Please re-draw the farm boundary.',
      );
    }

    final featureCollection = _buildFeatureCollection(coordinates, aoiName);

    try {
      _log.i(
        'Planetek: submitting certified deforestation analysis '
        '(${coordinates.length} pts)',
      );
      final callable = FirebaseFunctions.instance.httpsCallable(
        'runPlanetekDeforestationAnalysis',
        options: HttpsCallableOptions(timeout: _callableTimeout),
      );
      final response = await callable.call(<String, dynamic>{
        'featureCollection': featureCollection,
      });

      final data = Map<String, dynamic>.from(response.data as Map);
      final result = PlanetekAnalysisData.fromCallableResult(data);
      _log.i(
        'Planetek: analysis complete — certified=${result.deforestationCertified}, '
        'signatureVerified=${result.signatureVerified}',
      );
      return result;
    } on FirebaseFunctionsException catch (e, st) {
      _log.e('Planetek analysis failed: ${e.code} ${e.message}',
          stackTrace: st);
      throw _mapError(e);
    } catch (e, st) {
      _log.e('Planetek analysis failed: $e', stackTrace: st);
      throw ServiceUnavailableException(
        isNetworkError(e)
            ? 'Could not reach the Planetek deforestation analysis service — check your internet connection.'
            : 'Something went wrong running the certified deforestation analysis.',
        isNetworkError: isNetworkError(e),
      );
    }
  }

  ServiceUnavailableException _mapError(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'unauthenticated':
        return const ServiceUnavailableException(
          'Sign in to run the certified EUDR deforestation analysis.',
        );
      case 'invalid-argument':
        return const ServiceUnavailableException(
          "This farm's mapped boundary isn't valid for a certified analysis. "
          'Please re-draw the farm boundary and try again.',
        );
      case 'resource-exhausted':
        return ServiceUnavailableException(
          e.message ??
              'This farm boundary is likely too large for the certified analysis. '
                  'Try again with a smaller area.',
        );
      case 'deadline-exceeded':
        return const ServiceUnavailableException(
          'The certified deforestation analysis is taking longer than expected. '
          'Please try again shortly.',
        );
      case 'failed-precondition':
        return const ServiceUnavailableException(
          'Certified EUDR analysis is not configured for this app yet.',
        );
      case 'unavailable':
      default:
        return ServiceUnavailableException(
          e.message ??
              'The certified deforestation analysis service is unavailable.',
        );
    }
  }

  /// Converts a farm boundary ring into the GeoJSON FeatureCollection /
  /// MultiPolygon shape Planetek's API expects (see EUDR_Tutorial_v1.0.pdf),
  /// mirroring the ring-closing logic already used for the GFW geostore
  /// request in EudrComplianceService.
  Map<String, dynamic> _buildFeatureCollection(
    List<LatLng> coordinates,
    String aoiName,
  ) {
    final ring = coordinates.map((c) => [c.longitude, c.latitude]).toList();
    if (ring.isNotEmpty &&
        (ring.first[0] != ring.last[0] || ring.first[1] != ring.last[1])) {
      ring.add(ring.first);
    }

    return {
      'type': 'FeatureCollection',
      'name': aoiName,
      'crs': {
        'type': 'name',
        'properties': {'name': 'urn:ogc:def:crs:OGC:1.3:CRS84'},
      },
      'features': [
        {
          'type': 'Feature',
          'properties': {'id': null},
          'geometry': {
            'type': 'MultiPolygon',
            'coordinates': [
              [ring],
            ],
          },
        },
      ],
    };
  }
}
