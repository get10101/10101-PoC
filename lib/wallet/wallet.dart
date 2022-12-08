import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ten_ten_one/menu.dart';
import 'package:ten_ten_one/wallet/wallet_bitcoin.dart';
import 'package:ten_ten_one/wallet/wallet_change_notifier.dart';
import 'package:ten_ten_one/wallet/wallet_dashboard.dart';
import 'package:ten_ten_one/wallet/wallet_lightning.dart';

class Wallet extends StatefulWidget {
  const Wallet({Key? key}) : super(key: key);

  @override
  State<Wallet> createState() => _WalletState();
}

class _WalletState extends State<Wallet> {
  final List<Widget> _pages = <Widget>[
    const WalletDashboard(),
    const WalletLightning(),
    const WalletBitcoin(),
  ];

  @override
  Widget build(BuildContext context) {
    WalletChangeNotifier walletChangeNotifier = context.watch<WalletChangeNotifier>();

    return Scaffold(
        drawer: const Menu(),
        body: SafeArea(child: _pages.elementAt(walletChangeNotifier.selectedIndex)),
        bottomNavigationBar: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.wallet),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bolt),
              label: 'Lightning',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.link),
              label: 'Bitcoin',
            ),
          ],
          currentIndex: walletChangeNotifier.selectedIndex,
          selectedItemColor: Theme.of(context).colorScheme.primary,
          onTap: (index) {
            walletChangeNotifier.set(index);
          },
        ));
  }
}
