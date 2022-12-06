import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:ten_ten_one/app_bar_with_balance.dart';
import 'package:ten_ten_one/balance.dart';
import 'package:ten_ten_one/main.dart';
import 'package:ten_ten_one/wallet/payment_history_list_item.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:ten_ten_one/wallet/receive_on_chain.dart';
import 'package:ten_ten_one/wallet/send_on_chain.dart';

import 'package:ten_ten_one/menu.dart';
import 'package:ten_ten_one/payment_history_change_notifier.dart';

class WalletBitcoin extends StatefulWidget {
  const WalletBitcoin({Key? key}) : super(key: key);

  @override
  State<WalletBitcoin> createState() => _WalletBitcoinState();
}

class _WalletBitcoinState extends State<WalletBitcoin> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final history = context.watch<PaymentHistory>();

    List<Widget> widgets = [];

    final txHistoryList = ListView.builder(
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      itemCount: history.bitcoinHistory().length,
      itemBuilder: (context, index) {
        return PaymentHistoryListItem(data: history.bitcoinHistory()[index]);
      },
    );

    widgets.add(txHistoryList);

    const balanceSelector = BalanceSelector.bitcoin;

    return Scaffold(
      drawer: const Menu(),
      appBar: PreferredSize(
          child: const AppBarWithBalance(balanceSelector: balanceSelector),
          preferredSize: Size.fromHeight(balanceSelector.preferredHeight)),
      body: SafeArea(
          child: RefreshIndicator(
              onRefresh: _pullRefresh,
              child: ListView(
                  padding: const EdgeInsets.only(left: 25, right: 25), children: widgets))),
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
            onTap: () => GoRouter.of(context).go(ReceiveOnChain.route),
          ),
          SpeedDialChild(
            child: const Icon(Icons.upload_sharp),
            label: 'Send',
            labelStyle: const TextStyle(fontSize: 18.0),
            onTap: () => GoRouter.of(context).go(SendOnChain.route),
          ),
        ],
      ),
    );
  }

  Future<void> _pullRefresh() async {
    await refreshWalletInfo();
  }
}
