import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:ten_ten_one/cfd_trading/cfd_trading.dart';
import 'package:ten_ten_one/models/amount.model.dart';
import 'package:ten_ten_one/cfd_trading/cfd_trading_service.dart';
import 'package:ten_ten_one/models/order.dart';
import 'package:ten_ten_one/utilities/tto_table.dart';

class CfdOrderConfirmation extends StatelessWidget {
  static const subRouteName = 'cfd-order-confirmation';

  final Order? order;

  const CfdOrderConfirmation({this.order, super.key});

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.decimalPattern('en');

    final cfdTradingService = context.read<CfdTradingService>();
    Order order = this.order!;

    final openPrice = formatter.format(order.openPrice);
    final liquidationPrice = formatter.format(order.liquidationPrice);
    final estimatedFees = order.estimatedFees.display(Currency.btc).value.toStringAsFixed(10);
    final margin = order.margin.display(Currency.btc).value.toStringAsFixed(10);
    final unrealizedPL = order.pl.display(Currency.btc).value.toStringAsFixed(10);
    final expiry = DateFormat('dd.MM.yy-kk:mm').format(order.expiry);
    final quantity = order.quantity.toString();
    final tradingPair = order.tradingPair.name.toUpperCase();

    return Scaffold(
        appBar: AppBar(title: const Text('CFD Order Confirmation')),
        body: Container(
          padding: const EdgeInsets.only(top: 30, right: 30, left: 30),
          child: Column(children: [
            Center(child: Text(tradingPair, style: const TextStyle(fontSize: 24))),
            const SizedBox(height: 25),
            TtoTable([
              TtoRow(label: 'Position', value: order.position == Position.long ? 'Long' : 'Short'),
              TtoRow(label: 'Opening Price', value: '\$ $openPrice'),
              TtoRow(label: 'Unrealized P/L', value: unrealizedPL, icon: Icons.currency_bitcoin),
              TtoRow(label: 'Margin', value: margin, icon: Icons.currency_bitcoin),
              TtoRow(label: 'Expiry', value: expiry),
              TtoRow(label: 'Liquidation Price', value: '\$ $liquidationPrice'),
              TtoRow(label: 'Quantity', value: quantity),
              TtoRow(label: 'Estimated fees', value: estimatedFees, icon: Icons.currency_bitcoin)
            ]),
            const SizedBox(height: 20),
            Text(
                'This will open a position and lock up $margin BTC in a channel. Would you like to proceed',
                style: const TextStyle(fontSize: 20)),
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(0, 0, 20, 30),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton(
                            onPressed: () {
                              // switch index to cfd overview tab.
                              cfdTradingService.selectedIndex = 1;
                              // todo send order to maker.
                              order.status = OrderStatus.pending;
                              order.updated = DateTime.now();
                              cfdTradingService.persist(order);

                              // mock cfd has been accepted.
                              Timer(const Duration(seconds: 5), () {
                                order.status = OrderStatus.open;
                                cfdTradingService.persist(order);
                              });

                              context.go(CfdTrading.route);
                            },
                            child: const Text('Confirm'))
                      ],
                    ),
                  ],
                ),
              ),
            )
          ]),
        ));
  }
}
