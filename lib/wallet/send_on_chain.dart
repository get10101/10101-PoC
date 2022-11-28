import 'package:f_logs/f_logs.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:ten_ten_one/ffi.io.dart';
import 'package:ten_ten_one/models/balance_model.dart';
import 'package:ten_ten_one/utilities/async_button.dart';

class SendOnChain extends StatefulWidget {
  const SendOnChain({Key? key}) : super(key: key);

  static const route = '/' + subRouteName;
  static const subRouteName = 'send-on-chain';

  @override
  State<SendOnChain> createState() => _SendOnChainState();
}

class _SendOnChainState extends State<SendOnChain> {
  String address = "";
  int amount = 0;

  @override
  void initState() {
    super.initState();

    final bitcoinBalance = context.read<BitcoinBalance>();
    amount = bitcoinBalance.amount.asSats;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Send Bitcoin'),
        ),
        body: SafeArea(
            child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text("Address", style: TextStyle(color: Colors.grey)),
                    TextFormField(
                      initialValue: "",
                      keyboardType: TextInputType.text,
                      onChanged: (text) {
                        setState(() {
                          address = text;
                        });
                      },
                    ),
                    const SizedBox(
                      height: 10.0,
                    ),
                    const Text("Amount", style: TextStyle(color: Colors.grey)),
                    TextFormField(
                      initialValue: amount.toString(),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        border: UnderlineInputBorder(),
                      ),
                      inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
                      onChanged: (text) {
                        setState(() {
                          amount = text != "" ? int.parse(text) : 0;
                        });
                      },
                    )
                  ]),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [AsyncButton(onPressedFunction: sendOnChain, label: "Send")],
                        ),
                      ],
                    ),
                  ),
                ]))));
  }

  Future<void> sendOnChain() async {
    FLog.info(text: "Sending $amount to $address");
    await api.sendToAddress(address: address, amount: amount).then((value) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Sent $amount to $address"),
      ));

      context.go('/');
    }).catchError((error) {
      FLog.error(text: "Failed to send $amount to $address.", exception: error);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: Colors.red,
        content: Text("Failed to send $amount to $address. Error: " + error.toString()),
      ));
    });
  }
}
