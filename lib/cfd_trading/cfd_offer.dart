import 'package:flutter/material.dart' hide Divider;
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ten_ten_one/balance.dart';
import 'package:ten_ten_one/cfd_trading/cfd_trading.dart';
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

    final fmtBid = formatter.format(bid);
    final fmtAsk = formatter.format(ask);
    final fmtIndex = formatter.format(index);

    return Scaffold(
      body: ListView(padding: const EdgeInsets.only(left: 25, right: 25), children: [
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
                .map((position) => CfdPosition(position: position))
                .toList(),
            padding: const EdgeInsets.only(bottom: 15, top: 15)),
      ]),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          GoRouter.of(context).go(CfdTrading.route + '/' + CfdOrderConfirmation.subRouteName);
        },
        backgroundColor: Colors.orange,
        child: const Icon(Icons.shopping_cart_checkout),
      ),
    );
  }
}

class CfdPosition extends StatefulWidget {
  final Position position;

  const CfdPosition({super.key, required this.position});

  @override
  State<CfdPosition> createState() => _CfdPositionState();
}

class _CfdPositionState extends State<CfdPosition> with AutomaticKeepAliveClientMixin<CfdPosition> {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final formatter = NumberFormat.decimalPattern('en');

    const fundingRate = 0.000002;
    const margin = 0.0025;
    final expiry = DateTime.now();
    const liquidationPrice = 13104;

    final fmtLiquidationPrice = formatter.format(liquidationPrice);
    final fmtFundingRate = fundingRate.toStringAsFixed(10);
    final fmtMargin = margin.toStringAsFixed(10);

    return ListView(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Dropdown(
            values: List<int>.generate(10, (i) => (i + 1) * 100)
                .map((quantity) => quantity.toString())
                .toList()),
        const Dropdown(values: CfdOffer.tradingPairs),
        const Dropdown(values: CfdOffer.leverages),
      ]),
      Column(mainAxisAlignment: MainAxisAlignment.start, children: <Widget>[
        Container(
          margin: const EdgeInsets.only(top: 25),
          child: TtoTable([
            TtoRow(label: 'Funding Rate', value: fmtFundingRate, icon: Icons.currency_bitcoin),
            TtoRow(label: 'Margin', value: fmtMargin, icon: Icons.currency_bitcoin),
            TtoRow(label: 'Expiry', value: DateFormat('dd.MM.yy-kk:mm').format(expiry)),
            TtoRow(label: 'Liquidation Price', value: '\$ $fmtLiquidationPrice'),
          ]),
        )
      ])
    ]);
  }
}
