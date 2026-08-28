import 'package:coffeecore/models/farmer_produce.dart';
import 'package:coffeecore/models/produce_trace_stage.dart';

/// A produce submission bundled with its live-computed current stage, for
/// the cooperative-wide traceability table.
class TracedSubmission {
  final FarmerProduce submission;
  final ProduceStage stage;

  const TracedSubmission({required this.submission, required this.stage});
}
