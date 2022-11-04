import 'dart:math';

import 'package:flutter/material.dart' hide Divider;
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:ten_ten_one/balance.dart';
import 'package:ten_ten_one/cfd_trading/cfd_order_confirmation.dart';
import 'package:ten_ten_one/cfd_trading/cfd_trading.dart';
import 'package:ten_ten_one/models/amount.model.dart';
import 'package:ten_ten_one/models/cfd_trading_state.dart';
import 'package:ten_ten_one/models/order.dart';
import 'package:ten_ten_one/utilities/divider.dart';
import 'package:ten_ten_one/utilities/dropdown.dart';
import 'package:ten_ten_one/utilities/tto_table.dart';
import 'package:ten_ten_one/utilities/tto_tabs.dart';

class CfdOffer extends StatelessWidget {
  static const leverages = [1, 2, 3];

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

class _CfdPositionState extends State<CfdPosition> {
  late Order order;

  @override
  void initState() {
    super.initState();
    final cfdTradingState = context.read<CfdTradingState>();

    if (!cfdTradingState.isStarted()) {
      // mock data
      order = Order(
          fundingRate: Amount(200),
          margin: Amount(250000),
          expiry: DateTime.now(),
          liquidationPrice: 13104,
          openPrice: 19100,
          pl: Amount(Random().nextInt(20000) + -10000),
          quantity: 100,
          estimatedFees: Amount(-4));
      cfdTradingState.startOrder(order);
    }
    order = cfdTradingState.getDraftOrder();
  }

  @override
  Widget build(BuildContext context) {
    // this widget gets build whenever the tab changes. this event can be used
    // to update draft order in the cfd trading state.
    order.position = widget.position;

    final formatter = NumberFormat.decimalPattern('en');

    final liquidationPrice = formatter.format(order.liquidationPrice);
    final fundingRate = order.fundingRate.display(Currency.btc).value.toStringAsFixed(10);
    final margin = order.margin.display(Currency.btc).value.toStringAsFixed(10);

    return ListView(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Dropdown(
          values: List<int>.generate(10, (i) => (i + 1) * 100)
              .map((quantity) => quantity.toString())
              .toList(),
          onChange: (contracts) {
            order.quantity = int.parse(contracts!);
          },
          value: order.quantity.toString(),
        ),
        Dropdown(
            values: TradingPair.values.map((t) => t.name.toUpperCase()).toList(),
            onChange: (tradingPair) {
              order.tradingPair =
                  TradingPair.values.firstWhere((e) => e.name == tradingPair!.toLowerCase());
            },
            value: order.tradingPair.name.toUpperCase()),
        Dropdown(
            values: CfdOffer.leverages.map((l) => 'x$l').toList(),
            onChange: (leverage) {
              order.leverage = int.parse(leverage!.substring(1));
            },
            value: 'x' + order.leverage.toString()),
      ]),
      Column(mainAxisAlignment: MainAxisAlignment.start, children: <Widget>[
        Container(
          margin: const EdgeInsets.only(top: 25),
          child: TtoTable([
            TtoRow(label: 'Funding Rate', value: fundingRate, icon: Icons.currency_bitcoin),
            TtoRow(label: 'Margin', value: margin, icon: Icons.currency_bitcoin),
            TtoRow(label: 'Expiry', value: DateFormat('dd.MM.yy-kk:mm').format(order.expiry)),
            TtoRow(label: 'Liquidation Price', value: '\$ $liquidationPrice'),
          ]),
        )
      ]),
    ]);
  }
}
