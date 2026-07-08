import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'ifl_table_column.dart';
import 'ifl_table_schema.dart';
import 'ifl_table_theme.dart';

// Horizontal scrolling should stop at the edges; this keeps the table from
// bouncing past the first or last column on platforms with overscroll effects.
const ScrollPhysics _kHorizontalScrollPhysics = ClampingScrollPhysics();

// The vertical body must always be scrollable so RefreshIndicator can trigger
// even when the row count is shorter than the viewport. Clamping prevents visual
// overscroll beyond the first and last rows.
const ScrollPhysics _kVerticalScrollPhysics = AlwaysScrollableScrollPhysics(
  parent: ClampingScrollPhysics(),
);

/// A split table with optional fixed-left columns, summary row, and footer row.
///
/// [IflTable] renders the leading [IflTableSchema.fixedLeftColumns] in a fixed
/// area and renders the remaining columns in a horizontally scrollable area.
/// Vertical and horizontal scroll positions are synchronized internally so the
/// two areas behave like one table.
///
/// [RowT] is the row model type. [SummaryT] is the optional aggregate model used
/// by column summary builders.
class IflTable<RowT, SummaryT> extends StatefulWidget {
  /// Creates a table.
  const IflTable({
    super.key,
    required this.schema,
    required this.rows,
    this.summary,
    this.showSummary = true,
    this.emptyBuilder,
    this.rowKeyBuilder,
    this.theme,
    this.verticalController,
    this.horizontalController,
    this.onEndReached,
    this.endReachedThreshold = 160,
    this.footerBuilder,
    this.footerHeight = 36,
  });

  /// Column and sizing definition for the table.
  final IflTableSchema<RowT, SummaryT> schema;

  /// Rows rendered in the body.
  final List<RowT> rows;

  /// Optional aggregate object used by column summary builders.
  final SummaryT? summary;

  /// Whether to display the summary row when [summary] is non-null.
  ///
  /// When the data and summary fit inside the body viewport, the summary is
  /// rendered inline after the last row. Otherwise it is pinned below the body.
  final bool showSummary;

  /// Builder used when [rows] is empty.
  ///
  /// The empty state is still placed inside a scroll view so pull-to-refresh can
  /// work in [IflPagedTable].
  final WidgetBuilder? emptyBuilder;

  /// Optional stable key source for rows.
  ///
  /// Supplying this is helpful when row widgets contain local state or when the
  /// list is updated by paging.
  final Object? Function(RowT row)? rowKeyBuilder;

  /// Per-table theme overrides.
  final IflTableThemeData? theme;

  /// Optional external vertical controller for the table body.
  ///
  /// This controller drives the scrollable side of the table. The fixed side
  /// owns a separate internal controller that is synchronized to it.
  final ScrollController? verticalController;

  /// Optional external horizontal controller for the scrollable columns.
  final ScrollController? horizontalController;

  /// Called when the body scroll position reaches [endReachedThreshold].
  ///
  /// The callback is locked until the row count changes, which prevents repeated
  /// load-more calls while the user remains near the bottom.
  final VoidCallback? onEndReached;

  /// Distance from the bottom, in logical pixels, that triggers [onEndReached].
  final double endReachedThreshold;

  /// Optional footer rendered after rows and any inline summary.
  ///
  /// The footer occupies real scroll space. It is mainly used by
  /// [IflPagedTable] for load-more UI, but it is exposed for custom table
  /// states that should live inside the scrollable body.
  final WidgetBuilder? footerBuilder;

  /// Height of the optional [footerBuilder] row.
  final double footerHeight;

  @override
  State<IflTable<RowT, SummaryT>> createState() =>
      _IflTableState<RowT, SummaryT>();
}

class _IflTableState<RowT, SummaryT> extends State<IflTable<RowT, SummaryT>> {
  // The table is rendered as fixed-left and scrollable-right panes. Each pane
  // needs its own vertical controller because a ScrollController can only be
  // attached to one ScrollPosition in this setup.
  late final ScrollController _leftVerticalController;
  late final ScrollController _rightVerticalController;

