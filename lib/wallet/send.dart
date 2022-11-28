import 'package:f_logs/f_logs.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ten_ten_one/ffi.io.dart';
import 'package:ten_ten_one/utilities/async_button.dart';

class Send extends StatefulWidget {
  const Send({Key? key}) : super(key: key);

  static const route = '/' + subRouteName;
  static const subRouteName = 'send';

  @override
  State<Send> createState() => _SendState();
}

class _SendState extends State<Send> {
  String invoice = "";

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Send payment'),
        ),
        body: SafeArea(
            child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text("Invoice", style: TextStyle(color: Colors.grey)),
                    TextFormField(
                      initialValue: "",
                      keyboardType: TextInputType.text,
                      onChanged: (text) {
                        setState(() {
                          invoice = text;
                        });
                      },
                    ),
                    const SizedBox(
                      height: 10.0,
                    ),
                  ]),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [AsyncButton(onPressed: send, label: "Pay Invoice")],
                        ),
                      ],
                    ),
                  ),
                ]))));
  }

  Future<void> send() async {
    FLog.info(text: "Paying invoice $invoice");
    await api.sendLightningPayment(invoice: invoice).then((value) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Paid invoice $invoice"),
      ));

      context.go('/');
    }).catchError((error) {
      FLog.error(text: "Failed to pay invoice $invoice.", exception: error);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: Colors.red,
        content: Text("Failed to pay invoice $invoice. Error: " + error.toString()),
      ));
    });
  }
}
