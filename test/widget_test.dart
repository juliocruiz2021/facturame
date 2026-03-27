import 'package:flutter_test/flutter_test.dart';
import 'package:app_clientes/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const AppClientes());
    expect(find.byType(AppClientes), findsOneWidget);
  });
}
