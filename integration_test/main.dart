// ignore_for_file: avoid_print

import 'package:ten_ten_one/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  print('integration_test/main.dart starts!');

  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('end-to-end test', () {
    testWidgets('test if the app loads the dashboard', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();
      expect(find.textContaining('Create Wallet Backup'), findsOneWidget);
    });
  });
}
