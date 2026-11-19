import 'package:flutter_test/flutter_test.dart';
import 'package:gym_app/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const GymApp());
    expect(find.byType(GymApp), findsOneWidget);
  });
}
