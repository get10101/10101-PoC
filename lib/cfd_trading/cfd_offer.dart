import 'dart:math';

import 'package:flutter/material.dart' hide Divider;
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:ten_ten_one/balance.dart';
import 'package:ten_ten_one/bridge_generated/bridge_definitions.dart' hide Balance;
import 'package:ten_ten_one/cfd_trading/cfd_offer_change_notifier.dart';
import 'package:ten_ten_one/cfd_trading/cfd_order_confirmation.dart';
import 'package:ten_ten_one/cfd_trading/cfd_trading.dart';
import 'package:ten_ten_one/cfd_trading/cfd_trading_change_notifier.dart';
import 'package:ten_ten_one/cfd_trading/position_selection.dart';
import 'package:ten_ten_one/models/amount.model.dart';
import 'package:ten_ten_one/models/order.dart';
import 'package:ten_ten_one/utilities/divider.dart';
import 'package:ten_ten_one/utilities/dropdown.dart';
import 'package:ten_ten_one/utilities/tto_table.dart';

class CfdOffer extends StatefulWidget {
  static const leverages = [1, 2];

  const CfdOffer({Key? key}) : super(key: key);

  @override
  State<CfdOffer> createState() => _CfdOfferState();
}

class _CfdOfferState extends State<CfdOffer> {
  late Order order;

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.decimalPattern('en');

    final cfdTradingService = context.watch<CfdTradingChangeNotifier>();
    final cfdOffersChangeNotifier = context.watch<CfdOfferChangeNotifier>();

    // mock data
    cfdTradingService.draftOrder ??= Order(
        fundingRate: Amount(200),
        margin: Amount(250000),
        expiry: DateTime.now(),
        liquidationPrice: 13104,
        openPrice: 19100,
        pl: Amount(Random().nextInt(20000) + -10000),
        quantity: 100,
        estimatedFees: Amount(-4));

    order = cfdTradingService.draftOrder!;

    final liquidationPrice = formatter.format(order.liquidationPrice);
    final fundingRate = order.fundingRate.display(currency: Currency.btc).value;
    final margin = order.margin.display(currency: Currency.btc).value;

    final offer = cfdOffersChangeNotifier.offer ?? Offer(bid: 0, ask: 0, index: 0);

    final bid = offer.bid;
    final ask = offer.ask;
    final index = offer.index;

    final fmtBid = formatter.format(bid);
    final fmtAsk = formatter.format(ask);
    final fmtIndex = formatter.format(index);

    return Scaffold(
      body: ListView(padding: const EdgeInsets.only(left: 25, right: 25), children: [
        const Balance(balanceSelector: BalanceSelector.lightning),
        const Divider(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Text("bid $fmtBid"),
            Text("ask $fmtAsk"),
            Text("index $fmtIndex"),
          ],
        ),
        const SizedBox(height: 30),
        PositionSelection(
            onChange: (position) {
              setState(() {
                order.position = position!;
              });
            },
            value: order.position),
        const SizedBox(height: 15),
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
              values: [TradingPair.btcusd.name.toUpperCase()],
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
        ])
      ]),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          GoRouter.of(context)
              .go(CfdTrading.route + '/' + CfdOrderConfirmation.subRouteName, extra: order);
        },
        backgroundColor: Colors.orange,
        child: const Icon(Icons.shopping_cart_checkout),
      ),
    );
  }
}
