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
import 'package:ten_ten_one/models/service_model.dart';
import 'package:ten_ten_one/payment_history_change_notifier.dart';
import 'package:ten_ten_one/service_placeholders.dart';
import 'package:ten_ten_one/wallet/channel_change_notifier.dart';
import 'package:ten_ten_one/wallet/receive_on_chain.dart';
import 'package:ten_ten_one/wallet/open_channel.dart';
import 'package:ten_ten_one/wallet/wallet.dart';
import 'package:ten_ten_one/wallet/wallet_change_notifier.dart';
import 'package:ten_ten_one/models/amount.model.dart';
import 'package:ten_ten_one/models/balance_model.dart';
import 'package:ten_ten_one/cfd_trading/cfd_trading_change_notifier.dart';
import 'package:ten_ten_one/models/seed_backup_model.dart';
import 'package:ten_ten_one/wallet/receive.dart';
import 'package:ten_ten_one/wallet/seed.dart';
import 'package:go_router/go_router.dart';
import 'package:ten_ten_one/wallet/send.dart';
import 'package:ten_ten_one/wallet/send_on_chain.dart';
import 'package:ten_ten_one/bridge_generated/bridge_definitions.dart' as bridge_definitions;

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
    ChangeNotifierProvider(create: (context) => CfdTradingChangeNotifier().init()),
    ChangeNotifierProvider(create: (context) => WalletChangeNotifier()),
    ChangeNotifierProvider(create: (context) => cfdOffersChangeNotifier),
    ChangeNotifierProvider(create: (context) => ChannelChangeNotifier()),
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
    const mainColor = Colors.blue;

    return Visibility(
      visible: ready,
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: 'TenTenOne',
        theme: ThemeData(
            primarySwatch: mainColor,
            elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(foregroundColor: Colors.white)),
            floatingActionButtonTheme: const FloatingActionButtonThemeData(
              foregroundColor: Colors.white,
            ),
            appBarTheme: const AppBarTheme(
              foregroundColor: Colors.white,
            )),
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
              path: ReceiveOnChain.subRouteName,
              builder: (BuildContext context, GoRouterState state) {
                return const ReceiveOnChain();
              },
            ),
            GoRoute(
              path: SendOnChain.subRouteName,
              builder: (BuildContext context, GoRouterState state) {
                return const SendOnChain();
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
                return CfdOrderConfirmation(args: state.extra as CfdOrderConfirmationArgs);
              },
            ),
            GoRoute(
              path: CfdOrderDetail.subRouteName,
              builder: (BuildContext context, GoRouterState state) {
                return CfdOrderDetail(cfd: state.extra as Cfd);
              },
            ),
          ]),
      GoRoute(
        path: Service.savings.route,
        builder: (BuildContext context, GoRouterState state) {
          return const ServicePlaceholder(
              service: Service.savings, description: "We bring stacking to Bitcoin!");
        },
      ),
      GoRoute(
        path: Service.exchange.route,
        builder: (BuildContext context, GoRouterState state) {
          return const ServicePlaceholder(
              service: Service.exchange,
              description:
                  "Have you heard of Taro? We sure did - and yes, we are planning to build a non custodial exchange using Taro!");
        },
      ),
      GoRoute(
        path: Service.sportsbet.route,
        builder: (BuildContext context, GoRouterState state) {
          return const ServicePlaceholder(
              service: Service.sportsbet,
              description:
                  "Pick your favourite team and place a bet! Binary sports-bets are in the works - more complex bets to come - soon!");
        },
      ),
    ],
  );

  Future<void> init() async {
    try {
      await setupRustLogging();

      final appSupportDir = await getApplicationSupportDirectory();
      FLog.info(text: "App data will be stored in: " + appSupportDir.toString());

      await api.initWallet(path: appSupportDir.path);
      await api.initDb(appDir: appSupportDir.path);

      FLog.info(text: "Starting ldk node");
      api
          .runLdk()
          .then((value) => FLog.info(text: "ldk node stopped."))
          .catchError((error) => FLog.error(text: "ldk stopped with an error", exception: error));

      // connect to the maker, this will not return unless there was an error.
      api.connect().then((value) => FLog.error(text: "Lost connection to the maker")).catchError(
          (error) =>
              FLog.error(text: "Lost connection to the maker with an error", exception: error));

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
    runPeriodically(_callSync, seconds: 10);
    runPeriodically(_callSyncPaymentHistory, seconds: 10);
    runPeriodically(_callGetOffers, seconds: 5);
  }

  Future<void> _callSync() async {
    try {
      final balance = await api.getBalance();
      bitcoinBalance.update(Amount(balance.onChain.confirmed));
      lightningBalance.update(Amount(balance.offChain));
      FLog.trace(text: 'Successfully synced Bitcoin wallet');
    } catch (error) {
      FLog.error(text: "Failed to sync wallet:" + error.toString());
    }
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
        case bridge_definitions.Flow.Inbound:
          type = PaymentType.receive;
          break;
        case bridge_definitions.Flow.Outbound:
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

    var bph = bitcoinTxHistory.map((bitcoinTxHistoryItem) {
      var amount = bitcoinTxHistoryItem.sent != 0
          ? Amount((bitcoinTxHistoryItem.sent -
                  bitcoinTxHistoryItem.received -
                  bitcoinTxHistoryItem.fee) *
              -1)
          : Amount(bitcoinTxHistoryItem.received);

      var type =
          bitcoinTxHistoryItem.sent != 0 ? PaymentType.sendOnChain : PaymentType.receiveOnChain;

      var status =
          bitcoinTxHistoryItem.isConfirmed ? PaymentStatus.finalized : PaymentStatus.pending;
      return PaymentHistoryItem(amount, type, status, bitcoinTxHistoryItem.timestamp);
    }).toList();

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

void runPeriodically(void Function() callback, {seconds = 20}) {
  _callback() {
    try {
      callback();
    } on FfiException catch (error) {
      FLog.error(text: 'Error: ' + error.message, exception: error);
    }
  }

  _callback();

  Timer.periodic(Duration(seconds: seconds), (timer) {
    _callback();
  });
}
