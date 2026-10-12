import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:coffeecore/screens/Farm%20Management/models/drought_risk_model.dart';
import 'package:coffeecore/screens/Farm%20Management/models/farm_polygon_model.dart';
import 'package:coffeecore/screens/Farm%20Management/models/ndvi_history_entry_model.dart';
import 'package:coffeecore/screens/Farm%20Management/services/climate_satellite_service.dart';
import 'package:coffeecore/screens/Farm%20Management/services/drought_risk_service.dart';
import 'package:coffeecore/screens/Farm%20Management/services/farm_mapping_service.dart';
import 'package:coffeecore/screens/Farm%20Management/services/sentinel_hub_service.dart';
import 'package:coffeecore/screens/Farm%20Management/services/service_exceptions.dart';

/// Which provider the Climate & Satellite tab's vegetation-health card is
/// currently reading from. Both sources are fetched/cached independently
/// so switching back and forth never re-fetches data that's still fresh.
enum SatelliteSource { agroMonitoring, sentinelHub }

/// Latest climate/satellite data for the selected farm, with refresh
/// orchestration and loading/error state. Never fabricates data on
/// failure — surfaces [ServiceUnavailableException.userMessage] instead.
class ClimateSatelliteProvider with ChangeNotifier {
  final FarmPolygon farm;
  final ClimateSatelliteService _climateService;
  final FarmMappingService _mappingService;
  final SentinelHubService _sentinelHubService;
  final DroughtRiskService _droughtRiskService;

  ClimateSatelliteProvider({
    required this.farm,
    ClimateSatelliteService? climateService,
    FarmMappingService? mappingService,
    SentinelHubService? sentinelHubService,
    DroughtRiskService? droughtRiskService,
  })  : _climateService = climateService ?? ClimateSatelliteService(),
        _mappingService = mappingService ?? FarmMappingService(),
        _sentinelHubService = sentinelHubService ?? SentinelHubService(),
        _droughtRiskService = droughtRiskService ?? DroughtRiskService();

  ClimateData? _climate;
  SatelliteData? _satellite;
  List<Map<String, dynamic>> _forecast = [];
  List<NdviHistoryEntry> _history = [];
  // Cached locally (in addition to farm.agroMonitoringPolyId) because
  // `farm` is immutable for the lifetime of this provider — without this,
  // every refresh after the first would see farm.agroMonitoringPolyId as
  // still null (even though it was persisted to Firestore) and try to
  // register a duplicate AgroMonitoring polygon, which the API rejects.
  String? _agroMonitoringPolyId;
  bool _isLoadingClimate = false;
  bool _isLoadingSatellite = false;
  bool _isLoadingForecast = false;
  bool _isLoadingNdwi = false;
  String? _climateError;
  String? _satelliteError;
  String? _forecastError;
  String? _ndwiError;

  // ── Sentinel Hub comparison source ──────────────────────────
  //
  // Kept entirely separate from the AgroMonitoring fields above and never
  // persisted to Firestore or written into NDVI history — this is a
  // read-only preview so the two providers can be compared side by side
  // (via [selectedSource]) before deciding whether to adopt, keep both, or
  // drop either one.
  SatelliteSource _selectedSource = SatelliteSource.agroMonitoring;
  SatelliteData? _satelliteSentinel;
  bool _isLoadingSatelliteSentinel = false;
  String? _satelliteSentinelError;

  // ── AgroMonitoring quota fallback ───────────────────────────
  //
  // The AgroMonitoring polygon quota is account-wide, so once a
  // registration is refused every other unregistered farm will be too.
  // Shared across providers so opening farm after farm doesn't hammer the
  // API with registrations that are certain to fail; expires so an
  // upgraded plan is picked up without restarting the app.
  static const Duration _agroQuotaCooldown = Duration(minutes: 10);
  static DateTime? _agroQuotaExhaustedAt;

