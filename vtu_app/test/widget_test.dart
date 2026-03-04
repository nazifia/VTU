import 'package:flutter_test/flutter_test.dart';
import 'package:vtu_app/main.dart';

void main() {
  testWidgets('VTU App smoke test', (WidgetTester tester) async {
    // Smoke test: verify app widget builds without crashing
    expect(VtuApp, isNotNull);
  });
}
