import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:ten_ten_one/balance.dart';
import 'package:ten_ten_one/bridge_generated/bridge_definitions.dart' as bridge;
import 'package:ten_ten_one/wallet/wallet_change_notifier.dart';
import 'package:ten_ten_one/wallet/wallet_lightning.dart';
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
          ChangeNotifierProvider<WalletChangeNotifier>(create: (context) => balanceModel),
          ChangeNotifierProvider<SeedBackupModel>(create: (context) => seedBackupModel)
        ],
        child: MaterialApp.router(
          routerConfig: _router,
        ));

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Wallet widget tests', () {
    testWidgets('test if balance is rendered', (tester) async {
      await tester.pumpWidget(createWallet(WalletChangeNotifier(), SeedBackupModel()));

      expect(find.byType(Balance), findsOneWidget);
    });

    testWidgets('test if Bitcoin balance gets updated', (tester) async {
      final balanceModel = WalletChangeNotifier();
      await tester.pumpWidget(createWallet(balanceModel, SeedBackupModel()));

      Text balance = find.byKey(const Key('bitcoinBalance')).evaluate().first.widget as Text;
      // balance is empty on start
      expect(balance.data, '0');
      balanceModel.update(bridge.WalletInfo(
          balance: bridge.Balance(
              onChain: bridge.OnChain(trustedPending: 0, untrustedPending: 0, confirmed: 1001),
              offChain: bridge.OffChain(available: 0, pendingClose: 0)),
          bitcoinHistory: List.empty(),
          lightningHistory: List.empty()));
      await tester.pumpAndSettle();

      balance = find.byKey(const Key('bitcoinBalance')).evaluate().first.widget as Text;
      expect(balance.data, '1,001');
    });
  });
}
