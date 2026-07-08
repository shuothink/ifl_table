import 'package:flutter/widgets.dart';

/// Builds a body cell for one row item.
///
/// [RowT] is the application row model supplied to [IflTable] or
/// [IflPagedTable]. The returned widget is placed inside the column cell and is
/// wrapped with the table's alignment, padding, and text style.
typedef IflTableCellBuilder<RowT> =
    Widget Function(BuildContext context, RowT row);

/// Builds a summary cell for the optional summary row.
///
/// [SummaryT] is usually an aggregate model for the current dataset, but it can
/// be any object that the caller wants to render in the summary row.
typedef IflTableSummaryCellBuilder<SummaryT> =
    Widget Function(BuildContext context, SummaryT summary);

/// Preset width weights used when a column does not declare an explicit width.
///
/// The final width is still affected by [IflTableColumn.minWidth],
/// [IflTableColumn.flex], and the table's available width.
enum IflTableColumnSize { small, medium, large }

/// Describes one table column.
///
/// A column owns its header widget, its row cell builder, and optionally its
/// summary cell builder. The column width can be controlled in three ways:
///
/// * [fixedWidth] pins the column to an exact width.
/// * [minWidth] defines the lower bound for flexible columns.
/// * [flex] receives a proportional share of any remaining table width.
///
/// The deprecated [width] constructor argument is kept as an alias for
/// [fixedWidth] so older call sites can migrate gradually.
@immutable
class IflTableColumn<RowT, SummaryT> {
  /// Creates a column that can render any widget in body and summary cells.
  ///
  /// Use this constructor for rich cells such as badges, progress bars, action
  /// buttons, or custom layouts. Use [IflTableColumn.text] for simple text-only
  /// columns.
  const IflTableColumn({
    required this.id,
    required this.label,
    required this.cellBuilder,
    this.summaryBuilder,
    double? width,
    double? fixedWidth,
    this.minWidth,
    this.flex = 1,
    this.size = IflTableColumnSize.medium,
    this.alignment = Alignment.center,
    this.padding = const EdgeInsets.symmetric(horizontal: 8),
  }) : assert(width == null || fixedWidth == null),
       assert(flex > 0),
       fixedWidth = fixedWidth ?? width;

  /// Creates a convenience text column.
  ///
  /// This factory is intentionally small: it creates a [Text] header, a [Text]
  /// body cell from [valueBuilder], and an optional [Text] summary cell from
  /// [summaryValueBuilder]. For non-text content, use the default constructor.
  factory IflTableColumn.text({
    required String id,
    required String title,
    required String Function(RowT row) valueBuilder,
    String Function(SummaryT summary)? summaryValueBuilder,
    double? width,
    double? fixedWidth,
    double? minWidth,
    double flex = 1,
    IflTableColumnSize size = IflTableColumnSize.medium,
    AlignmentGeometry alignment = Alignment.center,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(horizontal: 8),
    int maxLines = 1,
    TextOverflow overflow = TextOverflow.ellipsis,
  }) {
    return IflTableColumn<RowT, SummaryT>(
      id: id,
      label: Text(title),
      width: width,
      fixedWidth: fixedWidth,
      minWidth: minWidth,
      flex: flex,
      size: size,
      alignment: alignment,
      padding: padding,
      cellBuilder: (context, row) {
        return Text(valueBuilder(row), maxLines: maxLines, overflow: overflow);
      },
      summaryBuilder: summaryValueBuilder == null
          ? null
          : (context, summary) {
              return Text(
                summaryValueBuilder(summary),
                maxLines: maxLines,
                overflow: overflow,
              );
            },
    );
  }

  /// Stable identifier for this column.
  ///
  /// The id is useful for debugging, analytics, and keeping schemas readable.
  final String id;

  /// Header widget rendered in the heading row.
  final Widget label;

  /// Builder used for every body row in this column.
  final IflTableCellBuilder<RowT> cellBuilder;

  /// Optional builder used when the table displays a summary row.
  final IflTableSummaryCellBuilder<SummaryT>? summaryBuilder;

  /// Backwards-compatible alias for [fixedWidth].
  double? get width => fixedWidth;

  /// Exact width for this column.
  ///
  /// When set, the column does not participate in remaining-width flex
  /// distribution. Do not pass both [width] and [fixedWidth].
  final double? fixedWidth;

  /// Minimum width for flexible columns.
  ///
  /// The resolved width is at least this value, or the schema-level
  /// `minColumnWidth` when this is null.
  final double? minWidth;

  /// Flexible weight used to distribute extra horizontal space.
  ///
  /// The value must be greater than zero. It is ignored when [fixedWidth] is set
  /// because fixed columns keep their exact width.
  final double flex;

  /// Preset width scale applied before extra space is distributed.
  final IflTableColumnSize size;

  /// Alignment applied to header, body, and summary cells in this column.
  final AlignmentGeometry alignment;

  /// Padding applied to header, body, and summary cells in this column.
  final EdgeInsetsGeometry padding;
}
