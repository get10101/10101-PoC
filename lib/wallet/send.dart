import 'package:f_logs/f_logs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';
import 'package:go_router/go_router.dart';
import 'package:ten_ten_one/ffi.io.dart';

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
          title: const Text('Send Lightning Invoice'),
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
                          children: [
                            ElevatedButton(
                                onPressed: () async {
                                  FLog.info(text: "Sending invoice" + invoice);
                                  String? error;
                                  try {
                                    await api.sendLightningPayment(invoice: invoice);
                                  } on FfiException catch (e) {
                                    error = e.message;
                                  }

                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                    content: Text(error == null
                                        ? "Paid lightning invoice $invoice"
                                        : "Failed to send lightning invoice: $error"),
                                  ));
                                  context.go('/');
                                },
                                child: const Text('Send'))
                          ],
                        ),
                      ],
                    ),
                  ),
                ]))));
  }
}
