import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ten_ten_one/menu.dart';
import 'package:ten_ten_one/wallet/wallet_bitcoin.dart';
import 'package:ten_ten_one/wallet/wallet_change_notifier.dart';
import 'package:ten_ten_one/wallet/wallet_dashboard.dart';
import 'package:ten_ten_one/wallet/wallet_lightning.dart';

class Wallet extends StatefulWidget {
  static const route = '/cfd-trading';

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

  final List<String> _pageNames = <String>[
    WalletDashboard.name,
    WalletLightning.name,
    WalletBitcoin.name,
  ];

  final List<String> _pageNavigationLabels = <String>[
    WalletDashboard.navigationLabel,
    WalletLightning.navigationLabel,
    WalletBitcoin.navigationLabel,
  ];

  final List<IconData> _pageIcons = <IconData>[
    WalletDashboard.icon,
    WalletLightning.icon,
    WalletBitcoin.icon,
  ];

  @override
  Widget build(BuildContext context) {
    WalletChangeNotifier walletChangeNotifier = context.watch<WalletChangeNotifier>();

    return Scaffold(
        appBar: AppBar(
            // title: walletChangeNotifier.selectedIndex == 0 ? const Text('Lightning Wallet') : const Text('Bitcoin Wallet'),
            title: Text(_pageNames.elementAt(walletChangeNotifier.selectedIndex))),
        drawer: const Menu(),
        body: _pages.elementAt(walletChangeNotifier.selectedIndex),
        bottomNavigationBar: BottomNavigationBar(
          items: List.generate(
              3,
              (index) => BottomNavigationBarItem(
                    icon: Icon(_pageIcons.elementAt(index)),
                    label: _pageNavigationLabels.elementAt(index),
                  )),
          currentIndex: walletChangeNotifier.selectedIndex,
          selectedItemColor: Colors.orange,
          onTap: (index) {
            setState(() {
              // setting the selected index should be sufficient but for some reason
              // this is not triggering a rebuild even though the cfd trading state
              // is watched. A manual re-rendering is triggered through the setState
              // hook.
              walletChangeNotifier.selectedIndex = index;
            });
          },
        ));
  }
}
