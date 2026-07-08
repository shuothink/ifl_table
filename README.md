# ifl_table

A Flutter table package for business-style data grids.

`ifl_table` focuses on predictable table behavior in real product screens:
the header stays fixed, one or more left columns can stay fixed, the body can
scroll vertically and horizontally, rows can render plain text or custom
widgets, and paged tables can support pull-to-refresh plus load-more.

> Chinese documentation: [README.zh-CN.md](README.zh-CN.md)

## Features

- Fixed header row at the top of the table.
- Configurable fixed-left columns with horizontally scrollable right columns.
- Vertically scrollable table body.
- Horizontally scrollable content area for wide tables.
- Optional summary row.
- Smart summary placement: when the content is short, the summary follows the
  content; when the content is long, the summary stays at the bottom.
- Text cells through `IflTableColumn.text`.
- Custom widget cells through `IflTableColumn`.
- Column width strategies:
  - `fixedWidth` for exact-width columns.
  - `minWidth` for flexible columns with a lower bound.
  - `flex` for distributing remaining width.
- `IflPagedTable` wrapper with pull-to-refresh and load-more support.
- In-table load-more footer that occupies real scroll space below the last row.
- Table-level theme overrides through `IflTableThemeData` or `IflTableTheme`.

## Installation

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  ifl_table: ^0.0.1
```

Then import the public API:

```dart
import 'package:ifl_table/ifl_table.dart';
```

## Basic Usage

Use `IflTable` when all rows are already available locally.

```dart
class UserRow {
  const UserRow({
    required this.name,
    required this.role,
    required this.status,
    required this.note,
  });

  final String name;
  final String role;
  final String status;
  final String note;
}

class UserSummary {
  const UserSummary({required this.total, required this.active});

  final String total;
  final String active;
}

final schema = IflTableSchema<UserRow, UserSummary>(
  fixedLeftColumns: 1,
  rowHeight: 40,
  columns: [
    IflTableColumn<UserRow, UserSummary>.text(
      id: 'name',
      title: 'Name',
      fixedWidth: 140,
      alignment: Alignment.centerLeft,
      valueBuilder: (row) => row.name,
      summaryValueBuilder: (_) => 'Total',
    ),
    IflTableColumn<UserRow, UserSummary>.text(
      id: 'role',
      title: 'Role',
      minWidth: 120,
      alignment: Alignment.centerLeft,
      valueBuilder: (row) => row.role,
      summaryValueBuilder: (summary) => summary.total,
    ),
    IflTableColumn<UserRow, UserSummary>.text(
      id: 'status',
      title: 'Status',
      minWidth: 120,
      valueBuilder: (row) => row.status,
      summaryValueBuilder: (summary) => summary.active,
    ),
    IflTableColumn<UserRow, UserSummary>.text(
      id: 'note',
      title: 'Note',
      minWidth: 180,
      flex: 1.4,
      alignment: Alignment.centerLeft,
      valueBuilder: (row) => row.note,
    ),
  ],
);

IflTable<UserRow, UserSummary>(
  schema: schema,
  rows: rows,
  summary: const UserSummary(total: '24 rows', active: '18 active'),
  rowKeyBuilder: (row) => row.name,
);
```

## Widget Cells

Use the default `IflTableColumn` constructor when a cell needs to render a
widget instead of plain text.

```dart
IflTableColumn<UserRow, UserSummary>(
  id: 'action',
  label: const Text('Action'),
  fixedWidth: 96,
  cellBuilder: (context, row) {
    return TextButton(
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Selected ${row.name}')),
        );
      },
      child: const Text('Select'),
    );
  },
);
```

## Paged Table

Use `IflPagedTable` when the table should support pull-to-refresh or load-more.
The load-more footer is rendered inside the table body, below the last row.

```dart
IflPagedTable<UserRow, UserSummary>(
  schema: schema,
  rows: rows,
  summary: summary,
  hasMore: hasMore,
  onRefresh: () async {
    await reloadFirstPage();
  },
  onLoadMore: () async {
    await loadNextPage();
  },
  rowKeyBuilder: (row) => row.name,
);
```

## Layout Behavior

The table is split into a fixed-left area and a horizontally scrollable area.
This allows the left columns to remain visible while the rest of the columns
move horizontally.

The header is always rendered above the body and does not move during vertical
scrolling. The body handles vertical scrolling. The right side of the body also
handles horizontal scrolling for wide content.

When a summary is provided and `showSummary` is true, the table decides where to
place it:

- If all rows plus the summary fit inside the body viewport, the summary is
  rendered immediately after the last row.
- If the rows overflow the body viewport, the summary is rendered as a fixed
  bottom row.

## Width Strategy

Each column can define its width in one of these ways:

```dart
IflTableColumn.text(
  id: 'fixed',
  title: 'Fixed',
  fixedWidth: 120,
  valueBuilder: (row) => row.note,
);

IflTableColumn.text(
  id: 'minimum',
  title: 'Minimum',
  minWidth: 140,
  valueBuilder: (row) => row.note,
);

IflTableColumn.text(
  id: 'flexible',
  title: 'Flexible',
  minWidth: 120,
  flex: 2,
  valueBuilder: (row) => row.note,
);
```

`fixedWidth` keeps an exact width and does not receive extra space. Flexible
columns start from their `minWidth` and share any remaining width according to
their `flex` values.

The older `width` argument is kept as a backwards-compatible alias for
`fixedWidth`.

## Theming

Pass `IflTableThemeData` directly to one table:

```dart
IflTable<UserRow, UserSummary>(
  schema: schema,
  rows: rows,
  theme: const IflTableThemeData(
    headerBackgroundColor: Color(0xFFF3F4F6),
    dividerThickness: 0.5,
  ),
);
```

Or scope the same style to multiple tables:

```dart
IflTableTheme(
  data: const IflTableThemeData(
    outerBorder: true,
    verticalDividers: true,
    horizontalDividers: true,
  ),
  child: child,
);
```

## Example App

The example app includes:

- `normal` mode without paging.
- `pagedTable` mode with refresh and load-more.
- `Text cells` mode with simple text-only cells.
- `Widget cells` mode with badges, progress, and actions.

Run it with:

```sh
cd example
flutter run
```
