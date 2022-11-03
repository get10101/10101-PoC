import 'package:flutter/material.dart' hide Divider;
import 'package:intl/intl.dart';
import 'package:ten_ten_one/balance.dart';
import 'package:ten_ten_one/utilities/divider.dart';
import 'package:ten_ten_one/utilities/dropdown.dart';
import 'package:ten_ten_one/utilities/tto_table.dart';
import 'package:ten_ten_one/utilities/tto_tabs.dart';

enum Position {
  long,
  short,
}

class CfdOffer extends StatelessWidget {
  static const tradingPairs = ['BTCUSD', 'ETHUSD'];
  static const leverages = ['x1', 'x2', 'x3'];

  const CfdOffer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.decimalPattern('en');

    // mock data
    const bid = 19000;
    const ask = 19200;
    const index = 19100;
    const fundingRate = 0.000002;
    const margin = 0.0025;
    final expiry = DateTime.now();
    const liquidationPrice = 13104;

    final fmtBid = formatter.format(bid);
    final fmtAsk = formatter.format(ask);
    final fmtIndex = formatter.format(index);
    final fmtLiquidationPrice = formatter.format(liquidationPrice);

    return ListView(padding: const EdgeInsets.only(left: 25, right: 25), children: [
      const Balance(),
      const Divider(),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Text("bid $fmtBid"),
          Text("ask $fmtAsk"),
          Text("index $fmtIndex"),
        ],
      ),
      const SizedBox(height: 15),
      TtoTabs(
          tabs: const [
            Text('Buy / Long', style: TextStyle(fontSize: 20)),
            Text('Sell / Short', style: TextStyle(fontSize: 20)),
          ],
          content: [Position.long, Position.short]
              .map((position) => ListView(children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Dropdown(
                          values: List<int>.generate(10, (i) => (i + 1) * 100)
                              .map((quantity) => quantity.toString())
                              .toList()),
                      const Dropdown(values: tradingPairs),
                      const Dropdown(values: leverages),
                    ]),
                    Column(mainAxisAlignment: MainAxisAlignment.start, children: <Widget>[
                      Container(
                        margin: const EdgeInsets.only(top: 25),
                        child: TtoTable([
                          const TtoRow(
                              label: 'Funding Rate',
                              value: '$fundingRate',
                              icon: Icons.currency_bitcoin),
                          const TtoRow(
                              label: 'Margin', value: '$margin', icon: Icons.currency_bitcoin),
                          TtoRow(
                              label: 'Expiry', value: DateFormat('dd.MM.yy-kk:mm').format(expiry)),
                          TtoRow(label: 'Liquidation Price', value: '\$ $fmtLiquidationPrice'),
                        ]),
                      )
                    ])
                  ]))
              .toList(),
          padding: const EdgeInsets.only(bottom: 15, top: 15)),
    ]);
  }
}
