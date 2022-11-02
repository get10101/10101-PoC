import 'package:flutter/material.dart';
import 'package:ten_ten_one/cfd_trading/offer_table.dart';
import 'package:ten_ten_one/utilities/dropdown.dart';

enum Position { short, long }

class PositionTab extends StatefulWidget {
  final Position position;

  const PositionTab({super.key, required this.position});

  @override
  State<PositionTab> createState() => _PositionTabState();
}

class _PositionTabState extends State<PositionTab> {
  static const tradingPairs = ['BTCUSD', 'ETHUSD'];
  static const leverages = ['x1', 'x2', 'x3'];

  @override
  Widget build(BuildContext context) {
    return ListView(children: [
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
            child: OfferTable(0.000002, 0.0025, DateTime.now(), 13104)),
      ])
    ]);
  }
}
