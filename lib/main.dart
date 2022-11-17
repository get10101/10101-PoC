import 'dart:async';

import 'package:f_logs/f_logs.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';
import 'package:provider/provider.dart';
import 'package:ten_ten_one/bridge_generated/bridge_definitions.dart';
import 'package:ten_ten_one/cfd_trading/cfd_offer_change_notifier.dart';
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
import 'package:ten_ten_one/bridge_generated/bridge_definitions.dart' as bride_definitions;

import 'package:ten_ten_one/ffi.io.dart' if (dart.library.html) 'ffi.web.dart';

LightningBalance lightningBalance = LightningBalance();
BitcoinBalance bitcoinBalance = BitcoinBalance();
SeedBackupModel seedBackup = SeedBackupModel();
PaymentHistory paymentHistory = PaymentHistory();
CfdOfferChangeNotifier cfdOffersChangeNotifier = CfdOfferChangeNotifier();

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
    ChangeNotifierProvider(create: (context) => cfdOffersChangeNotifier),
  ], child: const TenTenOneApp()));
}

class TenTenOneApp extends StatefulWidget {
  const TenTenOneApp({Key? key}) : super(key: key);

  @override
  State<TenTenOneApp> createState() => _TenTenOneState();
}

class _TenTenOneState extends State<TenTenOneApp> {
  bool ready = false;

  @override
  void initState() {
    super.initState();
    init();
  }

  @override
  Widget build(BuildContext context) {
    return Visibility(
      visible: ready,
      child: MaterialApp.router(
        title: 'TenTenOne',
        theme: ThemeData(primarySwatch: Colors.orange),
        routerConfig: _router,
      ),
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

  Future<void> init() async {
    try {
      await setupRustLogging();

      final appSupportDir = await getApplicationSupportDirectory();
      await api.initWallet(network: Network.Regtest, path: appSupportDir.path);
      await api.initDb(network: Network.Regtest, appDir: appSupportDir.path);
      await api.testDbConnection(); // TODO: Remove this call after testing DB

      FLog.info(text: "Starting ldk node");
      api
          .runLdk()
          .then((value) => FLog.info(text: "ldk node stopped."))
          .catchError((error) => FLog.error(text: "ldk stopped with an error", exception: error));

      FLog.info(text: "TenTenOne is ready!");
      setState(() {
        ready = true;
      });
    } on FfiException catch (error) {
      FLog.error(text: "Failed to initialise: Error: " + error.message, exception: error);
    } catch (error) {
      FLog.error(text: "Failed to initialise: Unknown error");
    }

    // consecutive syncs
    runPeriodically(_callSync);
    runPeriodically(_callSyncPaymentHistory);
    runPeriodically(_callGetOffers);
  }

  Future<void> _callSync() async {
    final balance = await api.getBalance();
    bitcoinBalance.update(Amount(balance.onChain.confirmed));
    lightningBalance.update(Amount(balance.offChain));
    FLog.trace(text: 'Successfully synced Bitcoin wallet');
  }

  Future<void> _callGetOffers() async {
    final offer = await api.getOffer();
    cfdOffersChangeNotifier.update(offer);
    FLog.trace(text: 'Successfully fetched offers');
  }

  Future<void> _callSyncPaymentHistory() async {
    final bitcoinTxHistory = await api.getBitcoinTxHistory();
    final lightningTxHistory = await api.getLightningTxHistory();

    var lth = lightningTxHistory.map((e) {
      var amount = Amount(e.sats);
      PaymentType type;
      switch (e.flow) {
        case bride_definitions.Flow.Inbound:
          type = PaymentType.receive;
          break;
        case bride_definitions.Flow.Outbound:
          type = PaymentType.send;
          break;
      }
      PaymentStatus status;
      switch (e.status) {
        case TransactionStatus.Failed:
          status = PaymentStatus.failed;
          break;
        case TransactionStatus.Succeeded:
          status = PaymentStatus.finalized;
          break;
        case TransactionStatus.Pending:
          status = PaymentStatus.pending;
          break;
      }
      return PaymentHistoryItem(amount, type, status, e.timestamp);
    }).toList();

    var bph = bitcoinTxHistory
        .map((bitcoinTxHistoryItem) => PaymentHistoryItem(
            bitcoinTxHistoryItem.sent != 0
                ? Amount(bitcoinTxHistoryItem.sent * -1)
                : Amount(bitcoinTxHistoryItem.received),
            bitcoinTxHistoryItem.sent != 0 ? PaymentType.withdraw : PaymentType.deposit,
            bitcoinTxHistoryItem.isConfirmed ? PaymentStatus.finalized : PaymentStatus.pending,
            bitcoinTxHistoryItem.timestamp))
        .toList();

    final combinedList = [...bph, ...lth];
    combinedList.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    paymentHistory.update(combinedList);

    FLog.trace(text: 'Successfully synced payment history');
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

void runPeriodically(void Function() callback) {
  _callback() {
    try {
      callback();
    } on FfiException catch (error) {
      FLog.error(text: 'Error: ' + error.message, exception: error);
    }
  }

  _callback();

  Timer.periodic(const Duration(seconds: 20), (timer) {
    _callback();
  });
}
