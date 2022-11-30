import 'dart:io';
import 'dart:typed_data';

import 'package:f_logs/f_logs.dart';
import 'package:feedback/feedback.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:ten_ten_one/balance.dart';
import 'package:ten_ten_one/main.dart';
import 'package:ten_ten_one/models/balance_model.dart';
import 'package:ten_ten_one/models/seed_backup_model.dart';
import 'package:ten_ten_one/models/service_model.dart';
import 'package:ten_ten_one/payment_history_change_notifier.dart';
import 'package:ten_ten_one/wallet/channel_change_notifier.dart';
import 'package:ten_ten_one/wallet/fund_wallet_on_chain.dart';
import 'package:ten_ten_one/wallet/payment_history_list_item.dart';
import 'package:ten_ten_one/wallet/seed.dart';
import 'package:ten_ten_one/wallet/service_card.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:device_info_plus/device_info_plus.dart';

import 'package:ten_ten_one/menu.dart';
import 'package:ten_ten_one/app_bar_with_balance.dart';
import 'action_card.dart';
import 'open_channel.dart';

class WalletDashboard extends StatefulWidget {
  const WalletDashboard({Key? key}) : super(key: key);

  @override
  State<WalletDashboard> createState() => _WalletDashboardState();
}

class _WalletDashboardState extends State<WalletDashboard> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final seedBackupModel = context.watch<SeedBackupModel>();
    final bitcoinBalance = context.watch<BitcoinBalance>();
    final lightningBalance = context.watch<LightningBalance>();
    final paymentHistory = context.watch<PaymentHistory>();
    final channel = context.watch<ChannelChangeNotifier>();

    List<Widget> widgets = [
      const ServiceNavigation(),
    ];

    if (!seedBackupModel.backup) {
      widgets.add(ActionCard(CardDetails(
          route: Seed.route,
          title: "Create Wallet Backup",
          subtitle: "You have not backed up your wallet yet, make sure you create a backup!",
          icon: const Icon(Icons.warning))));
    }

    if (bitcoinBalance.total().asSats == 0) {
      widgets.add(ActionCard(CardDetails(
          route: FundWalletOnChain.route,
          title: "Deposit Bitcoin",
          subtitle:
              "Deposit Bitcoin into your wallet to enable opening a channel for trading on Lightning",
          icon: const Icon(Icons.link))));
    }

    if (bitcoinBalance.total().asSats != 0 && lightningBalance.amount.asSats == 0) {
      widgets.add(ActionCard(CardDetails(
        route: OpenChannel.route,
        title: "Open Channel",
        subtitle: "Open a channel to enable trading on Lightning",
        disabled: channel.isInitialising(),
        icon: channel.isInitialising()
            ? Container(
                width: 22,
                height: 22,
                padding: const EdgeInsets.all(2.0),
                child: const CircularProgressIndicator(
                  color: Colors.grey,
                  strokeWidth: 3,
                ),
              )
            : const Icon(Icons.launch),
      )));
    }

    final paymentHistoryList = ListView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const ClampingScrollPhysics(),
      itemCount: paymentHistory.history.length,
      itemBuilder: (context, index) {
        return PaymentHistoryListItem(data: paymentHistory.history[index]);
      },
    );

    widgets.add(paymentHistoryList);
    if (Platform.isAndroid || Platform.isIOS || true) {
      widgets.add(const SizedBox(height: 10));
      widgets.add(OutlinedButton(
        style: OutlinedButton.styleFrom(
            minimumSize: const Size(20, 50),
            side: BorderSide(width: 1.0, color: Theme.of(context).primaryColor)),
        child: const Text('Provide feedback'),
        onPressed: () {
          BetterFeedback.of(context).show((feedback) async {
            final screenshotFilePath = await writeImageToStorage(feedback.screenshot);
            final logs = await FLog.exportLogs();

            final deviceInfoPlugin = DeviceInfoPlugin();
            String info = "";
            if (Platform.isAndroid) {
              final deviceInfo = await deviceInfoPlugin.androidInfo;
              info = deviceInfo.model.toString() +
                  ", Android " +
                  deviceInfo.version.sdkInt.toString() +
                  ", Release: " +
                  deviceInfo.version.release;
            } else {
              final deviceInfo = await deviceInfoPlugin.iosInfo;
              info = deviceInfo.name! +
                  ", " +
                  deviceInfo.systemName! +
                  " " +
                  deviceInfo.systemVersion!;
            }

            final Email email = Email(
              body: feedback.text + '\n\n----------\n' + info,
              subject: '10101 Feedback',
              recipients: ['richard@coblox.tech'],
              attachmentPaths: [screenshotFilePath, logs.path],
              isHTML: false,
            );
            await FlutterEmailSender.send(email);
          });
        },
      ));
      widgets.add(const SizedBox(height: 10));
    }

    const balanceSelector = BalanceSelector.both;

    return Scaffold(
        drawer: const Menu(),
        appBar: PreferredSize(
            child: const AppBarWithBalance(balanceSelector: balanceSelector),
            preferredSize: Size.fromHeight(balanceSelector.preferredHeight)),
        body: SafeArea(
            child: RefreshIndicator(
                onRefresh: _pullRefresh,
                child: ListView(
                    padding: const EdgeInsets.only(left: 20, right: 20), children: widgets))));
  }

  Future<String> writeImageToStorage(Uint8List feedbackScreenshot) async {
    final Directory output = await getTemporaryDirectory();
    final String screenshotFilePath = '${output.path}/feedback.png';
    final File screenshotFile = File(screenshotFilePath);
    await screenshotFile.writeAsBytes(feedbackScreenshot);
    return screenshotFilePath;
  }

  Future<void> _pullRefresh() async {
    try {
      await callSyncWithChain();
      await callSyncPaymentHistory();
      await callGetBalances();
      FLog.info(text: "Done");
    } catch (error) {
      FLog.error(text: "Failed to get balances:" + error.toString());
    }
  }
}

class ServiceNavigation extends StatelessWidget {
  const ServiceNavigation({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100.0,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          GestureDetector(
            onTap: () => {GoRouter.of(context).go(Service.trade.route)},
            child: const ServiceCard(Service.trade),
          ),
          GestureDetector(
            onTap: () => {GoRouter.of(context).go(Service.dca.route)},
            child: const ServiceCard(Service.dca),
          ),
          GestureDetector(
            onTap: () => {GoRouter.of(context).go(Service.savings.route)},
            child: const ServiceCard(Service.savings),
          ),
        ],
      ),
    );
  }
}