  static bool get _isAgroQuotaCoolingDown {
    final DateTime? hitAt = _agroQuotaExhaustedAt;
    return hitAt != null &&
        DateTime.now().difference(hitAt) < _agroQuotaCooldown;
  }

  /// Set when AgroMonitoring couldn't serve this farm and the tab switched
  /// to Sentinel Hub automatically; the tab shows it as an info banner.
  String? _fallbackNotice;

  ClimateData? get climate => _climate ?? farm.climateData;
  SatelliteData? get satellite => _satellite ?? farm.satelliteData;
  List<Map<String, dynamic>> get forecast => _forecast;
  List<NdviHistoryEntry> get history => _history;
  bool get isLoadingClimate => _isLoadingClimate;
  bool get isLoadingSatellite => _isLoadingSatellite;
  bool get isLoadingForecast => _isLoadingForecast;
  bool get isLoadingNdwi => _isLoadingNdwi;
  String? get climateError => _climateError;
  String? get satelliteError => _satelliteError;
  String? get forecastError => _forecastError;
  String? get ndwiError => _ndwiError;

  SatelliteSource get selectedSource => _selectedSource;
  SatelliteData? get satelliteSentinel => _satelliteSentinel;
  bool get isLoadingSatelliteSentinel => _isLoadingSatelliteSentinel;
  String? get satelliteSentinelError => _satelliteSentinelError;
  String? get fallbackNotice => _fallbackNotice;

  /// Whichever source is currently selected — the tab reads these instead
  /// of the per-source fields/getters directly, so the toggle only needs
  /// to flip [selectedSource].
  SatelliteData? get activeSatellite =>
      _selectedSource == SatelliteSource.agroMonitoring
          ? satellite
          : _satelliteSentinel;
  bool get isLoadingActiveSatellite =>
      _selectedSource == SatelliteSource.agroMonitoring
          ? _isLoadingSatellite
          : _isLoadingSatelliteSentinel;
  String? get activeSatelliteError =>
      _selectedSource == SatelliteSource.agroMonitoring
          ? _satelliteError
          : _satelliteSentinelError;

  void setSatelliteSource(SatelliteSource source) {
    if (_selectedSource == source) return;
    _selectedSource = source;
    notifyListeners();
  }

  /// Refreshes whichever source is currently selected.
  Future<void> refreshActiveSatellite() =>
      _selectedSource == SatelliteSource.agroMonitoring
          ? refreshSatellite()
          : refreshSatelliteSentinel();

  /// Transparent, explainable Drought Risk Index derived from whatever
  /// NDVI/NDWI/climate/forecast data is currently loaded. Purely computed —
  /// no loading/error state needed since it's synchronous — and returns
  /// null only when there's no satellite data at all yet to base it on.
  /// Prefers AgroMonitoring (it has NDVI history); falls back to the
  /// Sentinel Hub reading for farms AgroMonitoring can't serve.
  DroughtRiskResult? get droughtRisk {
    final s = satellite ?? _satelliteSentinel;
    if (s == null) return null;
    return _droughtRiskService.compute(
      currentNdvi: s.ndviScore,
      ndviHistory: _history,
      currentNdwi: s.ndwiScore,
      forecast: _forecast,
      climate: climate,
    );
  }

  Future<void> refreshClimate() async {
    if (farm.farmId == null) return;
    _isLoadingClimate = true;
    _climateError = null;
    notifyListeners();
    try {
      final center = farm.center;
      final data = await _climateService.fetchCurrentClimate(
          lat: center.latitude, lng: center.longitude);
      _climate = data;
      await _mappingService.updateClimateData(farm.farmId!, data);
    } on ServiceUnavailableException catch (e) {
      _climateError = e.userMessage;
    } catch (e) {
      _climateError = 'Something went wrong fetching climate data.';
    } finally {
      _isLoadingClimate = false;
      notifyListeners();
    }
  }

