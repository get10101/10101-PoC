import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ten_ten_one/cfd_trading/cfd_offer.dart';
import 'package:ten_ten_one/cfd_trading/cfd_overview.dart';
import 'package:ten_ten_one/menu.dart';
import 'package:ten_ten_one/cfd_trading/cfd_trading_change_notifier.dart';

import '../balance.dart';
import '../app_bar_with_balance.dart';

class CfdTrading extends StatefulWidget {
  static const route = '/cfd-trading';

  const CfdTrading({Key? key}) : super(key: key);

  @override
  State<CfdTrading> createState() => _CfdTradingState();
}

class _CfdTradingState extends State<CfdTrading> {
  final List<Widget> _pages = <Widget>[
    const CfdOffer(),
    const CfdOverview(),
    Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Text("Market"),
          Icon(Icons.candlestick_chart_sharp),
        ],
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    CfdTradingChangeNotifier cfdTradingService = context.watch<CfdTradingChangeNotifier>();

    const balanceSelector = BalanceSelector.lightning;

    return SafeArea(
      child: Scaffold(
          appBar: PreferredSize(
              child: const AppBarWithBalance(balanceSelector: balanceSelector),
              preferredSize: Size.fromHeight(balanceSelector.preferredHeight)),
          drawer: const Menu(),
          body: _pages.elementAt(cfdTradingService.selectedIndex),
          bottomNavigationBar: BottomNavigationBar(
            items: const <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                icon: Icon(Icons.handshake),
                label: 'Trade',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.format_list_bulleted_sharp),
                label: 'My CFDs',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.candlestick_chart_sharp),
                label: 'Market',
              ),
            ],
            currentIndex: cfdTradingService.selectedIndex,
            selectedItemColor: Theme.of(context).colorScheme.primary,
            onTap: (index) {
              setState(() {
                // setting the selected index should be sufficient but for some reason
                // this is not triggering a rebuild even though the cfd trading state
                // is watched. A manual re-rendering is triggered through the setState
                // hook.
                cfdTradingService.selectedIndex = index;
              });
            },
          )),
    );
  }
}
