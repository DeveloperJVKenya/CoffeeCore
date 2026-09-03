import 'package:coffeecore/models/produce_trace_stage.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Full post-harvest pipeline (Received → Milling → Drying/Sorting →
/// Ready for Market → Dispatched to Market) rendered as a horizontal
/// tracker — the same "shipment tracking" pattern courier apps use (e.g.
/// Kilimall's order tracker): a left-to-right row of stops connected by a
/// line, every stop always shown regardless of how far the bag has
/// actually progressed. Completed stops get a checkmark in the accent
/// color, the current stop gets a highlighted ring around its own icon,
/// and every stop still ahead renders in grey with an em dash instead of a
/// date rather than being omitted, so a viewer always sees the whole
/// pipeline at a glance. Scrolls horizontally rather than compressing if
/// the dialog is narrower than five stops need.
///
/// Shared between the farmer's own submission dialog (produce_screen.dart)
/// and the Market Manager/CoopAdmin/MainAdmin traceability table
/// (produce_traceability_screen.dart) so both render identically.
class ProduceStageChain extends StatelessWidget {
  final List<ProduceTraceEntry> history;
  final String submissionDate;
  final Color accentColor;

  const ProduceStageChain({
    super.key,
    required this.history,
    required this.submissionDate,
    this.accentColor = const Color(0xFF5D4037), // Colors.brown[700]
  });

  static const _circleDiameter = 34.0;
  static const _nodeWidth = 76.0;
  static const _connectorWidth = 32.0;

  IconData _iconFor(ProduceStage stage) {
    switch (stage) {
      case ProduceStage.received:
        return Icons.move_to_inbox_rounded;
      case ProduceStage.milling:
        return Icons.precision_manufacturing_rounded;
      case ProduceStage.dryingSorting:
        return Icons.wb_sunny_rounded;
      case ProduceStage.readyForMarket:
        return Icons.inventory_2_rounded;
      case ProduceStage.dispatchedToMarket:
        return Icons.local_shipping_rounded;
    }
  }

  ProduceTraceEntry? _entryFor(ProduceStage stage) {
    for (final h in history) {
      if (h.stage == stage) return h;
    }
    return null;
  }

  String? _shortDate(ProduceStage stage, ProduceTraceEntry? entry) {
    if (stage == ProduceStage.received) {
      final d = DateTime.tryParse(submissionDate);
      return d != null ? DateFormat('MMM d').format(d) : submissionDate;
    }
    if (entry == null) return null;
    return DateFormat('MMM d').format(entry.timestamp.toDate());
  }

  String _tooltipFor(ProduceStage stage, ProduceTraceEntry? entry) {
    if (stage == ProduceStage.received) {
      return '${stage.label}\n$submissionDate';
    }
    if (entry == null) return '${stage.label}\nNot yet reached';
    final ts = DateFormat('yyyy-MM-dd HH:mm').format(entry.timestamp.toDate());
    return '${stage.label}\n$ts${entry.note.isNotEmpty ? "\n${entry.note}" : ""}';
  }

  @override
  Widget build(BuildContext context) {
    final stages = ProduceStage.values;
    final currentIndex =
        history.isEmpty ? 0 : stages.indexOf(history.last.stage);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(stages.length * 2 - 1, (i) {
          // Connector segments sit at the odd indices between two stops —
          // colored once the stop to its left has been fully passed
          // (i.e. the bag has already moved on to the next one).
          if (i.isOdd) {
            final leftStageIndex = (i - 1) ~/ 2;
            final passed = leftStageIndex < currentIndex;
            return SizedBox(
              width: _connectorWidth,
              height: _circleDiameter,
              child: Center(
                child: Container(
                  height: 3,
                  color: passed ? accentColor : Colors.grey[300],
                ),
              ),
            );
          }

          final si = i ~/ 2;
          final stage = stages[si];
          final isDone = si < currentIndex;
          final isCurrent = si == currentIndex;
          final isFuture = si > currentIndex;
          final entry =
              stage == ProduceStage.received ? null : _entryFor(stage);
          final dateLabel = _shortDate(stage, entry);

          return Tooltip(
            message: _tooltipFor(stage, entry),
            child: SizedBox(
              width: _nodeWidth,
              child: Column(
                children: [
                  Container(
                    width: _circleDiameter,
                    height: _circleDiameter,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isFuture ? Colors.grey[200] : accentColor,
                      border: isCurrent
                          ? Border.all(
                              color: accentColor.withValues(alpha: .35),
                              width: 3)
                          : null,
                      boxShadow: isCurrent
                          ? [
                              BoxShadow(
                                  color: accentColor.withValues(alpha: .3),
                                  blurRadius: 6,
                                  spreadRadius: 1)
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      isDone ? Icons.check_rounded : _iconFor(stage),
                      size: 16,
                      color: isFuture ? Colors.grey[500] : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    stage.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: isFuture ? FontWeight.w500 : FontWeight.bold,
                      color: isFuture ? Colors.grey[500] : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dateLabel ?? '—',
                    style: TextStyle(
                      fontSize: 10,
                      color: isFuture ? Colors.grey[400] : Colors.grey[600],
                      fontStyle: isFuture ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
