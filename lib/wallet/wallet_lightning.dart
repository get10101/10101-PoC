import 'package:flutter/material.dart' hide Divider;
import 'package:go_router/go_router.dart';
import 'package:ten_ten_one/balance.dart';
import 'package:provider/provider.dart';
import 'package:ten_ten_one/cfd_trading/cfd_trading.dart';
import 'package:ten_ten_one/models/service_model.dart';
import 'package:ten_ten_one/wallet/payment_history_list_item.dart';
import 'package:ten_ten_one/wallet/receive.dart';
import 'package:ten_ten_one/wallet/send.dart';
import 'package:ten_ten_one/wallet/service_card.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';

import '../menu.dart';
import '../payment_history_change_notifier.dart';
import '../app_bar_with_balance.dart';

class WalletLightning extends StatefulWidget {
  const WalletLightning({Key? key}) : super(key: key);

  @override
  State<WalletLightning> createState() => _WalletLightningState();
}

class _WalletLightningState extends State<WalletLightning> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final history = context.watch<PaymentHistory>();

    List<Widget> widgets = [];

    final lightningHistory = history.lightningHistory();
    final paymentHistoryList = ListView.builder(
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      itemCount: lightningHistory.length,
      itemBuilder: (context, index) {
        return PaymentHistoryListItem(data: lightningHistory[index]);
      },
    );

    widgets.add(paymentHistoryList);

    const balanceSelector = BalanceSelector.lightning;

    return Scaffold(
      drawer: const Menu(),
      appBar: PreferredSize(
          child: const AppBarWithBalance(balanceSelector: balanceSelector),
          preferredSize: Size.fromHeight(balanceSelector.preferredHeight)),
      body: ListView(padding: const EdgeInsets.only(left: 25, right: 25), children: widgets),
      floatingActionButton: SpeedDial(
        icon: Icons.import_export,
        iconTheme: const IconThemeData(size: 35),
        activeIcon: Icons.close,
        activeBackgroundColor: Colors.grey,
        activeForegroundColor: Colors.white,
        buttonSize: const Size(56.0, 56.0),
        visible: true,
        closeManually: false,
        curve: Curves.bounceIn,
        overlayColor: Colors.black,
        overlayOpacity: 0.5,
        elevation: 8.0,
        shape: const CircleBorder(),
        children: [
          SpeedDialChild(
            child: const Icon(Icons.download_sharp),
            label: 'Receive',
            labelStyle: const TextStyle(fontSize: 18.0),
            onTap: () => GoRouter.of(context).go(Receive.route),
          ),
          SpeedDialChild(
            child: const Icon(Icons.upload_sharp),
            label: 'Send',
            labelStyle: const TextStyle(fontSize: 18.0),
            onTap: () => GoRouter.of(context).go(Send.route),
          ),
        ],
      ),
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
