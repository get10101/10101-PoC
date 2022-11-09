import 'dart:async';

import 'package:f_logs/f_logs.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';
import 'package:provider/provider.dart';
import 'package:ten_ten_one/cfd_trading/cfd_order_confirmation.dart';
import 'package:ten_ten_one/cfd_trading/cfd_order_detail.dart';
import 'package:ten_ten_one/cfd_trading/cfd_trading.dart';
import 'package:ten_ten_one/dashboard.dart';
import 'package:ten_ten_one/models/amount.model.dart';
import 'package:ten_ten_one/models/balance_model.dart';
import 'package:ten_ten_one/cfd_trading/cfd_trading_service.dart';
import 'package:ten_ten_one/models/order.dart';
import 'package:ten_ten_one/models/seed_backup_model.dart';
import 'package:ten_ten_one/receive.dart';
import 'package:ten_ten_one/seed.dart';
import 'package:go_router/go_router.dart';
import 'package:ten_ten_one/send.dart';

import 'bridge_generated/bridge_definitions.dart';

import 'ffi.io.dart' if (dart.library.html) 'ffi.web.dart';

BalanceModel balanceModel = BalanceModel();
SeedBackupModel seedBackupModel = SeedBackupModel();

void main() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };

  final config = FLog.getDefaultConfigurations();
  config.activeLogLevel = foundation.kReleaseMode ? LogLevel.INFO : LogLevel.DEBUG;

  FLog.applyConfigurations(config);

  runApp(MultiProvider(providers: [
    ChangeNotifierProvider(create: (context) => balanceModel),
    ChangeNotifierProvider(create: (context) => seedBackupModel),
    ChangeNotifierProvider(create: (context) => CfdTradingService()),
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
            return const Dashboard();
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
    // consecutive syncs
    runPeriodically(_callSync);
  }

  Future<void> _callSync() async {
    try {
      final balance = await api.getBalance();
      balanceModel.update(Amount(balance.confirmed));
      FLog.trace(text: 'Successfully synced wallet');
    } on FfiException catch (error) {
      FLog.error(text: 'Failed to sync wallet: Error: ' + error.message, exception: error);
    }
  }

  Future<void> setupRustLogging() async {
    api.initLogging().listen((event) {
      FLog.logThis(text: 'log from rust: ${event.msg}', type: LogLevel.DEBUG);
    });
  }
}

void runPeriodically(void Function() callback) =>
    Timer.periodic(const Duration(seconds: 20), (timer) => callback());
