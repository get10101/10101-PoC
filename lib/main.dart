import 'dart:async';

import 'package:f_logs/f_logs.dart';
import 'package:feedback/feedback.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ten_ten_one/bridge_generated/bridge_definitions.dart';
import 'package:ten_ten_one/cfd_trading/cfd_offer_change_notifier.dart';
import 'package:ten_ten_one/cfd_trading/cfd_order_confirmation.dart';
import 'package:ten_ten_one/cfd_trading/cfd_order_detail.dart';
import 'package:ten_ten_one/cfd_trading/cfd_trading.dart';
import 'package:ten_ten_one/models/payment.model.dart';
import 'package:ten_ten_one/models/service_model.dart';
import 'package:ten_ten_one/onboarding_tour.dart';
import 'package:ten_ten_one/payment_history_change_notifier.dart';
import 'package:ten_ten_one/service_placeholders.dart';
import 'package:ten_ten_one/settings.dart';
import 'package:ten_ten_one/wallet/bitcoin_tx_detail.dart';
import 'package:ten_ten_one/wallet/channel_change_notifier.dart';
import 'package:ten_ten_one/wallet/close_channel.dart';
import 'package:ten_ten_one/wallet/fund_wallet_on_chain.dart';
import 'package:ten_ten_one/wallet/lightning_tx_detail.dart';
import 'package:ten_ten_one/wallet/qr_scan.dart';
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
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };

  final config = FLog.getDefaultConfigurations();
  config.activeLogLevel = LogLevel.DEBUG;

  FLog.applyConfigurations(config);

  runApp(MultiProvider(providers: [
    ChangeNotifierProvider(create: (context) => lightningBalance),
    ChangeNotifierProvider(create: (context) => bitcoinBalance),
    ChangeNotifierProvider(create: (context) => seedBackup),
    ChangeNotifierProvider(create: (context) => paymentHistory),
    ChangeNotifierProvider(create: (context) => CfdTradingChangeNotifier().init()),
    ChangeNotifierProvider(create: (context) => QrScanChangeNotifier()),
    ChangeNotifierProvider(create: (context) => WalletChangeNotifier()),
    ChangeNotifierProvider(create: (context) => cfdOffersChangeNotifier),
    ChangeNotifierProvider(create: (context) => ChannelChangeNotifier().init()),
  ], child: const TenTenOneApp()));
}

class TenTenOneApp extends StatefulWidget {
  const TenTenOneApp({Key? key}) : super(key: key);

  @override
  State<TenTenOneApp> createState() => _TenTenOneState();
}

class _TenTenOneState extends State<TenTenOneApp> {
  bool ready = false;
  bool showOnboarding = false;

  @override
  void initState() {
    super.initState();

    TenTenOneSharedPreferences.instance.isFirstStartup().then((value) => setState(() {
          showOnboarding = value;
        }));

    init();
  }

  @override
  Widget build(BuildContext context) {
    const mainColor = Colors.blue;

    if (ready) {
      FlutterNativeSplash.remove();
    }
    return BetterFeedback(
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: 'TenTenOne',
        theme: ThemeData(
            primarySwatch: mainColor,
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size(100, 50),
                  side: BorderSide(width: 1.0, color: Theme.of(context).colorScheme.primary),
                  backgroundColor: Colors.white,
                  textStyle: const TextStyle(fontSize: 16)),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    minimumSize: const Size(100, 50),
                    textStyle: const TextStyle(fontSize: 16.0))),
            floatingActionButtonTheme: const FloatingActionButtonThemeData(
              foregroundColor: Colors.white,
            ),
            appBarTheme: const AppBarTheme(
              foregroundColor: Colors.white,
              systemOverlayStyle: SystemUiOverlayStyle.dark,
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
                path: BitcoinTxDetail.subRouteName,
                builder: (BuildContext context, GoRouterState state) {
                  return BitcoinTxDetail(transaction: state.extra as BitcoinTxHistoryItem);
                },
              ),
              GoRoute(
                path: LightningTxDetail.subRouteName,
                builder: (BuildContext context, GoRouterState state) {
                  return LightningTxDetail(transaction: state.extra as LightningTransaction);
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
                path: CloseChannel.subRouteName,
                builder: (BuildContext context, GoRouterState state) {
                  return const CloseChannel();
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
                path: QrScan.subRouteName,
                builder: (BuildContext context, GoRouterState state) {
                  return const QrScan();
                },
              ),
              GoRoute(
                path: OpenChannel.subRouteName,
                builder: (BuildContext context, GoRouterState state) {
                  return const OpenChannel();
                },
              ),
              GoRoute(
                path: FundWalletOnChain.subRouteName,
                builder: (BuildContext context, GoRouterState state) {
                  return const FundWalletOnChain();
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
          path: Service.dca.route,
          builder: (BuildContext context, GoRouterState state) {
            return const ServicePlaceholder(
                service: Service.dca,
                description:
                    "When is the best time to buy Bitcoin? Now! DCA is a constant investment strategy to buy smaller amounts of Bitcoin over a period of time, no matter what price. DCA is coming soon!");
          },
        ),
        GoRoute(
          path: Settings.route,
          builder: (BuildContext context, GoRouterState state) {
            return const Settings();
          },
        ),
        GoRoute(
            path: OnboardingTour.route,
            builder: (BuildContext context, GoRouterState state) {
              return const OnboardingTour();
            }),
      ],
      redirect: (BuildContext context, GoRouterState state) async {
        // TODO: It's not optimal that we read this from shared prefs every time, should probably be set through a provider
        final isFirstStartup = await TenTenOneSharedPreferences.instance.isFirstStartup();

        if (isFirstStartup) {
          FLog.info(text: "First startup, starting onboarding tour...");
          TenTenOneSharedPreferences.instance.setFirstStartup(false);
          return OnboardingTour.route;
        }

        return null;
      });

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

      setState(() {
        FLog.info(text: "TenTenOne is ready!");
        ready = true;
      });
    } on FfiException catch (error) {
      FLog.error(text: "Failed to initialise: Error: " + error.message, exception: error);
    } catch (error) {
      FLog.error(text: "Failed to initialise: Unknown error");
    }

