import 'dart:async';

import 'package:f_logs/f_logs.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';
import 'package:provider/provider.dart';
import 'package:ten_ten_one/bridge_generated/bridge_definitions.dart';
import 'package:ten_ten_one/cfd_trading/cfd_order_confirmation.dart';
import 'package:ten_ten_one/cfd_trading/cfd_order_detail.dart';
import 'package:ten_ten_one/cfd_trading/cfd_trading.dart';
import 'package:ten_ten_one/models/payment.model.dart';
import 'package:ten_ten_one/payment_history_change_notifier.dart';
import 'package:ten_ten_one/wallet/deposit.dart';
import 'package:ten_ten_one/wallet/open_channel.dart';
import 'package:ten_ten_one/wallet/wallet.dart';
import 'package:ten_ten_one/wallet/wallet_change_notifier.dart';
import 'package:ten_ten_one/models/amount.model.dart';
import 'package:ten_ten_one/models/balance_model.dart';
import 'package:ten_ten_one/cfd_trading/cfd_trading_change_notifier.dart';
import 'package:ten_ten_one/models/order.dart';
import 'package:ten_ten_one/models/seed_backup_model.dart';
import 'package:ten_ten_one/wallet/receive.dart';
import 'package:ten_ten_one/wallet/seed.dart';
import 'package:go_router/go_router.dart';
import 'package:ten_ten_one/wallet/send.dart';
import 'package:ten_ten_one/wallet/withdraw.dart';

import 'package:ten_ten_one/ffi.io.dart' if (dart.library.html) 'ffi.web.dart';

LightningBalance lightningBalance = LightningBalance();
BitcoinBalance bitcoinBalance = BitcoinBalance();
SeedBackupModel seedBackup = SeedBackupModel();
PaymentHistory paymentHistory = PaymentHistory();

void main() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };

  final config = FLog.getDefaultConfigurations();
  config.activeLogLevel = foundation.kReleaseMode ? LogLevel.INFO : LogLevel.DEBUG;

  FLog.applyConfigurations(config);

  runApp(MultiProvider(providers: [
    ChangeNotifierProvider(create: (context) => lightningBalance),
    ChangeNotifierProvider(create: (context) => bitcoinBalance),
    ChangeNotifierProvider(create: (context) => seedBackup),
    ChangeNotifierProvider(create: (context) => paymentHistory),
    ChangeNotifierProvider(create: (context) => CfdTradingChangeNotifier()),
    ChangeNotifierProvider(create: (context) => WalletChangeNotifier()),
  ], child: const TenTenOneApp()));
}

class TenTenOneApp extends StatefulWidget {
  const TenTenOneApp({Key? key}) : super(key: key);

  @override
  State<TenTenOneApp> createState() => _TenTenOneState();
}

class _TenTenOneState extends State<TenTenOneApp> {
  @override
  void initState() {
    super.initState();
    setupRustLogging();
    try {
      _callInitWallet();
      FLog.info(text: "Successfully initialised wallet");
    } on FfiException catch (error) {
      FLog.error(text: "Wallet failed to initialise: Error: " + error.message, exception: error);
    } catch (error) {
      FLog.error(text: "Wallet failed to initialise: Unknown error");
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'TenTenOne',
      theme: ThemeData(primarySwatch: Colors.orange),
      routerConfig: _router,
    );
  }

  final GoRouter _router = GoRouter(
    routes: <GoRoute>[
      GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) {
            return const Wallet();
          },
          routes: [
            GoRoute(
              path: Seed.subRouteName,
              builder: (BuildContext context, GoRouterState state) {
                return const Seed();
              },
            ),
            GoRoute(
              path: Send.subRouteName,
              builder: (BuildContext context, GoRouterState state) {
                return const Send();
              },
            ),
            GoRoute(
              path: Receive.subRouteName,
              builder: (BuildContext context, GoRouterState state) {
                return const Receive();
              },
            ),
            GoRoute(
              path: Deposit.subRouteName,
              builder: (BuildContext context, GoRouterState state) {
                return const Deposit();
              },
            ),
            GoRoute(
              path: Withdraw.subRouteName,
              builder: (BuildContext context, GoRouterState state) {
                return const Withdraw();
              },
            ),
            GoRoute(
              path: OpenChannel.subRouteName,
              builder: (BuildContext context, GoRouterState state) {
                return const OpenChannel();
              },
            ),
          ]),
      GoRoute(
          path: CfdTrading.route,
          builder: (BuildContext context, GoRouterState state) {
            return const CfdTrading();
          },
          routes: [
            GoRoute(
              path: CfdOrderConfirmation.subRouteName,
              builder: (BuildContext context, GoRouterState state) {
                return CfdOrderConfirmation(order: state.extra as Order);
              },
            ),
            GoRoute(
              path: CfdOrderDetail.subRouteName,
              builder: (BuildContext context, GoRouterState state) {
                return CfdOrderDetail(order: state.extra as Order);
              },
            ),
          ]),
    ],
  );

  Future<void> _callInitWallet() async {
    final appSupportDir = await getApplicationSupportDirectory();
    await api.initWallet(network: Network.Testnet, path: appSupportDir.path);

    // initial sync
    _callSync();
    _callSyncPaymentHistory();
    // consecutive syncs
    runPeriodically(_callSync);
    runPeriodically(_callSyncPaymentHistory);
  }

  Future<void> _callSync() async {
    try {
      final balance = await api.getBalance();
      bitcoinBalance.update(Amount(balance.confirmed));
      FLog.trace(text: 'Successfully synced Bitcoin wallet');
    } on FfiException catch (error) {
      FLog.error(text: 'Failed to sync Bitcoin wallet: Error: ' + error.message, exception: error);
    }
  }

  Future<void> _callSyncPaymentHistory() async {
    try {
      final bitcoinTxHistory = await api.getBitcoinTxHistory();

      var bph = bitcoinTxHistory
          .map((bitcoinTxHistoryItem) => PaymentHistoryItem(
              bitcoinTxHistoryItem.sent != 0
                  ? Amount(bitcoinTxHistoryItem.sent * -1)
                  : Amount(bitcoinTxHistoryItem.received),
              bitcoinTxHistoryItem.sent != 0 ? PaymentType.withdraw : PaymentType.deposit,
              bitcoinTxHistoryItem.isConfirmed ? PaymentStatus.finalized : PaymentStatus.pending))
          .toList();

      paymentHistory.update(bph);
      FLog.trace(text: 'Successfully synced payment history');
    } on FfiException catch (error) {
      FLog.error(text: 'Failed to sync payment history: ' + error.message, exception: error);
    }
  }

  Future<void> setupRustLogging() async {
    api.initLogging().listen((event) {
      // Only log to Dart file in release mode - in debug mode it's easier to
      // use stdout
      if (foundation.kReleaseMode) {
        FLog.logThis(text: '${event.target}: ${event.msg}', type: LogLevel.DEBUG);
      }
    });
  }
}

void runPeriodically(void Function() callback) =>
    Timer.periodic(const Duration(seconds: 20), (timer) => callback());
