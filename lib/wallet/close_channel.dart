import 'package:f_logs/f_logs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:ten_ten_one/cfd_trading/validation_error.dart';
import 'package:ten_ten_one/ffi.io.dart';
import 'package:ten_ten_one/models/amount.model.dart';
import 'package:ten_ten_one/models/wallet_info_change_notifier.dart';
import 'package:ten_ten_one/utilities/submit_button.dart';

class CloseChannel extends StatefulWidget {
  const CloseChannel({Key? key}) : super(key: key);

  static const route = '/' + subRouteName;
  static const subRouteName = 'close-channel';

  @override
  State<CloseChannel> createState() => _CloseChannelState();
}

class _CloseChannelState extends State<CloseChannel> {
  late AmountDisplay closeAmount;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    WalletInfoChangeNotifier walletChangeNotifier = context.watch<WalletInfoChangeNotifier>();
    final lightningAmount = Amount(walletChangeNotifier.walletInfo.balance.offChain.available);
    closeAmount = lightningAmount.display(currency: Currency.sat);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Close channel'),
      ),
      body: SafeArea(
          child: ListView(
        children: [
          Container(
            padding: const EdgeInsets.all(20.0),
            child: Column(children: [
              Center(
                child: RichText(
                    text: TextSpan(
                        style: const TextStyle(color: Colors.black, fontSize: 18),
                        children: [
                      const TextSpan(
                          text: "This will close your Lightning channel with 10101\n\n",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(
                          text:
                              "Closing the channel will send ${closeAmount.value} sats to your 10101 on-chain wallet.\n\n"),
                      const TextSpan(
                          text:
                              "It will take at least 2 blocks after the publication of the channel close transaction for your coins to be confirmed by your on-chain wallet.\n\n"),
                      const TextSpan(
                          text:
                              "Once the channel is closed, you will have to open a new one if you want to continue using your wallet for Lightning payments and trading.")
                    ])),
              ),
            ]),
          ),
          Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      AlertMessage(
                          message: Message(
                              title:
                                  "Every time you open a new channel, you incur in additional transaction fees.",
                              type: AlertType.info)),
                      const SizedBox(height: 50),
                    ],
                  ))),
          Padding(
              padding: const EdgeInsets.only(right: 20.0),
              child: Container(
                alignment: Alignment.bottomRight,
                child: SubmitButton(
                  onPressed: closeChannel,
                  label: 'Close Channel',
                ),
              ))
        ],
      )),
    );
  }

  Future<void> closeChannel() async {
    FLog.info(text: "Closing channel with outbound liquidity of " + closeAmount.value.toString());

    try {
      await api.closeChannel();
    } on FfiException catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: Colors.red,
        content: Text("Failed to close channel. Error: " + error.toString()),
      ));
    }

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text("Channel closed"),
    ));
    context.go('/');
  }
}
