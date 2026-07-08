import 'ifl_table_column.dart';

/// Shared layout configuration for [IflTable] and [IflPagedTable].
///
/// A schema is intentionally separate from the row data so the same column
/// definition can be reused across normal tables, paged tables, and different
/// datasets.
class IflTableSchema<RowT, SummaryT> {
  /// Creates a schema from an ordered list of [columns].
  ///
  /// [fixedLeftColumns] controls how many leading columns remain pinned while
  /// the rest of the table scrolls horizontally.
  const IflTableSchema({
    required this.columns,
    this.fixedLeftColumns = 1,
    this.rowHeight = 36,
    this.headingRowHeight,
    this.summaryRowHeight,
    this.minColumnWidth = 72,
    this.smallColumnRatio = 0.67,
    this.largeColumnRatio = 1.2,
  }) : assert(columns.length > 0),
       assert(fixedLeftColumns >= 0),
       assert(fixedLeftColumns <= columns.length);

  /// Convenience constructor for the common one-fixed-left-column layout.
  factory IflTableSchema.fixedLeft({
    required IflTableColumn<RowT, SummaryT> leftFixed,
    required List<IflTableColumn<RowT, SummaryT>> rightColumns,
    double rowHeight = 36,
    double? headingRowHeight,
    double? summaryRowHeight,
    double minColumnWidth = 72,
  }) {
    return IflTableSchema<RowT, SummaryT>(
      columns: [leftFixed, ...rightColumns],
      fixedLeftColumns: 1,
      rowHeight: rowHeight,
      headingRowHeight: headingRowHeight,
      summaryRowHeight: summaryRowHeight,
      minColumnWidth: minColumnWidth,
    );
  }

  /// Columns in visual order from left to right.
  final List<IflTableColumn<RowT, SummaryT>> columns;

  /// Number of leading columns that stay fixed during horizontal scrolling.
  final int fixedLeftColumns;

  /// Height of every body row.
  final double rowHeight;

  /// Optional heading row height.
  ///
  /// Falls back to [rowHeight] when omitted.
  final double? headingRowHeight;

  /// Optional summary row height.
  ///
  /// Falls back to [rowHeight] when omitted.
  final double? summaryRowHeight;

  /// Default minimum width for columns that do not declare a column-level
  /// `minWidth`.
  final double minColumnWidth;

  /// Width multiplier for [IflTableColumnSize.small] columns.
  final double smallColumnRatio;

  /// Width multiplier for [IflTableColumnSize.large] columns.
  final double largeColumnRatio;

  /// Columns rendered in the fixed-left area.
  List<IflTableColumn<RowT, SummaryT>> get leftColumns =>
      columns.take(fixedLeftColumns).toList(growable: false);

  /// Columns rendered in the horizontally scrollable area.
  List<IflTableColumn<RowT, SummaryT>> get rightColumns =>
      columns.skip(fixedLeftColumns).toList(growable: false);
}