    // consecutive syncs
    runPeriodically(callGetBalances, seconds: 10);
    runPeriodically(callSyncWithChain, seconds: 60);
    runPeriodically(callSyncPaymentHistory, seconds: 10);
    runPeriodically(callGetOffers, seconds: 5);
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

Future<void> callSyncWithChain() async {
  try {
    await api.sync();
  } catch (error) {
    FLog.error(text: "Failed to sync wallet:" + error.toString());
  }
}

Future<void> callGetBalances() async {
  try {
    final balance = await api.getBalance();
    bitcoinBalance.update(Amount(balance.onChain.confirmed), Amount(balance.onChain.trustedPending),
        Amount(balance.onChain.untrustedPending), Amount(balance.offChain.pendingClose));
    lightningBalance.update(Amount(balance.offChain.available));
    FLog.trace(text: 'Successfully retrieved wallet balances');
  } catch (error) {
    FLog.error(text: "Failed to get balances:" + error.toString());
  }
}

Future<void> callGetOffers() async {
  final offer = await api.getOffer();
  cfdOffersChangeNotifier.update(offer);
  FLog.trace(text: 'Successfully fetched offers');
}

Future<void> callSyncPaymentHistory() async {
  final bitcoinTxHistory = await api.getBitcoinTxHistory();
  final lightningTxHistory = await api.getLightningTxHistory();

  var lth = lightningTxHistory.map((e) {
    var amount = Amount(e.sats);
    PaymentType type;
    switch (e.flow) {
      case bridge_definitions.Flow.Inbound:
        type = PaymentType.receive;
        amount = Amount(e.sats);
        break;
      case bridge_definitions.Flow.Outbound:
        type = PaymentType.send;
        amount = Amount(-e.sats);
        break;
    }
    PaymentStatus status;
    switch (e.status) {
      case HTLCStatus.Failed:
      case HTLCStatus.Expired:
        status = PaymentStatus.failed;
        break;
      case HTLCStatus.Succeeded:
        status = PaymentStatus.finalized;
        break;
      case HTLCStatus.Pending:
        status = PaymentStatus.pending;
        break;
    }
    return PaymentHistoryItem(amount, type, status, e.createdTimestamp, e);
  }).toList();

  var bph = bitcoinTxHistory.map((bitcoinTxHistoryItem) {
    var amount = bitcoinTxHistoryItem.sent != 0
        ? Amount(
            (bitcoinTxHistoryItem.sent - bitcoinTxHistoryItem.received - bitcoinTxHistoryItem.fee) *
                -1)
        : Amount(bitcoinTxHistoryItem.received);

    var type =
        bitcoinTxHistoryItem.sent != 0 ? PaymentType.sendOnChain : PaymentType.receiveOnChain;

    var status = bitcoinTxHistoryItem.isConfirmed ? PaymentStatus.finalized : PaymentStatus.pending;
    return PaymentHistoryItem(
        amount, type, status, bitcoinTxHistoryItem.timestamp, bitcoinTxHistoryItem);
  }).toList();

  final combinedList = [...bph, ...lth];
  combinedList.sort((a, b) => b.timestamp.compareTo(a.timestamp));
  paymentHistory.update(combinedList);

  FLog.trace(text: 'Successfully synced payment history');
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

class TenTenOneSharedPreferences {
  TenTenOneSharedPreferences._privateConstructor();

  static final TenTenOneSharedPreferences instance =
      TenTenOneSharedPreferences._privateConstructor();

  static const firstStartup = "firstStartup";

  setFirstStartup(bool value) async {
    SharedPreferences myPrefs = await SharedPreferences.getInstance();
    myPrefs.setBool(firstStartup, value);
  }

  Future<bool> isFirstStartup() async {
    SharedPreferences myPrefs = await SharedPreferences.getInstance();
    return myPrefs.getBool(firstStartup) == null ? true : false;
  }
}
