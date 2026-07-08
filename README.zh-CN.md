# ifl_table

一个用于 Flutter 业务表格场景的表格组件包。

`ifl_table` 重点解决真实业务页面里的表格交互：顶部表头固定、左侧列可固定、内容区支持上下左右滑动、单元格既可以是纯文本也可以是自定义 Widget，并且分页表格支持下拉刷新和上滑加载更多。

> English documentation: [README.md](README.md)

## 功能特性

- 顶部表头固定。
- 支持配置左侧固定列，右侧列可横向滑动。
- 内容区支持纵向滑动。
- 宽表格内容区支持横向滑动。
- 支持可选汇总行。
- 汇总行智能定位：内容不足一屏时跟随内容展示；内容超过一屏时固定在底部展示。
- 通过 `IflTableColumn.text` 快速创建纯文本单元格。
- 通过 `IflTableColumn` 创建自定义 Widget 单元格。
- 支持列宽策略：
  - `fixedWidth`：固定宽度。
  - `minWidth`：最小宽度。
  - `flex`：按比例分配剩余宽度。
- 通过 `IflPagedTable` 支持下拉刷新和加载更多。
- 加载更多 footer 在表格内部占据真实空间，展示在最后一行下方。
- 支持通过 `IflTableThemeData` 或 `IflTableTheme` 自定义表格样式。

## 安装

在 `pubspec.yaml` 中添加依赖：

```yaml
dependencies:
  ifl_table: ^0.0.1
```

然后导入公开 API：

```dart
import 'package:ifl_table/ifl_table.dart';
```

## 基础用法

当数据已经在本地准备好时，可以直接使用 `IflTable`。

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

## 自定义 Widget 单元格

当表格单元格不只是文本，而是徽标、按钮、进度条等 Widget 时，使用默认的 `IflTableColumn` 构造函数。

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

## 分页表格

需要下拉刷新或加载更多时，使用 `IflPagedTable`。加载更多 footer 会展示在表格内容区内部，并在最后一行下方占据独立空间。

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

## 布局行为

表格会被拆成左侧固定区域和右侧横向滚动区域。这样可以让左侧关键列始终可见，同时右侧宽内容可以横向滑动。

表头始终显示在内容区上方，不参与纵向滚动。内容区负责上下滑动，右侧内容区同时负责横向滑动。

当传入 `summary` 且 `showSummary` 为 true 时，汇总行会根据内容高度自动选择展示方式：

- 如果数据行加汇总行可以放进内容区，汇总行会跟在最后一行后面。
- 如果数据行超过内容区，汇总行会固定在表格底部。

## 宽度策略

每一列都可以使用下面几种宽度策略：

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

`fixedWidth` 表示精确固定宽度，不参与剩余空间分配。柔性列会先满足 `minWidth`，然后按照 `flex` 比例分配剩余宽度。

旧的 `width` 参数仍然保留，作为 `fixedWidth` 的兼容别名。

## 主题

可以直接给单个表格传入 `IflTableThemeData`：

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

也可以通过 `IflTableTheme` 给多个表格统一设置样式：

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

## 示例 App

示例 App 包含：

- `normal`：无分页模式。
- `pagedTable`：支持下拉刷新和加载更多。
- `Text cells`：纯文本单元格示例。
- `Widget cells`：Widget 单元格示例，包括徽标、进度条和操作按钮。

运行示例：

```sh
cd example
flutter run
```
