import 'package:f_logs/f_logs.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';
import 'package:go_router/go_router.dart';
import 'package:ten_ten_one/cfd_trading/validation_error.dart';
import 'package:ten_ten_one/utilities/submit_button.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:ten_ten_one/ffi.io.dart' if (dart.library.html) 'ffi.web.dart';

class DrainFaucet extends StatefulWidget {
  const DrainFaucet({Key? key}) : super(key: key);

  static const route = '/' + subRouteName;
  static const subRouteName = 'drain-faucet';

  @override
  State<DrainFaucet> createState() => _DrainFaucetState();
}

final Uri _url = Uri.parse('https://coinfaucet.eu/en/btc-testnet/');

class _DrainFaucetState extends State<DrainFaucet> {
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
        title: const Text('Drain Faucet'),
      ),
      body: SafeArea(
          child: address.isEmpty
              ? const CircularProgressIndicator()
              : Container(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 15),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20.0),
                        child: AlertMessage(
                            message: Message(
                                title: "Use our faucet",
                                details:
                                    "By clicking the button below, you will receive 10,000 sats from us. \n\n"
                                    "To not go bankrupt, we would appreciate if you do this only once and return to us the funds when you are done testing. \n\n"
                                    "You can always go to the faucet yourself, see below.",
                                // TODO: allow them to return funds somehow
                                type: AlertType.info)),
                      ),
                      RichText(
                          text: TextSpan(
                        children: [
                          const TextSpan(
                            text: 'Public faucet: ',
                            style: TextStyle(color: Colors.black),
                          ),
                          TextSpan(
                            text: 'https://coinfaucet.eu/en/btc-testnet/',
                            style: const TextStyle(color: Colors.blue),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                launchUrl(_url);
                              },
                          ),
                        ],
                      )),
                      const Spacer(),
                      Container(
                        alignment: Alignment.bottomRight,
                        child: SubmitButton(
                            onPressed: () async {
                              try {
                                final txid = await api.callFaucet(address: address);
                                FLog.debug(text: "Tx id: " + txid);
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                  content: Text("Success. Your funds will arrive shortly."),
                                ));
                                GoRouter.of(context).go('/');
                              } on FfiException catch (error) {
                                FLog.error(
                                    text: "Failed to call faucet: Error: " + error.message,
                                    exception: error);
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  backgroundColor: Colors.red,
                                  content: Text("Failed to call faucet: Error: " + error.message),
                                ));
                              }
                            },
                            label: 'Fund me'),
                      )
                    ],
                  ),
                )),
    );
  }
}
