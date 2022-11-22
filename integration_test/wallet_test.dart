import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:ten_ten_one/balance.dart';
import 'package:ten_ten_one/wallet/wallet_lightning.dart';
import 'package:ten_ten_one/models/amount.model.dart';
import 'package:ten_ten_one/models/balance_model.dart';
import 'package:ten_ten_one/models/seed_backup_model.dart';
import 'package:ten_ten_one/wallet/seed.dart';

final GoRouter _router = GoRouter(
  routes: <GoRoute>[
    GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) {
          return const WalletLightning();
        },
        routes: [
          GoRoute(
            path: Seed.subRouteName,
            builder: (BuildContext context, GoRouterState state) {
              return const Seed();
            },
          ),
        ]),
  ],
);

Widget createWallet(balanceModel, seedBackupModel) => MultiProvider(
        providers: [
          ChangeNotifierProvider<LightningBalance>(create: (context) => balanceModel),
          ChangeNotifierProvider<SeedBackupModel>(create: (context) => seedBackupModel)
        ],
        child: MaterialApp.router(
          routerConfig: _router,
        ));

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Wallet widget tests', () {
    testWidgets('test if balance is rendered', (tester) async {
      await tester.pumpWidget(createWallet(LightningBalance(), SeedBackupModel()));

      expect(find.byType(Balance), findsOneWidget);
    });

    testWidgets('test if Bitcoin balance gets updated', (tester) async {
      final balanceModel = LightningBalance();
      await tester.pumpWidget(createWallet(balanceModel, SeedBackupModel()));

      Text balance = find.byKey(const Key('bitcoinBalance')).evaluate().first.widget as Text;
      // balance is empty on start
      expect(balance.data, '0');
      balanceModel.update(Amount(1001));
      await tester.pumpAndSettle();

      balance = find.byKey(const Key('bitcoinBalance')).evaluate().first.widget as Text;
      expect(balance.data, '1,001');
    });
  });
}
