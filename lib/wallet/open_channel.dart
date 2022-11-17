import 'package:f_logs/f_logs.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:ten_ten_one/ffi.io.dart' if (dart.library.html) 'ffi.web.dart';
import 'package:ten_ten_one/models/balance_model.dart';

class OpenChannel extends StatefulWidget {
  const OpenChannel({Key? key}) : super(key: key);

  static const route = '/' + subRouteName;
  static const subRouteName = 'open-channel';

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
    takerChannelAmount = bitcoinBalance.amount.asSats;
    _setMakerPeerInfo();
  }

  @override
  Widget build(BuildContext context) {
    final bitcoinBalance = context.watch<BitcoinBalance>();
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
              const Text("P2P Endpoint", style: TextStyle(color: Colors.grey)),
              const SizedBox(
                height: 5.0,
              ),
              Text(peerPubkeyAndIpAddr, style: const TextStyle(fontSize: 20)),
              const SizedBox(
                height: 10.0,
              ),
              const Text("Node Name", style: TextStyle(color: Colors.grey)),
              const SizedBox(
                height: 5.0,
              ),
              const SelectableText('10101', style: TextStyle(fontSize: 20)),
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
              const Text("Channel Amount", style: TextStyle(color: Colors.grey)),
              // TODO: Likely we cannot use the whole balance
              // TODO: Form validation
              TextFormField(
                initialValue: takerChannelAmount.toString(),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: UnderlineInputBorder(),
                ),
                inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
                onChanged: (text) {
                  setState(() {
                    takerChannelAmount = text != "" ? int.parse(text) : 0;
                  });
                },
              )
            ]),
            const Spacer(),
            const Padding(
              padding: EdgeInsets.only(bottom: 20.0),
              child: Text(
                  "Opening the channel will transfer the specified amount of your Bitcoin balance into a Lightning channel with 10101."
                  "\n\n"
                  "Once the channel is open you can trade with 10101 non-custodial over Lightning!"),
            ),
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