  Future<void> refreshForecast() async {
    _isLoadingForecast = true;
    _forecastError = null;
    notifyListeners();
    try {
      final center = farm.center;
      final days = await _climateService.fetchFiveDayForecast(
          lat: center.latitude, lng: center.longitude);
      _forecast = days;
    } on ServiceUnavailableException catch (e) {
      _forecastError = e.userMessage;
    } catch (e) {
      _forecastError = 'Something went wrong fetching the forecast.';
    } finally {
      _isLoadingForecast = false;
      notifyListeners();
    }
  }

  Future<void> refreshSatellite() async {
    if (farm.farmId == null) return;
    _isLoadingSatellite = true;
    _satelliteError = null;
    notifyListeners();
    String? quotaFallbackReason;
    try {
      String? polyId = _agroMonitoringPolyId ?? farm.agroMonitoringPolyId;
      // Check for an orphaned polygon from a prior registration that
      // succeeded remotely but never got persisted to Firestore, before
      // registering a brand new one — avoids burning the shared
      // AgroMonitoring quota on retries. See findAgroPolygonByName.
      polyId ??= await _climateService.findAgroPolygonByName(farm.farmName);
      if (polyId == null && _isAgroQuotaCoolingDown) {
        developer.log(
          'AgroMonitoring quota hit recently — skipping registration for '
          '"${farm.farmName}" and using Sentinel Hub.',
          name: 'ClimateSatelliteProvider',
        );
        throw const ServiceUnavailableException(_agroQuotaMessage,
            isQuotaExceeded: true);
      }
      polyId ??= await _climateService.registerAgroPolygon(
        farmName: farm.farmName,
        coordinates:
            farm.coordinates.map((c) => [c.longitude, c.latitude]).toList(),
      );
      // Cache locally before attempting to persist: if the Firestore write
      // below fails, a retry must reuse this id rather than register (and
      // leak) another polygon.
      _agroMonitoringPolyId = polyId;
      if (polyId != farm.agroMonitoringPolyId) {
        try {
          await _mappingService.setAgroMonitoringPolyId(farm.farmId!, polyId);
        } catch (e) {
          developer.log(
            'Failed to persist agroMonitoringPolyId=$polyId for '
            'farm ${farm.farmId} — will retry next refresh without '
            're-registering.',
            name: 'ClimateSatelliteProvider',
            error: e,
          );
        }
      }
      final data = await _climateService.fetchLatestNdvi(agroPolyId: polyId);
      // Preserve any already-fetched NDWI reading across this NDVI refresh.
      _satellite = data.copyWith(
        ndwiScore: _satellite?.ndwiScore,
        moistureLevel: _satellite?.moistureLevel,
      );
      await _mappingService.updateSatelliteData(farm.farmId!, _satellite!);
      await _mappingService.appendNdviHistoryEntry(
        farm.farmId!,
        NdviHistoryEntry(
          ndvi: data.ndviScore,
          ndwi: _satellite?.ndwiScore,
          fetchedAt: DateTime.now(),
        ),
      );
      _fallbackNotice = null;
    } on ServiceUnavailableException catch (e) {
      if (e.isQuotaExceeded) {
        // Don't extend the cooldown when this refusal came from the skip
        // path itself, or the API would never be retried.
        if (!_isAgroQuotaCoolingDown) _agroQuotaExhaustedAt = DateTime.now();
        quotaFallbackReason = e.userMessage;
      } else {
        _satelliteError = e.userMessage;
      }
    } catch (e) {
      _satelliteError = 'Something went wrong fetching satellite data.';
    } finally {
      _isLoadingSatellite = false;
      notifyListeners();
    }
    if (quotaFallbackReason != null) {
      await _fallBackToSentinel(quotaFallbackReason);
    }
  }

  static const String _agroQuotaMessage =
      'AgroMonitoring has reached its plan limit for new farm boundaries.';

