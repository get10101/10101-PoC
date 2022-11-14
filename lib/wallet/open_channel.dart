import 'package:f_logs/f_logs.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';
import 'package:provider/provider.dart';

import 'package:ten_ten_one/ffi.io.dart' if (dart.library.html) 'ffi.web.dart';

import '../model/balance_model.dart';

class OpenChannel extends StatefulWidget {
  const OpenChannel({Key? key}) : super(key: key);

  static const route = '/' + subRouteName;
  static const subRouteName = 'open-channel';

  static const makerNodeId =
      "029c33cbd0dd3a3c957e3e9933a4d29cdc03853caeb63e861c0dea3cbb240cea2e"; // TODO: plug in public maker pubkey
  static const makerNodeName = "10101";
  static const makerIpAddress = "127.0.0.1"; // TODO: plug in public maker node ip
  static const makerPort = "9745"; //TODO: reset to default port 9735

  @override
  State<OpenChannel> createState() => _OpenChannelState();
}

class _OpenChannelState extends State<OpenChannel> {
  int channelCapacity = 0;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _callOpenChannel() async {
    try {
      FLog.info(text: "Opening Channel with capacity " + channelCapacity.toString());

      await api.openChannel(
          peerPubkeyAndIpAddr: OpenChannel.makerNodeId +
              "@" +
              OpenChannel.makerIpAddress +
              ":" +
              OpenChannel.makerPort,
          channelAmountSat: channelCapacity);
    } on FfiException catch (error) {
      FLog.error(text: "Failed to fetch address phrase: Error: " + error.message, exception: error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bitcoinBalance = context.watch<BitcoinBalance>();
    channelCapacity = bitcoinBalance.amount.asSats;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Open Channel'),
      ),
      body: SafeArea(
          child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text("Node ID", style: TextStyle(color: Colors.grey)),
              const SizedBox(
                height: 5.0,
              ),
              const SelectableText(OpenChannel.makerNodeId, style: TextStyle(fontSize: 20)),
              const SizedBox(
                height: 10.0,
              ),
              const Text("Node Name", style: TextStyle(color: Colors.grey)),
              const SizedBox(
                height: 5.0,
              ),
              const SelectableText(OpenChannel.makerNodeName, style: TextStyle(fontSize: 20)),
              const SizedBox(
                height: 10.0,
              ),
              const Text("Your Bitcoin Balance", style: TextStyle(color: Colors.grey)),
              const SizedBox(
                height: 5.0,
              ),
              SelectableText(bitcoinBalance.amount.asSats.toString(),
                  style: const TextStyle(fontSize: 20)),
              const SizedBox(
                height: 10.0,
              ),
              const Text("Channel Capacity", style: TextStyle(color: Colors.grey)),
              // TODO: Likely we cannot use the whole balance
              // TODO: Form validation
              TextFormField(
                initialValue: bitcoinBalance.amount.asSats.toString(),
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
                onChanged: (text) {
                  channelCapacity = int.parse(text);
                },
              )
            ]),
            const Spacer(),
            const Padding(
              padding: EdgeInsets.only(bottom: 20.0),
              child: Text(
                  "Opening the channel will transfer the specified channel capacity of your Bitcoin balance into a Lightning channel with 10101."
                  "\n\n"
                  "Once the channel is open you can trade with 10101 non-custodial over Lightning!"),
            ),
            Container(
              alignment: Alignment.bottomRight,
              child: ElevatedButton(
                  onPressed: () async {
                    await _callOpenChannel();

                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text("Call open channel returned"),
                    ));
                  },
                  child: const Text('Open Channel')),
            )
          ],
        ),
      )),
    );
  }
}
