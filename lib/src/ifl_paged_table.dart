import 'package:flutter/material.dart';

import 'ifl_table.dart';
import 'ifl_table_schema.dart';
import 'ifl_table_theme.dart';

/// A table wrapper with pull-to-refresh and load-more behavior.
///
/// [IflPagedTable] keeps the base table API but adds two paging hooks:
/// [onRefresh] for pull-down refresh and [onLoadMore] for near-bottom loading.
/// The load-more indicator is rendered as an in-table footer row so it occupies
/// real scroll space below the last data row.
class IflPagedTable<RowT, SummaryT> extends StatefulWidget {
  /// Creates a paged table.
  const IflPagedTable({
    super.key,
    required this.schema,
    required this.rows,
    this.summary,
    this.hasMore = false,
    this.onRefresh,
    this.onLoadMore,
    this.showSummary = true,
    this.emptyBuilder,
    this.loadingMoreBuilder,
    this.rowKeyBuilder,
    this.theme,
    this.verticalController,
    this.horizontalController,
  });

  /// Column and layout definition shared with [IflTable].
  final IflTableSchema<RowT, SummaryT> schema;

  /// Rows currently available to render.
  final List<RowT> rows;

  /// Optional aggregate object rendered by summary builders.
  final SummaryT? summary;

  /// Whether another page can be loaded.
  final bool hasMore;

  /// Called by [RefreshIndicator] when the user pulls down.
  final Future<void> Function()? onRefresh;

  /// Called once when the vertical scroll position reaches the load threshold.
  final Future<void> Function()? onLoadMore;

  /// Whether to render [summary] when it is non-null.
  final bool showSummary;

  /// Builder used when [rows] is empty.
  final WidgetBuilder? emptyBuilder;

  /// Custom builder for the load-more footer.
  final WidgetBuilder? loadingMoreBuilder;

  /// Optional stable key source for preserving row state during updates.
  final Object? Function(RowT row)? rowKeyBuilder;

  /// Per-table theme overrides.
  final IflTableThemeData? theme;

  /// Optional external vertical controller.
  ///
  /// When omitted, the paged table owns and disposes an internal controller.
  final ScrollController? verticalController;

  /// Optional external horizontal controller for the scrollable columns.
  final ScrollController? horizontalController;

  @override
  State<IflPagedTable<RowT, SummaryT>> createState() =>
      _IflPagedTableState<RowT, SummaryT>();
}

class _IflPagedTableState<RowT, SummaryT>
    extends State<IflPagedTable<RowT, SummaryT>> {
  late final ScrollController _verticalController;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    // Reuse an external controller when supplied so parent widgets can inspect
    // or drive the table scroll position.
    _verticalController = widget.verticalController ?? ScrollController();
  }

  @override
  void dispose() {
    if (widget.verticalController == null) {
      _verticalController.dispose();
    }
    super.dispose();
  }

  Future<void> _handleLoadMore() async {
    if (_loadingMore || !widget.hasMore || widget.onLoadMore == null) {
      return;
    }
    setState(() {
      _loadingMore = true;
    });
    // The footer is inserted after this setState. Scrolling on the next frame
    // reveals that reserved footer space instead of leaving it under the last
    // data row.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_verticalController.hasClients) {
        return;
      }
      _verticalController.animateTo(
        _verticalController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
    try {
      await widget.onLoadMore!();
    } finally {
      if (mounted) {
        setState(() {
          _loadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final table = IflTable<RowT, SummaryT>(
      schema: widget.schema,
      rows: widget.rows,
      summary: widget.summary,
      showSummary: widget.showSummary,
      emptyBuilder: widget.emptyBuilder,
      rowKeyBuilder: widget.rowKeyBuilder,
      theme: widget.theme,
      verticalController: _verticalController,
      horizontalController: widget.horizontalController,
      onEndReached: widget.hasMore ? _handleLoadMore : null,
      footerBuilder: _loadingMore
          ? (widget.loadingMoreBuilder ?? _defaultLoadingMoreBuilder)
          : null,
    );

    final child = table;

    if (widget.onRefresh == null) {
      return child;
    }

    return RefreshIndicator(
      notificationPredicate: (notification) {
        // Horizontal table scrolling also emits notifications; the refresh
        // indicator should only react to the vertical body scroll.
        return notification.metrics.axis == Axis.vertical;
      },
      onRefresh: widget.onRefresh!,
      child: child,
    );
  }

  Widget _defaultLoadingMoreBuilder(BuildContext context) {
    final color = Theme.of(context).textTheme.bodySmall?.color;
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.96),
        ),
        child: SizedBox(
          height: 36,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox.square(
                    dimension: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Loading...',
                    style: TextStyle(
                      color: color?.withValues(alpha: 0.72),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
