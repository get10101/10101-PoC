import 'package:flutter/material.dart' hide Divider;
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:ten_ten_one/balance.dart';
import 'package:ten_ten_one/cfd_trading/cfd_trading.dart';
import 'package:ten_ten_one/models/balance_model.dart';
import 'package:ten_ten_one/models/seed_backup_model.dart';
import 'package:ten_ten_one/models/service_model.dart';
import 'package:ten_ten_one/payment_history_change_notifier.dart';
import 'package:ten_ten_one/wallet/receive_on_chain.dart';
import 'package:ten_ten_one/wallet/payment_history_list_item.dart';
import 'package:ten_ten_one/wallet/seed.dart';
import 'package:ten_ten_one/wallet/service_card.dart';
import 'package:ten_ten_one/utilities/divider.dart';

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

    List<Widget> widgets = [
      const Balance(balanceSelector: BalanceSelector.both),
      const Divider(),
      const ServiceNavigation(),
      const Divider()
    ];

    if (!seedBackupModel.backup) {
      widgets.add(const BackupSeedCard());
    }

    if (bitcoinBalance.amount.asSats == 0) {
      widgets.add(const DepositBitcoinCard());
    }

    if (bitcoinBalance.amount.asSats != 0 && lightningBalance.amount.asSats == 0) {
      widgets.add(const OpenChannelCard());
    }

    final paymentHistoryList = ListView.builder(
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      itemCount: paymentHistory.history.length,
      itemBuilder: (context, index) {
        return PaymentHistoryListItem(data: paymentHistory.history[index]);
      },
    );

    widgets.add(paymentHistoryList);

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: ListView(padding: const EdgeInsets.only(left: 25, right: 25), children: widgets),
    );
  }
}

class ServiceNavigation extends StatelessWidget {
  const ServiceNavigation({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 110.0,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          GestureDetector(
            onTap: () => {GoRouter.of(context).go(CfdTrading.route)},
            child: const ServiceCard(Service.cfd),
          ),
          const ServiceCard(Service.sportsbet),
        ],
      ),
    );
  }
}

class BackupSeedCard extends StatelessWidget {
  const BackupSeedCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTap: () => {GoRouter.of(context).go(Seed.route)},
        child: Card(
          shape: const Border(left: BorderSide(color: Colors.blueGrey, width: 5)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const <Widget>[
              ListTile(
                leading: Icon(
                  Icons.warning,
                ),
                title: Text('Create Wallet Backup'),
                subtitle: Text(
                    'You have not backed up your wallet yet, make sure you create a backup!',
                    textAlign: TextAlign.justify),
              ),
            ],
          ),
        ));
  }
}

class DepositBitcoinCard extends StatelessWidget {
  const DepositBitcoinCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTap: () => {GoRouter.of(context).go(ReceiveOnChain.route)},
        child: Card(
          shape: const Border(left: BorderSide(color: Colors.blueGrey, width: 5)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const <Widget>[
              ListTile(
                leading: Icon(Icons.currency_bitcoin),
                title: Text('Deposit Bitcoin'),
                subtitle: Text(
                    'Deposit Bitcoin into your wallet to enable opening a channel for trading on Lightning',
                    textAlign: TextAlign.justify),
              ),
            ],
          ),
        ));
  }
}

class OpenChannelCard extends StatelessWidget {
  const OpenChannelCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTap: () => {GoRouter.of(context).go(OpenChannel.route)},
        child: Card(
          shape: const Border(left: BorderSide(color: Colors.blueGrey, width: 5)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const <Widget>[
              ListTile(
                leading: Icon(Icons.launch),
                title: Text('Open Channel'),
                subtitle: Text('Open a channel to enable trading on Lightning',
                    textAlign: TextAlign.justify),
              ),
            ],
          ),
        ));
  }
}
