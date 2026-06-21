import 'package:flutter_test/flutter_test.dart';
import 'package:beninplay/main.dart';

void main() {
  testWidgets('BeninPlay smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const BeninPlayApp());
    expect(find.byType(BeninPlayApp), findsOneWidget);
  });
}