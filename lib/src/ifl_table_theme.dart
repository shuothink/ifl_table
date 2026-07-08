import 'package:flutter/material.dart';

/// Visual overrides for IFL table widgets.
///
/// All properties are optional except the feature toggles. Null values are
/// resolved from the ambient Material [ThemeData] at build time, which keeps the
/// table aligned with the app theme by default.
@immutable
class IflTableThemeData {
  /// Creates table theme overrides.
  const IflTableThemeData({
    this.headerBackgroundColor,
    this.bodyBackgroundColor,
    this.summaryBackgroundColor,
    this.borderColor,
    this.textStyle,
    this.headerTextStyle,
    this.summaryTextStyle,
    this.fixedColumnShadowColor,
    this.outerBorder = true,
    this.verticalDividers = true,
    this.horizontalDividers = true,
    this.leftShadow = true,
    this.dividerThickness = 0.5,
  });

  /// Background color for the heading row.
  final Color? headerBackgroundColor;

  /// Background color for body cells and footer placeholders.
  final Color? bodyBackgroundColor;

  /// Background color for the summary row.
  final Color? summaryBackgroundColor;

  /// Color used by outer borders and cell dividers.
  final Color? borderColor;

  /// Default text style for body cells.
  final TextStyle? textStyle;

  /// Default text style for heading cells.
  final TextStyle? headerTextStyle;

  /// Default text style for summary cells.
  final TextStyle? summaryTextStyle;

  /// Color used by the fixed-left-column shadow.
  final Color? fixedColumnShadowColor;

  /// Whether to draw the table's outer border.
  final bool outerBorder;

  /// Whether to draw vertical dividers between columns.
  final bool verticalDividers;

  /// Whether to draw horizontal dividers between rows.
  final bool horizontalDividers;

  /// Whether to show a shadow when fixed columns cover horizontally scrolled
  /// content.
  final bool leftShadow;

  /// Stroke width used for borders and dividers.
  final double dividerThickness;

  /// Returns a copy with the provided overrides applied.
  IflTableThemeData copyWith({
    Color? headerBackgroundColor,
    Color? bodyBackgroundColor,
    Color? summaryBackgroundColor,
    Color? borderColor,
    TextStyle? textStyle,
    TextStyle? headerTextStyle,
    TextStyle? summaryTextStyle,
    Color? fixedColumnShadowColor,
    bool? outerBorder,
    bool? verticalDividers,
    bool? horizontalDividers,
    bool? leftShadow,
    double? dividerThickness,
  }) {
    return IflTableThemeData(
      headerBackgroundColor:
          headerBackgroundColor ?? this.headerBackgroundColor,
      bodyBackgroundColor: bodyBackgroundColor ?? this.bodyBackgroundColor,
      summaryBackgroundColor:
          summaryBackgroundColor ?? this.summaryBackgroundColor,
      borderColor: borderColor ?? this.borderColor,
      textStyle: textStyle ?? this.textStyle,
      headerTextStyle: headerTextStyle ?? this.headerTextStyle,
      summaryTextStyle: summaryTextStyle ?? this.summaryTextStyle,
      fixedColumnShadowColor:
          fixedColumnShadowColor ?? this.fixedColumnShadowColor,
      outerBorder: outerBorder ?? this.outerBorder,
      verticalDividers: verticalDividers ?? this.verticalDividers,
      horizontalDividers: horizontalDividers ?? this.horizontalDividers,
      leftShadow: leftShadow ?? this.leftShadow,
      dividerThickness: dividerThickness ?? this.dividerThickness,
    );
  }
}

/// Inherited theme for IFL tables.
///
/// Place this above one or more [IflTable] or [IflPagedTable] widgets to share
/// table styling without passing a theme to every table instance.
class IflTableTheme extends InheritedWidget {
  /// Creates a scoped table theme.
  const IflTableTheme({super.key, required this.data, required super.child});

  /// Theme data made available to descendant tables.
  final IflTableThemeData data;

  /// Reads the nearest scoped table theme.
  ///
  /// Returns a default [IflTableThemeData] when no inherited table theme exists.
  static IflTableThemeData of(BuildContext context) {
    final theme = context.dependOnInheritedWidgetOfExactType<IflTableTheme>();
    return theme?.data ?? const IflTableThemeData();
  }

  @override
  bool updateShouldNotify(IflTableTheme oldWidget) => data != oldWidget.data;
}
