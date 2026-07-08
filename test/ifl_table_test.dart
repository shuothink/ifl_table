import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ifl_table/ifl_table.dart';

void main() {
  testWidgets('renders text cells, widget cells, and summary cells', (
    tester,
  ) async {
    final schema = IflTableSchema<_Row, _Summary>(
      rowHeight: 40,
      columns: [
        IflTableColumn<_Row, _Summary>.text(
          id: 'name',
          title: 'Name',
          width: 120,
          valueBuilder: (row) => row.name,
          summaryValueBuilder: (summary) => summary.label,
        ),
        IflTableColumn<_Row, _Summary>(
          id: 'status',
          label: const Text('Status'),
          minWidth: 100,
          cellBuilder: (context, row) {
            return Chip(label: Text(row.status));
          },
          summaryBuilder: (context, summary) => Text('${summary.count} rows'),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 220,
            child: IflTable<_Row, _Summary>(
              schema: schema,
              rows: const [
                _Row(name: 'Alpha', status: 'Done'),
                _Row(name: 'Beta', status: 'Pending'),
              ],
              summary: const _Summary(label: 'Total', count: 2),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Status'), findsOneWidget);
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
    expect(find.text('2 rows'), findsOneWidget);
  });

  testWidgets('renders empty state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 240,
            height: 160,
            child: IflTable<_Row, Object>(
              schema: IflTableSchema<_Row, Object>(
                columns: [
                  IflTableColumn.text(
                    id: 'name',
                    title: 'Name',
                    valueBuilder: (row) => row.name,
                  ),
                ],
              ),
              rows: const [],
              emptyBuilder: (_) => const Center(child: Text('暂无数据')),
            ),
          ),
        ),
      ),
    );

    expect(find.text('暂无数据'), findsOneWidget);
  });

  testWidgets('keeps summary row after content when content is short', (
    tester,
  ) async {
    final schema = IflTableSchema<_Row, _Summary>(
      rowHeight: 40,
      columns: [
        IflTableColumn<_Row, _Summary>.text(
          id: 'name',
          title: 'Name',
          valueBuilder: (row) => row.name,
          summaryValueBuilder: (summary) => summary.label,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 240,
            height: 240,
            child: IflTable<_Row, _Summary>(
              schema: schema,
              rows: const [_Row(name: 'Alpha', status: 'Done')],
              summary: const _Summary(label: 'Total', count: 1),
            ),
          ),
        ),
      ),
    );

    final alphaTop = tester.getTopLeft(find.text('Alpha')).dy;
    final totalTop = tester.getTopLeft(find.text('Total')).dy;

    expect(totalTop, greaterThan(alphaTop));
    expect(totalTop - alphaTop, lessThan(60));
  });

  testWidgets('paged table supports pull to refresh when content is short', (
    tester,
  ) async {
    var refreshed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 240,
            height: 240,
            child: IflPagedTable<_Row, Object>(
              schema: _singleColumnSchema,
              rows: const [_Row(name: 'Alpha', status: 'Done')],
              onRefresh: () async {
                refreshed = true;
              },
            ),
          ),
        ),
      ),
    );

    await tester.drag(find.text('Alpha'), const Offset(0, 300));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(refreshed, isTrue);
  });

  testWidgets('paged table triggers load more near the bottom', (tester) async {
    var loadMoreCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 260,
            height: 180,
            child: IflPagedTable<_Row, Object>(
              schema: _twoColumnSchema,
              rows: List.generate(
                12,
                (index) => _Row(name: 'Row $index', status: 'Done'),
              ),
              hasMore: true,
              onLoadMore: () async {
                loadMoreCount++;
              },
            ),
          ),
        ),
      ),
    );

    await tester.drag(find.text('Row 0'), const Offset(0, -500));
    await tester.pump();

    expect(loadMoreCount, 1);
  });

  testWidgets('paged table renders load more footer inside the table', (
    tester,
  ) async {
    final completer = Completer<void>();
    final controller = ScrollController();
    var loadStarted = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 260,
            height: 180,
            child: IflPagedTable<_Row, Object>(
              schema: _twoColumnSchema,
              rows: List.generate(
                12,
                (index) => _Row(name: 'Row $index', status: 'Done'),
              ),
              hasMore: true,
              verticalController: controller,
              onLoadMore: () {
                loadStarted = true;
                return completer.future;
              },
            ),
          ),
        ),
      ),
    );

    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();

    expect(loadStarted, isTrue);
    expect(find.text('Loading...'), findsOneWidget);

    completer.complete();
    await tester.pump();
  });

  testWidgets('normal table keeps bottom border on the last data row', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 260,
            height: 140,
            child: IflTable<_Row, Object>(
              schema: _singleColumnSchema,
              rows: const [_Row(name: 'Alpha', status: 'Done')],
            ),
          ),
        ),
      ),
    );

    final rowCell = tester.widget<Container>(
      find
          .ancestor(of: find.text('Alpha'), matching: find.byType(Container))
          .first,
    );
    final decoration = rowCell.decoration as BoxDecoration;
    final border = decoration.border as Border;

    expect(border.bottom, isNot(BorderSide.none));
  });
}

final _singleColumnSchema = IflTableSchema<_Row, Object>(
  rowHeight: 40,
  columns: [
    IflTableColumn<_Row, Object>.text(
      id: 'name',
      title: 'Name',
      valueBuilder: (row) => row.name,
    ),
  ],
);

final _twoColumnSchema = IflTableSchema<_Row, Object>(
  rowHeight: 40,
  columns: [
    IflTableColumn<_Row, Object>.text(
      id: 'name',
      title: 'Name',
      width: 120,
      valueBuilder: (row) => row.name,
    ),
    IflTableColumn<_Row, Object>.text(
      id: 'status',
      title: 'Status',
      minWidth: 120,
      valueBuilder: (row) => row.status,
    ),
  ],
);

class _Row {
  const _Row({required this.name, required this.status});

  final String name;
  final String status;
}

class _Summary {
  const _Summary({required this.label, required this.count});

  final String label;
  final int count;
}
