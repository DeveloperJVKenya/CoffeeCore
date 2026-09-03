import 'package:flutter/material.dart';

/// Consistent "modern" chrome for the produce/traceability tables — a
/// rounded, bordered card housing the DataTable, tinted header row, and
/// slightly larger/darker header text — instead of a bare DataTable
/// floating directly on the page background. Shared across
/// produce_screen.dart, market_manager_screen.dart, and
/// produce_traceability_screen.dart so all three read as one consistent
/// design language rather than three different table looks.
class ModernDataTable extends StatelessWidget {
  final List<DataColumn> columns;
  final List<DataRow> rows;
  final int? sortColumnIndex;
  final bool sortAscending;

  const ModernDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.sortColumnIndex,
    this.sortAscending = true,
  });

  /// Subtle zebra striping for a table's rows — pass `rowColor(index)` to
  /// each DataRow's `color:` while building the row list.
  static WidgetStateProperty<Color?> rowColor(int index) {
    return WidgetStateProperty.all(
      index.isEven ? Colors.white : Colors.brown.shade50.withValues(alpha: .55),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1.5,
      margin: EdgeInsets.zero,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.brown.shade100),
      ),
      clipBehavior: Clip.antiAlias,
      child: DataTable(
        sortColumnIndex: sortColumnIndex,
        sortAscending: sortAscending,
        headingRowColor: WidgetStateProperty.all(Colors.brown.shade50),
        headingTextStyle: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.brown[900],
            fontSize: 13),
        dataTextStyle: const TextStyle(fontSize: 13.5, color: Colors.black87),
        columnSpacing: 28,
        horizontalMargin: 18,
        dividerThickness: 0.4,
        columns: columns,
        rows: rows,
      ),
    );
  }
}

/// Small rounded pill for a numeric/text value that deserves more visual
/// weight than plain table text — weight, variety, etc.
class ProduceValueChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color color;

  const ProduceValueChip({
    super.key,
    required this.label,
    this.icon,
    this.color = const Color(0xFF5D4037), // Colors.brown[700]
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Text(label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}
