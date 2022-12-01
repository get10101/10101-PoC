import 'dart:io';

import 'package:f_logs/f_logs.dart';
import 'package:feedback/feedback.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:ten_ten_one/app_bar_with_balance.dart';
import 'package:ten_ten_one/balance.dart';
import 'package:ten_ten_one/main.dart';
import 'package:ten_ten_one/menu.dart';
import 'package:ten_ten_one/models/balance_model.dart';
import 'package:ten_ten_one/models/seed_backup_model.dart';
import 'package:ten_ten_one/models/service_model.dart';
import 'package:ten_ten_one/payment_history_change_notifier.dart';
import 'package:ten_ten_one/utilities/feedback.dart';
import 'package:ten_ten_one/wallet/channel_change_notifier.dart';
import 'package:ten_ten_one/wallet/fund_wallet_on_chain.dart';
import 'package:ten_ten_one/wallet/payment_history_list_item.dart';
import 'package:ten_ten_one/wallet/seed.dart';
import 'package:ten_ten_one/wallet/service_card.dart';

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
    if (Platform.isAndroid || Platform.isIOS) {
      widgets.add(const SizedBox(height: 10));
      widgets.add(OutlinedButton(
        style: OutlinedButton.styleFrom(
            minimumSize: const Size(20, 50),
            side: BorderSide(width: 1.0, color: Theme.of(context).primaryColor)),
        child: const Text('Provide feedback'),
        onPressed: () {
          BetterFeedback.of(context).show(submitFeedback);
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
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
    );
  }
}
