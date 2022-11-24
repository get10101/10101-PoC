import 'package:f_logs/f_logs.dart';
import 'package:flutter/material.dart' hide Divider;
import 'package:flutter/services.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:ten_ten_one/balance.dart';

import 'package:ten_ten_one/ffi.io.dart' if (dart.library.html) 'ffi.web.dart';
import 'package:ten_ten_one/models/balance_model.dart';
import 'package:ten_ten_one/utilities/divider.dart';

class OpenChannel extends StatefulWidget {
  const OpenChannel({Key? key}) : super(key: key);

  static const route = '/' + subRouteName;
  static const subRouteName = 'open-channel';

  // Max allowed amount is (16777215 / 3) - otherwise maker will not accept
  // the request.
  static const maxChannelAmount = 5592405;

  @override
  State<OpenChannel> createState() => _OpenChannelState();
}

class _OpenChannelState extends State<OpenChannel> {
  int takerChannelAmount = 0;

  @override
  void initState() {
    super.initState();
    final bitcoinBalance = context.read<BitcoinBalance>();
    takerChannelAmount = bitcoinBalance.amount.asSats.clamp(0, OpenChannel.maxChannelAmount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Open Channel'),
      ),
      body: SafeArea(
          child: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: const [
                  Balance(balanceSelector: BalanceSelector.bitcoin),
                  SizedBox(height: 10),
                  Padding(
                    padding: EdgeInsets.only(left: 20.0, right: 20.0),
                    child: Divider(),
                  )
                ]),
                const SizedBox(height: 10),
                const Center(child: Icon(Icons.private_connectivity_outlined, size: 80)),
                const SizedBox(height: 10),
                ListTile(
                    leading: addCircle("1"),
                    title: const Text("Fund your bitcoin wallet"),
                    subtitle: const Text(
                        "In order to establish a Lightning channel between 10101 and you we need to lock some bitcoin on chain.",
                        style: TextStyle(color: Colors.grey))),
                const SizedBox(height: 15),
                ListTile(
                    leading: addCircle("2"),
                    title: const Text("Enter the channel amount"),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                            "Define the amount of bitcoin you want to lock into the Lightning channel. 10101 will double it for great inbound liquidity.",
                            style: TextStyle(color: Colors.grey)),
                        TextFormField(
                          initialValue: takerChannelAmount.toString(),
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            border: UnderlineInputBorder(),
                          ),
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          onChanged: (text) {
                            setState(() {
                              takerChannelAmount = text != ""
                                  ? int.parse(text).clamp(0, OpenChannel.maxChannelAmount)
                                  : 0;
                            });
                          },
                        )
                      ],
                    )),
                const SizedBox(height: 15),
                ListTile(
                    leading: addCircle("3"),
                    title: const Text("Select your maker"),
                    subtitle: const Text(
                        "In this version you can only trade with 10101, but in the future you will be able to choose who to connect to.",
                        style: TextStyle(color: Colors.grey))),
                const SizedBox(height: 15),
                ListTile(
                    leading: addCircle("4"),
                    title: const Text("Ready!"),
                    subtitle: const Text(
                        "Hit the 'Open Channel' button and the channel will be created in a few moments.",
                        style: TextStyle(color: Colors.grey))),
                const SizedBox(height: 15),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 20.0),
            child: Container(
              alignment: Alignment.bottomRight,
              child: ElevatedButton(
                  onPressed: () async {
                    FLog.info(
                        text: "Opening Channel with capacity " + takerChannelAmount.toString());
                    try {
                      await api.openChannel(takerAmount: takerChannelAmount);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text("Waiting for channel to get established"),
                      ));
                      context.go('/');
                    } on FfiException catch (error) {
                      FLog.error(text: "Failed to open channel.", exception: error);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        backgroundColor: Colors.red,
                        content: Text("Failed to open channel. Is the maker online?"),
                      ));
                    }
                  },
                  child: const Text('Open Channel')),
            ),
          )
        ],
      )),
    );
  }

  Container addCircle(String value) {
    return Container(
      width: 45,
      height: 45,
      decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(100)),
      child: Center(
          child: Text(
        value,
        style: const TextStyle(color: Colors.white, fontSize: 20),
      )),
    );
  }
}
