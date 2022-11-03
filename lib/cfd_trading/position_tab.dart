import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ten_ten_one/utilities/dropdown.dart';
import 'package:ten_ten_one/utilities/tto_table.dart';

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
    final formatter = NumberFormat.decimalPattern('en');

    // mock data
    const fundingRate = 0.000002;
    const margin = 0.0025;
    final expiry = DateTime.now();
    const liquidationPrice = 13104;
    final fmtLiquidationPrice = formatter.format(liquidationPrice);

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
            child: TtoTable([
              const TtoRow(label: 'Funding Rate', value: '$fundingRate', icon: Icons.currency_bitcoin),
              const TtoRow(label: 'Margin', value: '$margin', icon: Icons.currency_bitcoin),
              TtoRow(label: 'Expiry', value: DateFormat('dd.MM.yy-kk:mm').format(expiry)),
              TtoRow(label: 'Liquidation Price', value: '\$ $fmtLiquidationPrice'),
            ]),
        )
      ])
    ]);
  }
}
