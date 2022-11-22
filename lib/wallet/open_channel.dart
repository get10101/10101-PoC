import 'package:f_logs/f_logs.dart';
import 'package:flutter/material.dart' hide Divider;
import 'package:flutter/services.dart';
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
  String peerPubkeyAndIpAddr = "";

  @override
  void initState() {
    super.initState();
    final bitcoinBalance = context.read<BitcoinBalance>();
    takerChannelAmount = bitcoinBalance.amount.asSats.clamp(0, OpenChannel.maxChannelAmount);
    _setMakerPeerInfo();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Open Channel'),
      ),
      body: SafeArea(
          child: Padding(
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
            // const Center(child: Text("How this works", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 24))),
            const SizedBox(height: 10),
            // const Center(child: Text("Before trading non-custodial, we need to establish a secure lightning channel.", style: TextStyle(fontWeight: FontWeight.normal, fontSize: 16))),
            // const SizedBox(height: 15),
            ListTile(
                leading: Container(
                  width: 50,
                  decoration:
                      BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(100)),
                  child: const Center(
                      child: Text(
                    "1",
                    style: TextStyle(color: Colors.white, fontSize: 20),
                  )),
                ),
                title: const Text("Fund your bitcoin wallet"),
                subtitle: const Text(
                    "In order to establish a secure channel between 10101 and you we need to lock some Bitcoin on chain through a Lightning channel.",
                    style: TextStyle(color: Colors.grey))),
            const SizedBox(height: 15),
            ListTile(
                leading: Container(
                  width: 50,
                  decoration:
                      BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(100)),
                  child: const Center(
                      child: Text(
                    "2",
                    style: TextStyle(color: Colors.white, fontSize: 20),
                  )),
                ),
                title: const Text("Enter the channel amount"),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                        "Define the amount of bitcoin you want to lock to the lightning channel. 10101 will add the same amount to the Lightning channel.",
                        style: TextStyle(color: Colors.grey)),
                    TextFormField(
                      initialValue: takerChannelAmount.toString(),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        border: UnderlineInputBorder(),
                      ),
                      inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
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
                leading: Container(
                  width: 50,
                  decoration:
                      BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(100)),
                  child: const Center(
                      child: Text(
                    "3",
                    style: TextStyle(color: Colors.white, fontSize: 20),
                  )),
                ),
                title: const Text("Select your maker"),
                subtitle: const Text(
                    "This feature is coming, but in this version you can only trade with 10101.",
                    style: TextStyle(color: Colors.grey))),
            const SizedBox(height: 15),
            ListTile(
                leading: Container(
                  width: 50,
                  decoration:
                      BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(100)),
                  child: const Center(
                      child: Text(
                    "4",
                    style: TextStyle(color: Colors.white, fontSize: 20),
                  )),
                ),
                title: const Text("Ready!"),
                subtitle: const Text(
                    "Hit the open channel button and the channel should be established in a few moments.",
                    style: TextStyle(color: Colors.grey))),
            const SizedBox(height: 15),
            const Spacer(),
            Container(
              alignment: Alignment.bottomRight,
              child: ElevatedButton(
                  onPressed: () async {
                    FLog.info(
                        text: "Opening Channel with capacity " + takerChannelAmount.toString());

                    api.openChannel(takerAmount: takerChannelAmount);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text("Waiting for channel to get established"),
                    ));
                    context.go('/');
                  },
                  child: const Text('Open Channel')),
            )
          ],
        ),
      )),
    );
  }

// This is pre-set in the backend, so no need to hook up to a change provider
  Future<void> _setMakerPeerInfo() async {
    final makerPubkeyAndIpAddr = await api.makerPeerInfo();
    setState(() => peerPubkeyAndIpAddr = makerPubkeyAndIpAddr);
  }
}
