import 'package:flutter/material.dart' hide Divider;
import 'package:ten_ten_one/balance.dart';
import 'package:ten_ten_one/cfd_trading/position_tab.dart';
import 'package:ten_ten_one/cfd_trading/position_tabs.dart';
import 'package:ten_ten_one/cfd_trading/prices.dart';
import 'package:ten_ten_one/utilities/divider.dart';
import 'package:ten_ten_one/menu.dart';

class CfdOffer extends StatelessWidget {
  const CfdOffer({Key? key}) : super(key: key);

  static const route = '/cfd-trading';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CFD Trading'),
      ),
      drawer: const Menu(),
      body: ListView(padding: const EdgeInsets.only(left: 25, right: 25), children: const [
        Balance(),
        Divider(),
        Prices(19000, 19200, 19000),
        SizedBox(height: 15),
        PositionTabs(tabs: [
          Text('Buy / Long', style: TextStyle(fontSize: 20)),
          Text('Sell / Short', style: TextStyle(fontSize: 20)),
        ], content: [
          PositionTab(position: Position.long),
          PositionTab(position: Position.short),
        ], padding: EdgeInsets.only(bottom: 15, top: 15)),
      ]),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: Colors.orange,
        child: const Icon(Icons.shopping_cart_checkout),
      ),
    );
  }
}
