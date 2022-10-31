import 'package:flutter/material.dart';
import 'mocks.dart';

class Seed extends StatelessWidget {
  const Seed({Key? key}) : super(key: key);

  static const routeName = '/seed';

  @override
  Widget build(BuildContext context) {
    final walletInfo = ModalRoute.of(context)!.settings.arguments as WalletInfo;
    return Scaffold(
        appBar: AppBar(
          title: const Text('Backup Seed'),
        ),
        body: ListView(children: [
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Card(
                  child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      child: Column(
                        children: [
                          const Text("Seed phrase",
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text(walletInfo.phrase.toString())
                        ],
                      )))),
        ]));
  }
}