  // Header, body, and fixed summary are separate horizontal scroll views. They
  // are synchronized to keep the same column offset while allowing each section
  // to participate in a different layout subtree.
  late final ScrollController _headerHorizontalController;
  late final ScrollController _bodyHorizontalController;
  late final ScrollController _summaryHorizontalController;
  bool _syncingVerticalOffset = false;
  bool _syncingHorizontalOffset = false;
  bool _showLeftShadow = false;
  bool _endReachedLocked = false;

  @override
  void initState() {
    super.initState();
    _leftVerticalController = ScrollController();
    _rightVerticalController = widget.verticalController ?? ScrollController();
    _headerHorizontalController = ScrollController();
    _bodyHorizontalController =
        widget.horizontalController ?? ScrollController();
    _summaryHorizontalController = ScrollController();
    _leftVerticalController.addListener(_syncRightVerticalOffset);
    _rightVerticalController.addListener(_syncLeftVerticalOffset);
    _rightVerticalController.addListener(_handleEndReached);
    _headerHorizontalController.addListener(_syncHorizontalFromHeader);
    _bodyHorizontalController.addListener(_syncHorizontalFromBody);
    _summaryHorizontalController.addListener(_syncHorizontalFromSummary);
    _bodyHorizontalController.addListener(_syncLeftShadow);
    // Wait for the first layout before checking whether horizontal scroll has
    // moved far enough to show the fixed-column shadow.
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncLeftShadow());
  }

  @override
  void didUpdateWidget(covariant IflTable<RowT, SummaryT> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rows.length != widget.rows.length) {
      // A changed row count usually means refresh or load-more completed, so a
      // future near-bottom scroll should be allowed to fire again.
      _endReachedLocked = false;
    }
  }

  @override
  void dispose() {
    _leftVerticalController.removeListener(_syncRightVerticalOffset);
    _rightVerticalController.removeListener(_syncLeftVerticalOffset);
    _rightVerticalController.removeListener(_handleEndReached);
    _headerHorizontalController.removeListener(_syncHorizontalFromHeader);
    _bodyHorizontalController.removeListener(_syncHorizontalFromBody);
    _summaryHorizontalController.removeListener(_syncHorizontalFromSummary);
    _bodyHorizontalController.removeListener(_syncLeftShadow);
    _leftVerticalController.dispose();
    _headerHorizontalController.dispose();
    _summaryHorizontalController.dispose();
    if (widget.verticalController == null) {
      _rightVerticalController.dispose();
    }
    if (widget.horizontalController == null) {
      _bodyHorizontalController.dispose();
    }
    super.dispose();
  }

  void _syncRightVerticalOffset() {
    _syncVerticalOffset(_leftVerticalController, _rightVerticalController);
  }

  void _syncLeftVerticalOffset() {
    _syncVerticalOffset(_rightVerticalController, _leftVerticalController);
  }

  void _syncVerticalOffset(ScrollController source, ScrollController target) {
    if (_syncingVerticalOffset || !source.hasClients || !target.hasClients) {
      return;
    }
    // Clamp the copied offset because the fixed and scrollable panes can have
    // slightly different extents when columns or footer rows are present.
    final targetOffset = source.offset.clamp(
      target.position.minScrollExtent,
      target.position.maxScrollExtent,
    );
    if ((target.offset - targetOffset).abs() < 0.5) {
      return;
    }
    _syncingVerticalOffset = true;
    target.jumpTo(targetOffset);
    _syncingVerticalOffset = false;
  }

  void _syncHorizontalFromHeader() {
    _syncHorizontalOffset(_headerHorizontalController);
  }

  void _syncHorizontalFromBody() {
    _syncHorizontalOffset(_bodyHorizontalController);
  }

  void _syncHorizontalFromSummary() {
    _syncHorizontalOffset(_summaryHorizontalController);
  }

  void _syncHorizontalOffset(ScrollController source) {
    if (_syncingHorizontalOffset || !source.hasClients) {
      return;
    }
    _syncingHorizontalOffset = true;
    for (final target in [
      _headerHorizontalController,
      _bodyHorizontalController,
      _summaryHorizontalController,
    ]) {
      if (identical(source, target) || !target.hasClients) {
        continue;
      }
      // Summary/header/body can have different scroll extents during layout
      // changes, so copy only the portion that each target can represent.
      final targetOffset = source.offset.clamp(
        target.position.minScrollExtent,
        target.position.maxScrollExtent,
      );
      if ((target.offset - targetOffset).abs() >= 0.5) {
        target.jumpTo(targetOffset);
      }
    }
    _syncingHorizontalOffset = false;
  }

  void _syncLeftShadow() {
    final shouldShow =
        _resolvedTheme.leftShadow &&
        widget.schema.fixedLeftColumns > 0 &&
        _bodyHorizontalController.hasClients &&
        _bodyHorizontalController.offset > 0.5;
    if (_showLeftShadow == shouldShow || !mounted) {
      return;
    }
    setState(() {
      _showLeftShadow = shouldShow;
    });
  }

  void _handleEndReached() {
    final callback = widget.onEndReached;
    if (callback == null ||
        _endReachedLocked ||
        !_rightVerticalController.hasClients) {
      return;
    }
    final position = _rightVerticalController.position;
    final distanceToEnd = position.maxScrollExtent - position.pixels;
    if (distanceToEnd <= widget.endReachedThreshold) {
      _endReachedLocked = true;
      callback();
    }
  }

  IflTableThemeData get _resolvedTheme {
    return IflTableTheme.of(context).copyWith(
      headerBackgroundColor: widget.theme?.headerBackgroundColor,
      bodyBackgroundColor: widget.theme?.bodyBackgroundColor,
      summaryBackgroundColor: widget.theme?.summaryBackgroundColor,
      borderColor: widget.theme?.borderColor,
      textStyle: widget.theme?.textStyle,
      headerTextStyle: widget.theme?.headerTextStyle,
      summaryTextStyle: widget.theme?.summaryTextStyle,
      fixedColumnShadowColor: widget.theme?.fixedColumnShadowColor,
      outerBorder: widget.theme?.outerBorder,
      verticalDividers: widget.theme?.verticalDividers,
      horizontalDividers: widget.theme?.horizontalDividers,
      leftShadow: widget.theme?.leftShadow,
      dividerThickness: widget.theme?.dividerThickness,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final schema = widget.schema;
        final theme = _materialTheme(context, _resolvedTheme);
        final widths = _IflColumnWidthResolver(
          schema,
        ).resolve(constraints.maxWidth.isFinite ? constraints.maxWidth : null);
        final fixedColumns = schema.leftColumns;
        final scrollColumns = schema.rightColumns;
        final fixedWidth = widths.leftWidth;
        final scrollWidth = widths.rightWidth;
        final headerHeight = schema.headingRowHeight ?? schema.rowHeight;
        final summaryHeight = schema.summaryRowHeight ?? schema.rowHeight;
        final hasSummary = widget.showSummary && widget.summary != null;

        return Column(
          children: [
            SizedBox(
              height: headerHeight,
              child: _IflSplitRow<RowT, SummaryT>(
                columns: schema.columns,
                fixedColumnCount: schema.fixedLeftColumns,
                widths: widths,
                rowHeight: headerHeight,
                scrollController: _headerHorizontalController,
                fixedBuilder: (column) => column.label,
                scrollBuilder: (column) => column.label,
                theme: theme,
                area: _IflTableArea.header,
                showLeftShadow: _showLeftShadow,
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, bodyConstraints) {
                  final bodyHeight = bodyConstraints.maxHeight;
                  final dataHeight = widget.rows.length * schema.rowHeight;
                  // If all rows and the summary fit in the body, keep the
                  // summary directly after the content. Otherwise reserve the
                  // bottom summary slot outside the scrollable body.
                  final canInlineSummary =
                      hasSummary &&
                      bodyHeight.isFinite &&
                      dataHeight + summaryHeight <= bodyHeight + 0.01;

                  if (widget.rows.isEmpty) {
                    return ListView(
                      controller: _rightVerticalController,
                      physics: _kVerticalScrollPhysics,
                      padding: EdgeInsets.zero,
                      children: [
                        SizedBox(
                          height: bodyHeight.isFinite ? bodyHeight : null,
                          child:
                              widget.emptyBuilder?.call(context) ??
                              const Center(child: Text('No data')),
                        ),
                      ],
                    );
                  }

                  return _IflTableBody<RowT, SummaryT>(
                    rows: widget.rows,
                    summary: widget.summary,
                    fixedColumns: fixedColumns,
                    scrollColumns: scrollColumns,
                    widths: widths,
                    rowHeight: schema.rowHeight,
                    summaryHeight: summaryHeight,
                    fixedWidth: fixedWidth,
                    scrollWidth: scrollWidth,
                    leftVerticalController: _leftVerticalController,
                    rightVerticalController: _rightVerticalController,
                    horizontalController: _bodyHorizontalController,
                    rowKeyBuilder: _rowKey,
                    theme: theme,
                    showLeftShadow: _showLeftShadow,
                    inlineSummary: canInlineSummary,
                    footerBuilder: widget.footerBuilder,
                    footerHeight: widget.footerHeight,
                  );
                },
              ),
            ),
            if (hasSummary)
              LayoutBuilder(
                builder: (context, summaryConstraints) {
                  final totalHeight = constraints.maxHeight;
                  final bodyHeight = totalHeight.isFinite
                      ? totalHeight - headerHeight
                      : null;
                  final dataHeight = widget.rows.length * schema.rowHeight;
                  final canInlineSummary =
                      bodyHeight != null &&
                      dataHeight + summaryHeight <= bodyHeight + 0.01;
                  if (canInlineSummary) {
                    return const SizedBox.shrink();
                  }
                  return SizedBox(
                    height: summaryHeight,
                    child: _IflSplitRow<RowT, SummaryT>(
                      columns: schema.columns,
                      fixedColumnCount: schema.fixedLeftColumns,
                      widths: widths,
                      rowHeight: summaryHeight,
                      scrollController: _summaryHorizontalController,
                      fixedBuilder: (column) =>
                          column.summaryBuilder?.call(
                            context,
                            widget.summary as SummaryT,
                          ) ??
                          const Text('Total'),
                      scrollBuilder: (column) =>
                          column.summaryBuilder?.call(
                            context,
                            widget.summary as SummaryT,
                          ) ??
                          const SizedBox.shrink(),
                      theme: theme,
                      area: _IflTableArea.summary,
                      showLeftShadow: _showLeftShadow,
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  Key _rowKey(int index, RowT row, String side) {
    final value = widget.rowKeyBuilder?.call(row);
    return ValueKey(value == null ? '$side-$index' : '$side-$value');
  }
}

class _IflSplitRow<RowT, SummaryT> extends StatelessWidget {
  const _IflSplitRow({
    required this.columns,
    required this.fixedColumnCount,
    required this.widths,
    required this.rowHeight,
    required this.scrollController,
    required this.fixedBuilder,
    required this.scrollBuilder,
    required this.theme,
    required this.area,
    required this.showLeftShadow,
  });

  final List<IflTableColumn<RowT, SummaryT>> columns;
  final int fixedColumnCount;
  final _ResolvedColumnWidths widths;
  final double rowHeight;
  final ScrollController scrollController;
  final Widget Function(IflTableColumn<RowT, SummaryT> column) fixedBuilder;
  final Widget Function(IflTableColumn<RowT, SummaryT> column) scrollBuilder;
  final _ResolvedIflTableTheme theme;
  final _IflTableArea area;
  final bool showLeftShadow;

  @override
  Widget build(BuildContext context) {
    final fixedColumns = columns.take(fixedColumnCount).toList(growable: false);
    final scrollColumns = columns
        .skip(fixedColumnCount)
        .toList(growable: false);

    return Stack(
      children: [
        // Header and fixed summary rows use the same split layout as the body:
        // fixed columns on the left, scrollable columns on the right.
        Row(
          children: [
            if (fixedColumns.isNotEmpty)
              SizedBox(
                width: widths.leftWidth,
                child: Row(
                  children: [
                    for (var i = 0; i < fixedColumns.length; i++)
                      _IflCell(
                        width: widths.leftWidths[i],
                        height: rowHeight,
                        column: fixedColumns[i],
                        theme: theme,
                        area: area,
                        isFirst: i == 0,
                        child: fixedBuilder(fixedColumns[i]),
                      ),
                  ],
                ),
              ),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                scrollDirection: Axis.horizontal,
                physics: _kHorizontalScrollPhysics,
                child: SizedBox(
                  width: widths.rightWidth,
                  child: Row(
                    children: [
                      for (var i = 0; i < scrollColumns.length; i++)
                        _IflCell(
                          width: widths.rightWidths[i],
                          height: rowHeight,
                          column: scrollColumns[i],
                          theme: theme,
                          area: area,
                          isFirst: fixedColumns.isEmpty && i == 0,
                          child: scrollBuilder(scrollColumns[i]),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        if (showLeftShadow && fixedColumns.isNotEmpty)
          Positioned(
            left: widths.leftWidth - 1,
            top: 0,
            bottom: 0,
            child: _IflFixedColumnShadow(color: theme.fixedColumnShadowColor),
          ),
      ],
    );
  }
}

class _IflTableBody<RowT, SummaryT> extends StatelessWidget {
  const _IflTableBody({
    required this.rows,
    required this.summary,
    required this.fixedColumns,
    required this.scrollColumns,
    required this.widths,
    required this.rowHeight,
    required this.summaryHeight,
    required this.fixedWidth,
    required this.scrollWidth,
    required this.leftVerticalController,
    required this.rightVerticalController,
    required this.horizontalController,
    required this.rowKeyBuilder,
    required this.theme,
    required this.showLeftShadow,
    required this.inlineSummary,
    required this.footerBuilder,
    required this.footerHeight,
  });

  final List<RowT> rows;
  final SummaryT? summary;
  final List<IflTableColumn<RowT, SummaryT>> fixedColumns;
  final List<IflTableColumn<RowT, SummaryT>> scrollColumns;
  final _ResolvedColumnWidths widths;
  final double rowHeight;
  final double summaryHeight;
  final double fixedWidth;
  final double scrollWidth;
  final ScrollController leftVerticalController;
  final ScrollController rightVerticalController;
  final ScrollController horizontalController;
  final Key Function(int index, RowT row, String side) rowKeyBuilder;
  final _ResolvedIflTableTheme theme;
  final bool showLeftShadow;
  final bool inlineSummary;
  final WidgetBuilder? footerBuilder;
  final double footerHeight;

  bool get _hasFooter => footerBuilder != null;

  int get _itemCount =>
      rows.length + (inlineSummary ? 1 : 0) + (_hasFooter ? 1 : 0);

  bool _isSummaryIndex(int index) => inlineSummary && index == rows.length;

  bool _isFooterIndex(int index) => _hasFooter && index == _itemCount - 1;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // The body is two ListViews side by side. They contain the same logical
        // rows and are kept vertically synchronized by the parent state.
        Row(
          children: [
            if (fixedColumns.isNotEmpty)
              SizedBox(
                width: fixedWidth,
                child: ListView.builder(
                  controller: leftVerticalController,
                  physics: _kVerticalScrollPhysics,
                  padding: EdgeInsets.zero,
                  itemCount: _itemCount,
                  itemBuilder: (context, index) {
                    if (_isSummaryIndex(index)) {
                      return _IflSummaryCells<RowT, SummaryT>(
                        columns: fixedColumns,
                        widths: widths.leftWidths,
                        summary: summary as SummaryT,
                        rowHeight: summaryHeight,
                        theme: theme,
                        showLeftBorder: true,
                        fallbackFirstCell: const Text('Total'),
                      );
                    }
                    if (_isFooterIndex(index)) {
                      // The fixed pane still needs a footer-height placeholder
                      // so both vertical lists stay the same length. The visible
                      // footer content is drawn by _IflFooterOverlay below.
                      return _IflFooterCells<RowT, SummaryT>(
                        widths: widths.leftWidths,
                        rowHeight: footerHeight,
                        theme: theme,
                      );
                    }
                    final row = rows[index];
                    return SizedBox(
                      key: rowKeyBuilder(index, row, 'left'),
                      height: rowHeight,
                      child: _IflDataCells<RowT, SummaryT>(
                        columns: fixedColumns,
                        row: row,
                        widths: widths.leftWidths,
                        rowHeight: rowHeight,
                        theme: theme,
                        showBottomBorder: true,
                        showLeftBorder: true,
                      ),
                    );
                  },
                ),
              ),
            Expanded(
              child: SingleChildScrollView(
                controller: horizontalController,
                scrollDirection: Axis.horizontal,
                physics: _kHorizontalScrollPhysics,
                child: SizedBox(
                  width: scrollWidth,
                  child: ListView.builder(
                    controller: rightVerticalController,
                    physics: _kVerticalScrollPhysics,
                    padding: EdgeInsets.zero,
                    itemCount: _itemCount,
                    itemBuilder: (context, index) {
                      if (_isSummaryIndex(index)) {
                        return _IflSummaryCells<RowT, SummaryT>(
                          columns: scrollColumns,
                          widths: widths.rightWidths,
                          summary: summary as SummaryT,
                          rowHeight: summaryHeight,
                          theme: theme,
                          showLeftBorder: fixedColumns.isEmpty,
                          fallbackFirstCell: const SizedBox.shrink(),
                        );
                      }
                      if (_isFooterIndex(index)) {
                        // Keep the scrollable pane aligned with the fixed pane.
                        // Dividers are intentionally omitted from footer cells.
                        return _IflFooterCells<RowT, SummaryT>(
                          widths: widths.rightWidths,
                          rowHeight: footerHeight,
                          theme: theme,
                        );
                      }
                      final row = rows[index];
                      return SizedBox(
                        key: rowKeyBuilder(index, row, 'right'),
                        height: rowHeight,
                        child: _IflDataCells<RowT, SummaryT>(
                          columns: scrollColumns,
                          row: row,
                          widths: widths.rightWidths,
                          rowHeight: rowHeight,
                          theme: theme,
                          showBottomBorder: true,
                          showLeftBorder: fixedColumns.isEmpty,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
        if (showLeftShadow && fixedColumns.isNotEmpty)
          Positioned(
            left: fixedWidth - 1,
            top: 0,
            // Do not draw the fixed-column shadow through the footer. The footer
            // is a single full-width state row, not part of the column grid.
            bottom: _hasFooter ? footerHeight : 0,
            child: _IflFixedColumnShadow(color: theme.fixedColumnShadowColor),
          ),
        if (_hasFooter)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: footerHeight,
            child: _IflFooterOverlay(
              theme: theme,
              child: footerBuilder!(context),
            ),
          ),
      ],
    );
  }
}

class _IflDataCells<RowT, SummaryT> extends StatelessWidget {
  const _IflDataCells({
    super.key,
    required this.columns,
    required this.row,
    required this.widths,
    required this.rowHeight,
    required this.theme,
    required this.showBottomBorder,
    required this.showLeftBorder,
  });

  final List<IflTableColumn<RowT, SummaryT>> columns;
  final RowT row;
  final List<double> widths;
  final double rowHeight;
  final _ResolvedIflTableTheme theme;
  final bool showBottomBorder;
  final bool showLeftBorder;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < columns.length; i++)
          _IflCell(
            width: widths[i],
            height: rowHeight,
            column: columns[i],
            theme: theme,
            area: _IflTableArea.body,
            isFirst: showLeftBorder && i == 0,
            showBottomBorder: showBottomBorder,
            child: columns[i].cellBuilder(context, row),
          ),
      ],
    );
  }
}

class _IflSummaryCells<RowT, SummaryT> extends StatelessWidget {
  const _IflSummaryCells({
    required this.columns,
    required this.widths,
    required this.summary,
    required this.rowHeight,
    required this.theme,
    required this.showLeftBorder,
    required this.fallbackFirstCell,
  });

  final List<IflTableColumn<RowT, SummaryT>> columns;
  final List<double> widths;
  final SummaryT summary;
  final double rowHeight;
  final _ResolvedIflTableTheme theme;
  final bool showLeftBorder;
  final Widget fallbackFirstCell;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: rowHeight,
      child: Row(
        children: [
          for (var i = 0; i < columns.length; i++)
            _IflCell(
              width: widths[i],
              height: rowHeight,
              column: columns[i],
              theme: theme,
              area: _IflTableArea.summary,
              isFirst: showLeftBorder && i == 0,
              child:
                  columns[i].summaryBuilder?.call(context, summary) ??
                  (i == 0 ? fallbackFirstCell : const SizedBox.shrink()),
            ),
        ],
      ),
    );
  }
}

class _IflFooterCells<RowT, SummaryT> extends StatelessWidget {
  const _IflFooterCells({
    required this.widths,
    required this.rowHeight,
    required this.theme,
  });

  final List<double> widths;
  final double rowHeight;
  final _ResolvedIflTableTheme theme;

  @override
  Widget build(BuildContext context) {
    final width = widths.fold(0.0, (sum, width) => sum + width);
    return SizedBox(
      width: width,
      height: rowHeight,
      // This row reserves scrollable height only. The overlay paints the actual
      // footer once across the full visible table width, which avoids a split
      // footer label and removes vertical divider artifacts.
      child: DecoratedBox(
        decoration: BoxDecoration(color: theme.bodyBackgroundColor),
      ),
    );
  }
}

class _IflFooterOverlay extends StatelessWidget {
  const _IflFooterOverlay({required this.theme, required this.child});

  final _ResolvedIflTableTheme theme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      // The footer is informational loading UI. Ignoring pointer events keeps it
      // from blocking drags while it sits at the bottom of the body stack.
      child: DecoratedBox(
        decoration: BoxDecoration(color: theme.bodyBackgroundColor),
        child: DefaultTextStyle.merge(
          style: theme.textStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _IflCell<RowT, SummaryT> extends StatelessWidget {
  const _IflCell({
    required this.width,
    required this.height,
    required this.column,
    required this.theme,
    required this.area,
    required this.child,
    this.isFirst = false,
    this.showBottomBorder = true,
  });

  final double width;
  final double height;
  final IflTableColumn<RowT, SummaryT> column;
  final _ResolvedIflTableTheme theme;
  final _IflTableArea area;
  final Widget child;
  final bool isFirst;
  final bool showBottomBorder;

  @override
  Widget build(BuildContext context) {
    final textStyle = switch (area) {
      _IflTableArea.header => theme.headerTextStyle,
      _IflTableArea.summary => theme.summaryTextStyle,
      _IflTableArea.body => theme.textStyle,
    };
    final backgroundColor = switch (area) {
      _IflTableArea.header => theme.headerBackgroundColor,
      _IflTableArea.summary => theme.summaryBackgroundColor,
      _IflTableArea.body => theme.bodyBackgroundColor,
    };
    final side = BorderSide(
      color: theme.borderColor,
      width: theme.dividerThickness,
    );

    return Container(
      width: width,
      height: height,
      alignment: column.alignment,
      padding: column.padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          // Only the first visible cell draws the left border. Every cell draws
          // its right border, producing one thin internal divider per boundary.
          top: area == _IflTableArea.header && theme.outerBorder
              ? side
              : BorderSide.none,
          left: isFirst && theme.outerBorder ? side : BorderSide.none,
          right: theme.verticalDividers ? side : BorderSide.none,
          bottom: showBottomBorder && theme.horizontalDividers
              ? side
              : BorderSide.none,
        ),
      ),
      child: DefaultTextStyle.merge(
        style: textStyle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        child: child,
      ),
    );
  }
}

class _IflFixedColumnShadow extends StatelessWidget {
  const _IflFixedColumnShadow({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      // The shadow is purely visual and should never intercept table gestures.
      child: SizedBox(
        width: 14,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                color.withValues(alpha: 0.18),
                color.withValues(alpha: 0.06),
                color.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _IflTableArea { header, body, summary }

class _IflColumnWidthResolver<RowT, SummaryT> {
  const _IflColumnWidthResolver(this.schema);

  final IflTableSchema<RowT, SummaryT> schema;

  _ResolvedColumnWidths resolve(double? availableWidth) {
    // Resolve a base width first. Fixed columns keep their exact width, while
    // flexible columns start from the larger of their min width and size/flex
    // based width.
    final baseWidths = [
      for (final column in schema.columns)
        column.fixedWidth ??
            math.max(
              column.minWidth ?? schema.minColumnWidth,
              _flexBase(column),
            ),
    ];
    final usedWidth = baseWidths.fold(0.0, (sum, width) => sum + width);
    final extraWidth = availableWidth == null
        ? 0.0
        : math.max(availableWidth - usedWidth, 0.0);
    // Only columns without fixedWidth participate in distributing extra space.
    final flexibleWeight = schema.columns.fold(0.0, (sum, column) {
      return column.fixedWidth == null ? sum + column.flex : sum;
    });
    final widths = [
      for (var i = 0; i < schema.columns.length; i++)
        baseWidths[i] +
            (schema.columns[i].fixedWidth == null && flexibleWeight > 0
                ? extraWidth * (schema.columns[i].flex / flexibleWeight)
                : 0.0),
    ];
    // Store the split widths because fixed and scrollable panes are rendered by
    // different widgets but must agree on the same column measurements.
    final split = schema.fixedLeftColumns.clamp(0, schema.columns.length);
    return _ResolvedColumnWidths(
      leftWidths: widths.take(split).toList(growable: false),
      rightWidths: widths.skip(split).toList(growable: false),
    );
  }

  double _flexBase(IflTableColumn<RowT, SummaryT> column) {
    final ratio = switch (column.size) {
      IflTableColumnSize.small => schema.smallColumnRatio,
      IflTableColumnSize.medium => 1.0,
      IflTableColumnSize.large => schema.largeColumnRatio,
    };
    return schema.minColumnWidth * column.flex * ratio;
  }
}

class _ResolvedColumnWidths {
  const _ResolvedColumnWidths({
    required this.leftWidths,
    required this.rightWidths,
  });

  final List<double> leftWidths;
  final List<double> rightWidths;

  double get leftWidth => leftWidths.fold(0, (sum, width) => sum + width);

  double get rightWidth => rightWidths.fold(0, (sum, width) => sum + width);
}

class _ResolvedIflTableTheme {
  const _ResolvedIflTableTheme({
    required this.headerBackgroundColor,
    required this.bodyBackgroundColor,
    required this.summaryBackgroundColor,
    required this.borderColor,
    required this.textStyle,
    required this.headerTextStyle,
    required this.summaryTextStyle,
    required this.fixedColumnShadowColor,
    required this.outerBorder,
    required this.verticalDividers,
    required this.horizontalDividers,
    required this.dividerThickness,
  });

  final Color headerBackgroundColor;
  final Color bodyBackgroundColor;
  final Color summaryBackgroundColor;
  final Color borderColor;
  final TextStyle textStyle;
  final TextStyle headerTextStyle;
  final TextStyle summaryTextStyle;
  final Color fixedColumnShadowColor;
  final bool outerBorder;
  final bool verticalDividers;
  final bool horizontalDividers;
  final double dividerThickness;
}

_ResolvedIflTableTheme _materialTheme(
  BuildContext context,
  IflTableThemeData data,
) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;
  final textTheme = theme.textTheme;
  return _ResolvedIflTableTheme(
    headerBackgroundColor:
        data.headerBackgroundColor ?? colorScheme.surfaceContainerHighest,
    bodyBackgroundColor: data.bodyBackgroundColor ?? colorScheme.surface,
    summaryBackgroundColor:
        data.summaryBackgroundColor ?? colorScheme.surfaceContainerHigh,
    borderColor: data.borderColor ?? theme.dividerColor,
    textStyle:
        data.textStyle ?? textTheme.bodySmall ?? const TextStyle(fontSize: 12),
    headerTextStyle:
        data.headerTextStyle ??
        textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600) ??
        const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    summaryTextStyle:
        data.summaryTextStyle ??
        textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600) ??
        const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    fixedColumnShadowColor: data.fixedColumnShadowColor ?? Colors.black,
    outerBorder: data.outerBorder,
    verticalDividers: data.verticalDividers,
    horizontalDividers: data.horizontalDividers,
    dividerThickness: data.dividerThickness,
  );
}
