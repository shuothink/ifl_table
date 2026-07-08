import 'package:flutter_test/flutter_test.dart';
import 'package:ifl_table_example/main.dart';

void main() {
  testWidgets('example renders table demo', (tester) async {
    await tester.pumpWidget(const TableExampleApp());

    expect(find.text('IFL Table'), findsOneWidget);
    expect(find.text('Text cells'), findsOneWidget);
    expect(find.text('normal'), findsOneWidget);
    expect(find.text('Name'), findsOneWidget);
  });
}
