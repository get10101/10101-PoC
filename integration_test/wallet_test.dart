import 'package:flutter/material.dart' hide Balance;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:ten_ten_one/bridge_generated/bridge_definitions.dart';
import 'package:ten_ten_one/wallet/wallet_lightning.dart';
import 'package:ten_ten_one/models/wallet_info_change_notifier.dart';
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

Widget createWallet(walletChangeNotifier, seedBackupModel) => MultiProvider(
        providers: [
          ChangeNotifierProvider<WalletInfoChangeNotifier>(
              create: (context) => walletChangeNotifier),
          ChangeNotifierProvider<SeedBackupModel>(create: (context) => seedBackupModel)
        ],
        child: MaterialApp.router(
          routerConfig: _router,
        ));

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Wallet widget tests', () {
    testWidgets('test if balance is rendered', (tester) async {
      await tester.pumpWidget(createWallet(WalletInfoChangeNotifier(), SeedBackupModel()));

      expect(find.byType(Balance), findsOneWidget);
    });

    testWidgets('test if Bitcoin balance gets updated', (tester) async {
      final walletChangeNotifier = WalletInfoChangeNotifier();
      await tester.pumpWidget(createWallet(walletChangeNotifier, SeedBackupModel()));

      Text balance = find.byKey(const Key('bitcoinBalance')).evaluate().first.widget as Text;
      // balance is empty on start
      expect(balance.data, '0');
      walletChangeNotifier.update(WalletInfo(
          balance: Balance(
              onChain: OnChain(trustedPending: 0, untrustedPending: 0, confirmed: 1001),
              offChain: OffChain(available: 0, pendingClose: 0)),
          bitcoinHistory: List.empty(),
          lightningHistory: List.empty()));
      await tester.pumpAndSettle();

      balance = find.byKey(const Key('bitcoinBalance')).evaluate().first.widget as Text;
      expect(balance.data, '1,001');
    });
  });
}
