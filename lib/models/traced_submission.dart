import 'package:coffeecore/models/farmer_produce.dart';
import 'package:coffeecore/models/produce_trace_stage.dart';

/// A produce submission bundled with its live-computed current stage, for
/// the cooperative-wide traceability table.
class TracedSubmission {
  final FarmerProduce submission;
  final ProduceStage stage;
  // Populated only by ProduceTraceabilityService.tracedSubmissionsForAllCoops
  // (MainAdmin's cross-cooperative view) — empty for the single-cooperative
  // stream MarketManager/CoopAdmin use, where every row already belongs to
  // the one cooperative the screen was opened for.
  final String coopId;
  final String coopLabel;

  const TracedSubmission({
    required this.submission,
    required this.stage,
    this.coopId = '',
    this.coopLabel = '',
  });
}
