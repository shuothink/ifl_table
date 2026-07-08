import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ifl_table/ifl_table.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders an IFL table', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IflTable<Map<String, String>, Object>(
            schema: IflTableSchema<Map<String, String>, Object>(
              columns: [
                IflTableColumn<Map<String, String>, Object>.text(
                  id: 'name',
                  title: 'Name',
                  valueBuilder: (row) => row['name'] ?? '',
                ),
              ],
            ),
            rows: const [
              {'name': 'Alpha'},
            ],
          ),
        ),
      ),
    );

    expect(find.text('Alpha'), findsOneWidget);
  });
}
