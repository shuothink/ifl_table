import 'package:flutter/material.dart';
import 'package:ifl_table/ifl_table.dart';

void main() {
  runApp(const TableExampleApp());
}

class TableExampleApp extends StatelessWidget {
  const TableExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        useMaterial3: true,
      ),
      home: const TableExamplePage(),
    );
  }
}

class TableExamplePage extends StatefulWidget {
  const TableExamplePage({super.key});

  @override
  State<TableExamplePage> createState() => _TableExamplePageState();
}

class _TableExamplePageState extends State<TableExamplePage> {
  var _cellDemo = _CellDemo.text;
  var _tableMode = _TableMode.normal;
  var _pagedRows = _sampleRows.take(_initialPageSize).toList();

  Future<void> _refresh() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    setState(() {
      _pagedRows = _sampleRows.take(_initialPageSize).toList();
    });
  }

  Future<void> _loadMore() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    setState(() {
      final next = (_pagedRows.length + 4).clamp(0, _sampleRows.length);
      _pagedRows = _sampleRows.take(next).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final rows = _tableMode == _TableMode.normal ? _sampleRows : _pagedRows;
    return Scaffold(
      appBar: AppBar(title: const Text('IFL Table')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<_TableMode>(
              segments: const [
                ButtonSegment(value: _TableMode.normal, label: Text('normal')),
                ButtonSegment(
                  value: _TableMode.pagedTable,
                  label: Text('pagedTable'),
                ),
              ],
              selected: {_tableMode},
              onSelectionChanged: (value) {
                setState(() {
                  _tableMode = value.single;
                  _pagedRows = _sampleRows.take(_initialPageSize).toList();
                });
              },
            ),
            const SizedBox(height: 12),
            SegmentedButton<_CellDemo>(
              segments: const [
                ButtonSegment(value: _CellDemo.text, label: Text('Text cells')),
                ButtonSegment(
                  value: _CellDemo.widget,
                  label: Text('Widget cells'),
                ),
              ],
              selected: {_cellDemo},
              onSelectionChanged: (value) {
                setState(() {
                  _cellDemo = value.single;
                });
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final tableHeight = _preferredTableHeight(
                    rows: rows,
                    maxHeight: constraints.maxHeight,
                  );
                  return Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      height: tableHeight,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                        child: _buildTable(rows),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _preferredTableHeight({
    required List<SampleRow> rows,
    required double maxHeight,
  }) {
    final schema = _activeSchema;
    final rowHeight = schema.rowHeight;
    final headingHeight = schema.headingRowHeight ?? rowHeight;
    final summaryHeight = _cellDemo == _CellDemo.text
        ? (schema.summaryRowHeight ?? rowHeight)
        : 0.0;
    final footerHeight =
        _tableMode == _TableMode.pagedTable && rows.length < _sampleRows.length
        ? 36.0
        : 0.0;
    final contentHeight =
        headingHeight + rows.length * rowHeight + summaryHeight + footerHeight;
    return contentHeight.clamp(0.0, maxHeight);
  }

  Widget _buildTable(List<SampleRow> rows) {
    if (_tableMode == _TableMode.pagedTable) {
      return IflPagedTable<SampleRow, SampleSummary>(
        schema: _activeSchema,
        rows: rows,
        summary: _cellDemo == _CellDemo.text ? _summary : null,
        hasMore: _pagedRows.length < _sampleRows.length,
        onRefresh: _refresh,
        onLoadMore: _loadMore,
        showSummary: _cellDemo == _CellDemo.text,
        rowKeyBuilder: (row) => row.id,
        emptyBuilder: (context) => const Center(child: Text('No rows')),
        theme: _tableTheme,
      );
    }

    return IflTable<SampleRow, SampleSummary>(
      schema: _activeSchema,
      rows: rows,
      summary: _cellDemo == _CellDemo.text ? _summary : null,
      showSummary: _cellDemo == _CellDemo.text,
      rowKeyBuilder: (row) => row.id,
      emptyBuilder: (context) => const Center(child: Text('No rows')),
      theme: _tableTheme,
    );
  }

  IflTableSchema<SampleRow, SampleSummary> get _activeSchema {
    return _cellDemo == _CellDemo.text ? _textSchema : _widgetSchema;
  }
}

enum _CellDemo { text, widget }

enum _TableMode { normal, pagedTable }

const _tableTheme = IflTableThemeData(headerBackgroundColor: Color(0xFFF3F4F6));

const _initialPageSize = 14;

final IflTableSchema<SampleRow, SampleSummary> _textSchema =
    IflTableSchema<SampleRow, SampleSummary>(
      rowHeight: 40,
      fixedLeftColumns: 1,
      columns: [
        IflTableColumn<SampleRow, SampleSummary>.text(
          id: 'name',
          title: 'Name',
          width: 128,
          alignment: Alignment.centerLeft,
          valueBuilder: (row) => row.name,
          summaryValueBuilder: (_) => 'Total',
        ),
        IflTableColumn<SampleRow, SampleSummary>.text(
          id: 'category',
          title: 'Category',
          minWidth: 120,
          alignment: Alignment.centerLeft,
          valueBuilder: (row) => row.category,
          summaryValueBuilder: (summary) => summary.category,
        ),
        IflTableColumn<SampleRow, SampleSummary>.text(
          id: 'status',
          title: 'Status',
          minWidth: 112,
          alignment: Alignment.centerLeft,
          valueBuilder: (row) => row.status,
          summaryValueBuilder: (summary) => summary.status,
        ),
        IflTableColumn<SampleRow, SampleSummary>.text(
          id: 'tag',
          title: 'Tag',
          minWidth: 104,
          alignment: Alignment.centerLeft,
          valueBuilder: (row) => row.tag,
          summaryValueBuilder: (summary) => summary.tag,
        ),
        IflTableColumn<SampleRow, SampleSummary>.text(
          id: 'note',
          title: 'Note',
          minWidth: 144,
          flex: 1.4,
          alignment: Alignment.centerLeft,
          valueBuilder: (row) => row.note,
          summaryValueBuilder: (summary) => summary.note,
        ),
      ],
    );

final IflTableSchema<SampleRow, SampleSummary> _widgetSchema =
    IflTableSchema<SampleRow, SampleSummary>(
      rowHeight: 40,
      fixedLeftColumns: 1,
      columns: [
        IflTableColumn<SampleRow, SampleSummary>.text(
          id: 'name',
          title: 'Name',
          width: 128,
          alignment: Alignment.centerLeft,
          valueBuilder: (row) => row.name,
          summaryValueBuilder: (_) => 'Total',
        ),
        IflTableColumn<SampleRow, SampleSummary>.text(
          id: 'category',
          title: 'Category',
          minWidth: 120,
          alignment: Alignment.centerLeft,
          valueBuilder: (row) => row.category,
          summaryValueBuilder: (summary) => summary.category,
        ),
        IflTableColumn<SampleRow, SampleSummary>(
          id: 'tag',
          label: const Text('Tag'),
          minWidth: 104,
          cellBuilder: (context, row) => _TagBadge(text: row.tag),
          summaryBuilder: (context, summary) => Text(summary.tag),
        ),
        IflTableColumn<SampleRow, SampleSummary>(
          id: 'progress',
          label: const Text('Progress'),
          minWidth: 128,
          cellBuilder: (context, row) => _ProgressCell(value: row.progress),
          summaryBuilder: (context, summary) => Text(summary.progress),
        ),
        IflTableColumn<SampleRow, SampleSummary>(
          id: 'action',
          label: const Text('Action'),
          fixedWidth: 96,
          cellBuilder: (context, row) {
            return TextButton(
              onPressed: () {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Selected ${row.name}')));
              },
              child: const Text('Select'),
            );
          },
          summaryBuilder: (context, summary) => const SizedBox.shrink(),
        ),
      ],
    );

class _TagBadge extends StatelessWidget {
  const _TagBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final color = switch (text) {
      'New' => Colors.blue,
      'Ready' => Colors.green,
      _ => Colors.orange,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          text,
          style: TextStyle(
            color: color.shade700,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ProgressCell extends StatelessWidget {
  const _ProgressCell({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: LinearProgressIndicator(
            value: value,
            minHeight: 6,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 8),
        Text('${(value * 100).round()}%'),
      ],
    );
  }
}

class SampleRow {
  const SampleRow({
    required this.id,
    required this.name,
    required this.category,
    required this.status,
    required this.tag,
    required this.note,
    required this.progress,
  });

  final String id;
  final String name;
  final String category;
  final String status;
  final String tag;
  final String note;
  final double progress;
}

class SampleSummary {
  const SampleSummary({
    required this.category,
    required this.status,
    required this.tag,
    required this.note,
    required this.progress,
  });

  final String category;
  final String status;
  final String tag;
  final String note;
  final String progress;
}

const _summary = SampleSummary(
  category: '60 rows',
  status: '3 states',
  tag: 'Mixed',
  note: 'Text only',
  progress: 'Average',
);

final _sampleRows = List.generate(60, (index) {
  return SampleRow(
    id: 'row-$index',
    name: 'Item ${index + 1}',
    category: ['Alpha', 'Beta', 'Gamma', 'Delta'][index % 4],
    status: ['Draft', 'Review', 'Done'][index % 3],
    tag: ['New', 'Ready', 'Hold'][index % 3],
    note: [
      'Plain text',
      'Short value',
      'Sample row',
      'Static content',
    ][index % 4],
    progress: ((index % 10) + 1) / 10,
  );
});
