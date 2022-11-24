import 'package:f_logs/f_logs.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:ten_ten_one/cfd_trading/validation_error.dart';

import 'package:ten_ten_one/ffi.io.dart' if (dart.library.html) 'ffi.web.dart';

class ReceiveOnChain extends StatefulWidget {
  const ReceiveOnChain({Key? key}) : super(key: key);

  static const route = '/' + subRouteName;
  static const subRouteName = 'receive-on-chain';

  @override
  State<ReceiveOnChain> createState() => _ReceiveOnChainState();
}

class _ReceiveOnChainState extends State<ReceiveOnChain> {
  String address = "";

  @override
  void initState() {
    _callGetAddress();
    super.initState();
  }

  Future<void> _callGetAddress() async {
    try {
      final address = await api.getAddress();
      setState(() {
        this.address = address.address;
      });
    } on FfiException catch (error) {
      FLog.error(text: "Failed to fetch address phrase: Error: " + error.message, exception: error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receive Bitcoin'),
      ),
      body: SafeArea(
          child: address.isEmpty
              ? const CircularProgressIndicator()
              : Container(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 250,
                        width: 250,
                        child: QrImage(
                          data: address,
                        ),
                      ),
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          Expanded(
                              child: Text(
                            address,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 20),
                          )),
                          IconButton(
                            icon: const Icon(Icons.copy),
                            style: IconButton.styleFrom(
                              focusColor:
                                  Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.12),
                              highlightColor:
                                  Theme.of(context).colorScheme.onSurface.withOpacity(0.12),
                            ),
                            onPressed: () async {
                              await Clipboard.setData(ClipboardData(text: address));

                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                content: Text("Copied to Clipboard"),
                              ));
                            },
                          )
                        ],
                      ),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20.0),
                        child: AlertMessage(
                            message: Message(
                                title:
                                    "Send Bitcoin to the given address. Once your transaction is confirmed the balance will change in the wallet",
                                type: AlertType.info)),
                      ),
                      Container(
                        alignment: Alignment.bottomRight,
                        child: ElevatedButton(
                            onPressed: () async {
                              GoRouter.of(context).go('/');
                            },
                            child: const Text('Close')),
                      )
                    ],
                  ),
                )),
    );
  }
}
