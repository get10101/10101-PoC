import 'package:flutter/material.dart' hide Divider;
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:ten_ten_one/balance.dart';
import 'package:ten_ten_one/cfd_trading/cfd_trading.dart';
import 'package:ten_ten_one/models/seed_backup_model.dart';
import 'package:ten_ten_one/models/service_model.dart';
import 'package:ten_ten_one/wallet/payment_history_list_item.dart';
import 'package:ten_ten_one/wallet/seed.dart';
import 'package:ten_ten_one/wallet/service_card.dart';
import 'package:ten_ten_one/utilities/divider.dart';

import '../mocks/payment_history.dart';

class WalletDashboard extends StatefulWidget {
  const WalletDashboard({Key? key}) : super(key: key);

  static const name = "Dashboard";
  static const navigationLabel = "Dashboard";
  static const icon = Icons.home;

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
    List<Widget> widgets = [
      const Balance(balanceSelector: BalanceSelector.both),
      const Divider(),
      const ServiceNavigation(),
      const Divider()
    ];

    if (!seedBackupModel.backup) {
      widgets.add(const BackupSeedCard());
    }

    final paymentHistory = mockPaymentHistory(10);

    final paymentHistoryList = ListView.builder(
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      itemCount: paymentHistory.length,
      itemBuilder: (context, index) {
        return PaymentHistoryListItem(data: paymentHistory[index]);
      },
    );

    widgets.add(paymentHistoryList);

    return Scaffold(
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
                leading: Icon(Icons.warning),
                title: Text('Create Wallet Backup'),
                subtitle:
                    Text('You have not backed up your wallet yet, make sure you create a backup!'),
              ),
            ],
          ),
        ));
  }
}