  /// AgroMonitoring can't register this farm (plan quota), so switch the
  /// tab to Sentinel Hub — which needs no registration — instead of leaving
  /// the user on an error. The AgroMonitoring error is kept so toggling
  /// back explains why that source is empty.
  Future<void> _fallBackToSentinel(String reason) async {
    _satelliteError = reason;
    _fallbackNotice = 'AgroMonitoring has reached its plan limit for new '
        'farm boundaries, so this farm is showing Sentinel Hub satellite '
        'data instead. These readings are not added to the NDVI history.';
    _selectedSource = SatelliteSource.sentinelHub;
    notifyListeners();
    if (_satelliteSentinel == null && !_isLoadingSatelliteSentinel) {
      await refreshSatelliteSentinel();
    }
  }

  /// NDVI counterpart to [refreshSatellite] via Sentinel Hub instead of
  /// AgroMonitoring — no polygon registration step, so there's nothing to
  /// persist to Firestore and nothing that can leak/exhaust quota. Purely
  /// in-memory for comparison; never written to `farm`'s satellite data or
  /// NDVI history.
  Future<void> refreshSatelliteSentinel() async {
    if (farm.farmId == null) return;
    _isLoadingSatelliteSentinel = true;
    _satelliteSentinelError = null;
    notifyListeners();
    try {
      final stats = await _sentinelHubService.fetchNdviStats(
        coordinates: farm.coordinates,
      );
      _satelliteSentinel = SatelliteData(
        ndviScore: stats.mean,
        vegetationHealth: _ndviToHealth(stats.mean),
        fetchedAt: stats.fetchedAt,
        dataSource: 'Sentinel-2 / Copernicus Data Space Ecosystem',
        ndwiScore: _satelliteSentinel?.ndwiScore,
        moistureLevel: _satelliteSentinel?.moistureLevel,
      );
    } on ServiceUnavailableException catch (e) {
      _satelliteSentinelError = e.userMessage;
    } catch (e) {
      _satelliteSentinelError =
          'Something went wrong fetching Sentinel Hub satellite data.';
    } finally {
      _isLoadingSatelliteSentinel = false;
      notifyListeners();
    }
  }

  Future<void> refreshNdwi() async {
    if (farm.farmId == null) return;
    _isLoadingNdwi = true;
    _ndwiError = null;
    notifyListeners();
    try {
      final ndwi =
          await _sentinelHubService.fetchNdwi(coordinates: farm.coordinates);
      final base = satellite;
      if (base == null) {
        throw const ServiceUnavailableException(
          'Fetch NDVI/satellite data for this farm first, then retry moisture (NDWI).',
        );
      }
      final updated = base.copyWith(
        ndwiScore: ndwi.mean,
        moistureLevel: _ndwiToMoistureLevel(ndwi.mean),
      );
      _satellite = updated;
      await _mappingService.updateSatelliteData(farm.farmId!, updated);
      await _mappingService.appendNdviHistoryEntry(
        farm.farmId!,
        NdviHistoryEntry(
          ndvi: updated.ndviScore,
          ndwi: ndwi.mean,
          fetchedAt: DateTime.now(),
        ),
      );
    } on ServiceUnavailableException catch (e) {
      _ndwiError = e.userMessage;
    } catch (e) {
      _ndwiError = 'Something went wrong fetching moisture (NDWI) data.';
    } finally {
      _isLoadingNdwi = false;
      notifyListeners();
    }
  }

  Future<void> loadNdviHistory() async {
    if (farm.farmId == null) return;
    _history = await _mappingService.fetchRecentNdviHistory(farm.farmId!);
    notifyListeners();
  }

  String _ndwiToMoistureLevel(double ndwi) {
    if (ndwi >= 0.30) return 'Saturated';
    if (ndwi >= 0.05) return 'Moist';
    if (ndwi >= -0.20) return 'Adequate';
    return 'Dry';
  }

  // Mirrors ClimateSatelliteService's private thresholds so both satellite
  // sources classify vegetation health identically.
  String _ndviToHealth(double ndvi) {
    if (ndvi >= 0.60) return 'Excellent';
    if (ndvi >= 0.40) return 'Good';
    if (ndvi >= 0.20) return 'Fair';
    return 'Poor';
  }
}
