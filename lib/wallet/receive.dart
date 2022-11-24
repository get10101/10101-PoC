import 'package:f_logs/model/flog/flog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:ten_ten_one/ffi.io.dart';

class Receive extends StatefulWidget {
  const Receive({Key? key}) : super(key: key);

  static const route = '/' + subRouteName;
  static const subRouteName = 'receive';

  @override
  State<Receive> createState() => _ReceiveState();
}

class _ReceiveState extends State<Receive> {
  int invoiceAmount = 100;
  int expirySeconds = 600; // 10 mins default invoice expiry
  String description = "";
  String invoice = "";

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Receive Payment'),
        ),
        body: SafeArea(
            child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text("Amount (sats)", style: TextStyle(color: Colors.grey)),
                    TextFormField(
                      initialValue: invoiceAmount.toString(),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        border: UnderlineInputBorder(),
                      ),
                      inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
                      onChanged: (text) {
                        setState(() {
                          invoiceAmount = text != "" ? int.parse(text) : 0;
                        });
                      },
                    ),
                    const SizedBox(
                      height: 10.0,
                    ),
                  ]),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text("Expiry (seconds)", style: TextStyle(color: Colors.grey)),
                    TextFormField(
                      initialValue: expirySeconds.toString(),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        border: UnderlineInputBorder(),
                      ),
                      inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
                      onChanged: (text) {
                        setState(() {
                          expirySeconds = text != "" ? int.parse(text) : 0;
                        });
                      },
                    ),
                    const SizedBox(
                      height: 10.0,
                    ),
                  ]),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text("Description", style: TextStyle(color: Colors.grey)),
                    TextFormField(
                      initialValue: description,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        border: UnderlineInputBorder(),
                      ),
                      onChanged: (text) {
                        setState(() {
                          description = text;
                        });
                      },
                    ),
                    const SizedBox(
                      height: 10.0,
                    ),
                  ]),
                  ElevatedButton(
                      onPressed: () async {
                        FLog.info(
                            text: "Generating invoice for " +
                                invoiceAmount.toString() +
                                " sats with description: '" +
                                description +
                                "'");
                        String? error;
                        String? newInvoice;
                        try {
                          newInvoice = await api.createLightningInvoice(
                              amountSats: invoiceAmount,
                              expirySecs: expirySeconds,
                              description: description);
                        } on FfiException catch (e) {
                          error = e.message;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(error == null
                              ? "Generated new invoice"
                              : "Failed to create lightning invoice: $error"),
                        ));
                        if (newInvoice != null) {
                          FLog.info(text: "New invoice: " + invoice);
                          setState(() {
                            invoice = newInvoice!;
                          });
                        }
                      },
                      child: const Text('Create Invoice')),
                  const SizedBox(
                    height: 10.0,
                  ),
                  Expanded(
                    child: Container(
                      child: invoice.isEmpty
                          ? const Text("Generated invoice will appear here")
                          : Column(
                              children: [
                                Text(
                                  invoice,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 20),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy),
                                  style: IconButton.styleFrom(
                                    focusColor: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant
                                        .withOpacity(0.12),
                                    highlightColor:
                                        Theme.of(context).colorScheme.onSurface.withOpacity(0.12),
                                  ),
                                  onPressed: () async {
                                    await Clipboard.setData(ClipboardData(text: invoice));

                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                      content: Text("Copied to Clipboard"),
                                    ));
                                  },
                                ),
                                SizedBox(
                                  height: 250,
                                  width: 250,
                                  child: QrImage(
                                    data: invoice,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  )
                ]))));
  }
}
