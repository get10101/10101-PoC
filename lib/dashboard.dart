import 'package:flutter/material.dart';
import 'package:ten_ten_one/bridge_definitions.dart';
import 'package:ten_ten_one/seed.dart';

import 'ffi.io.dart' if (dart.library.html) 'ffi.web.dart';
export 'ffi.io.dart' if (dart.library.html) 'ffi.web.dart' show api;

class Dashboard extends StatefulWidget {
  const Dashboard({Key? key}) : super(key: key);

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  late WalletInfo walletInfo;

  @override
  void initState() {
    super.initState();
    initWallet();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Dashboard'),
        ),
        body: ListView(children: [
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
                  children: const <Widget>[
                    ListTile(
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

  Future<void> initWallet() async {
    // todo: this should eventually come from the settings
    final info = await api.initWallet(network: "testnet");
    if (mounted) setState(() => walletInfo = info);
  }
}
