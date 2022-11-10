import 'package:flutter/material.dart' hide Divider;
import 'package:go_router/go_router.dart';
import 'package:ten_ten_one/balance.dart';
import 'package:ten_ten_one/cfd_trading/cfd_trading.dart';
import 'package:ten_ten_one/mocks/payment_history.dart';
import 'package:ten_ten_one/models/service_model.dart';
import 'package:ten_ten_one/wallet/payment_history_list_item.dart';
import 'package:ten_ten_one/wallet/receive.dart';
import 'package:ten_ten_one/wallet/send.dart';
import 'package:ten_ten_one/wallet/service_card.dart';
import 'package:ten_ten_one/utilities/divider.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';

class WalletBitcoin extends StatefulWidget {
  const WalletBitcoin({Key? key}) : super(key: key);

  static const name = "Bitcoin Wallet";
  static const navigationLabel = "Bitcoin";
  static const icon = Icons.currency_bitcoin;

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
    List<Widget> widgets = [
      const Balance(balanceSelector: BalanceSelector.bitcoin),
      const Divider(),
    ];

    final history = mockPaymentHistoryBitcoin(2);

    final txHistoryList = ListView.builder(
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      itemCount: history.length,
      itemBuilder: (context, index) {
        return PaymentHistoryListItem(data: history[index]);
      },
    );

    widgets.add(txHistoryList);

    return Scaffold(
      body: ListView(padding: const EdgeInsets.only(left: 25, right: 25), children: widgets),
      floatingActionButton: SpeedDial(
        icon: Icons.import_export,
        iconTheme: const IconThemeData(size: 35),
        activeIcon: Icons.close,
        backgroundColor: Colors.orange[800],
        foregroundColor: Colors.white,
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
            backgroundColor: Colors.orange[600],
            foregroundColor: Colors.white,
            label: 'Deposit',
            labelStyle: const TextStyle(fontSize: 18.0),
            onTap: () => GoRouter.of(context).go(Receive.route),
          ),
          SpeedDialChild(
            child: const Icon(Icons.upload_sharp),
            backgroundColor: Colors.orange[600],
            foregroundColor: Colors.white,
            label: 'Withdraw',
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