import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:provider/provider.dart';
import 'package:ten_ten_one/balance.dart';
import 'package:ten_ten_one/dashboard.dart';
import 'package:ten_ten_one/models/balance.model.dart';

Widget createDashboard(balanceModel) => ChangeNotifierProvider<BalanceModel>(
    create: (context) => balanceModel, child: const MaterialApp(home: Dashboard()));

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Dashboard widget tests', () {
    testWidgets('test if balance is rendered', (tester) async {
      await tester.pumpWidget(createDashboard(BalanceModel()));

      expect(find.byType(Balance), findsOneWidget);
    });

    testWidgets('test if balance gets updated', (tester) async {
      final balanceModel = BalanceModel();
      await tester.pumpWidget(createDashboard(balanceModel));

      Text balance = find.byKey(const Key('balance')).evaluate().first.widget as Text;
      // balance is empty on start
      expect(balance.data, '0');
      balanceModel.update(1001);
      await tester.pumpAndSettle();

      balance = find.byKey(const Key('balance')).evaluate().first.widget as Text;
      expect(balance.data, '1,001');
    });
  });
}
