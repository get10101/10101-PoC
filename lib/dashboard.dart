import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ten_ten_one/balance.dart';
import 'package:ten_ten_one/seed.dart';

import 'mocks.dart';

import 'ffi.io.dart' if (dart.library.html) 'ffi.web.dart';
export 'ffi.io.dart' if (dart.library.html) 'ffi.web.dart' show api;

class Dashboard extends StatefulWidget {
  const Dashboard({Key? key}) : super(key: key);

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  WalletInfo walletInfo = WalletInfo();
  String? walletBalance;

  @override
  void initState() {
    super.initState();
    _callInitWallet();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Dashboard'),
        ),
        body: ListView(children: [
          const Balance(),
          GestureDetector(
              onTap: () => {
                    Navigator.pushNamed(
                      context,
                      Seed.routeName,
                      arguments: walletInfo,
                    )
                  },
              child: Card(
                shape: const Border(left: BorderSide(color: Colors.blueGrey, width: 5)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    ListTile(
                      leading: const Icon(Icons.warning),
                      // TODO: Remove balance from here? Just plugged in to
                      // showcase that it works
                      title: const Text('Wallet Balance'),
                      subtitle: Text(walletBalance ?? ""),
                    ),
                    const ListTile(
                      leading: Icon(Icons.warning),
                      title: Text('Create Wallet Backup'),
                      subtitle: Text(
                          'You have not backed up your wallet yet, make sure you create a backup!'),
                    ),
                  ],
                ),
              ))
        ]));
  }

  Future<void> _callInitWallet() async {
    await api.initWallet();
    runPeriodically(_callSync);
  }

  Future<void> _callSync() async {
    final balance = await api.getBalance();
    if (mounted) setState(() => walletBalance = balance.confirmed.toString());
  }
}

void runPeriodically(void Function() callback) =>
    Timer.periodic(const Duration(seconds: 20), (timer) => callback());
