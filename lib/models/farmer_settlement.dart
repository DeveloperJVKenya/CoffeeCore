/// A farmer's computed settlement position — always derived live from their
/// submissions/deductions/payouts, never stored, so it can never go stale
/// the way a denormalized total would (see FarmerSettlementService).
class FarmerSettlement {
  final String userId;
  final String farmerName;
  final String contact;
  final double grossEarned;
  final double totalDeductions;
  final double totalPaidOut;
  // Submissions recorded before the settlement feature existed (or with no
  // variety/price selected) contribute 0 to grossEarned — surfaced here so
  // the UI can flag "N submissions have no recorded price" instead of
  // silently under-counting a farmer's earnings.
  final int unpricedSubmissionCount;

  const FarmerSettlement({
    required this.userId,
    required this.farmerName,
    required this.contact,
    required this.grossEarned,
    required this.totalDeductions,
    required this.totalPaidOut,
    required this.unpricedSubmissionCount,
  });

  double get balanceDue => grossEarned - totalDeductions - totalPaidOut;
}
