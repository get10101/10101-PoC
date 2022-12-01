import 'package:f_logs/model/flog/flog.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ten_ten_one/balance.dart';
import 'package:provider/provider.dart';
import 'package:ten_ten_one/cfd_trading/cfd_trading_change_notifier.dart';
import 'package:ten_ten_one/cfd_trading/validation_error.dart';
import 'package:ten_ten_one/main.dart';
import 'package:ten_ten_one/wallet/channel_change_notifier.dart';
import 'package:ten_ten_one/wallet/close_channel.dart';
import 'package:ten_ten_one/wallet/payment_history_list_item.dart';
import 'package:ten_ten_one/wallet/receive.dart';
import 'package:ten_ten_one/wallet/send.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';

import 'package:ten_ten_one/menu.dart';
import 'package:ten_ten_one/payment_history_change_notifier.dart';
import 'package:ten_ten_one/app_bar_with_balance.dart';

class WalletLightning extends StatelessWidget {
  const WalletLightning({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final history = context.watch<PaymentHistory>();
    final channel = context.watch<ChannelChangeNotifier>();

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

    final cfdTradingService = context.watch<CfdTradingChangeNotifier>();
    final hasOpenCfds = cfdTradingService.hasOpenCfds();

    if (hasOpenCfds) {
      widgets.insert(
          0,
          AlertMessage(
              message: Message(
                  title:
                      "Cannot send or receive payments or close the channel when you have an open CFD. This feature is coming soon.",
                  type: AlertType.info)));
    }

    List<SpeedDialChild> dials = [
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
      )
    ];

    if (channel.isAvailable()) {
      dials.insert(
          0,
          SpeedDialChild(
            child: const Icon(Icons.link),
            label: 'Close channel',
            labelStyle: const TextStyle(fontSize: 18.0),
            onTap: () => GoRouter.of(context).go(CloseChannel.route),
          ));
    }

    return Scaffold(
      drawer: const Menu(),
      appBar: PreferredSize(
          child: const AppBarWithBalance(balanceSelector: balanceSelector),
          preferredSize: Size.fromHeight(balanceSelector.preferredHeight)),
      body: SafeArea(
          child: RefreshIndicator(
        onRefresh: _pullRefresh,
        child: ListView(padding: const EdgeInsets.only(left: 25, right: 25), children: widgets),
      )),
      floatingActionButton: SpeedDial(
        icon: Icons.import_export,
        iconTheme: const IconThemeData(size: 35),
        activeIcon: Icons.close,
        activeBackgroundColor: Colors.grey,
        activeForegroundColor: Colors.white,
        buttonSize: const Size(56.0, 56.0),
        visible: !hasOpenCfds,
        closeManually: false,
        curve: Curves.bounceIn,
        overlayColor: Colors.black,
        overlayOpacity: 0.5,
        elevation: 8.0,
        shape: const CircleBorder(),
        children: dials,
      ),
    );
  }

  Future<void> _pullRefresh() async {
    try {
      await callSyncWithChain();
      await callSyncPaymentHistory();
      await callGetBalances();
    } catch (error) {
      FLog.error(text: "Failed to get balances:" + error.toString());
    }
  }
}
