import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:ten_ten_one/cfd_trading/cfd_trading.dart';
import 'package:ten_ten_one/model/amount.dart';
import 'package:ten_ten_one/controller/cfd_trading_change_notifier.dart';
import 'package:ten_ten_one/model/order.dart';
import 'package:ten_ten_one/utilities/tto_table.dart';
import 'package:go_router/go_router.dart';

class CfdOrderDetail extends StatefulWidget {
  static const subRouteName = 'cfd-order-detail';

  final Order? order;

  const CfdOrderDetail({this.order, super.key});

  @override
  State<CfdOrderDetail> createState() => _CfdOrderDetailState();
}

class _CfdOrderDetailState extends State<CfdOrderDetail> {
  bool confirm = false;

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.decimalPattern('en');

    final cfdTradingService = context.watch<CfdTradingChangeNotifier>();
    Order order = widget.order!;

    final openPrice = formatter.format(order.openPrice);
    final liquidationPrice = formatter.format(order.liquidationPrice);
    final estimatedFees = order.estimatedFees.display(currency: Currency.btc, sign: true).value;
    final margin = order.margin.display(currency: Currency.btc).value;
    final unrealizedPL = order.pl.display(currency: Currency.btc, sign: true).value;
    final expiry = DateFormat('dd.MM.yy-kk:mm').format(order.expiry);
    final quantity = order.quantity.toString();
    final tradingPair = order.tradingPair.name.toUpperCase();

    return Scaffold(
        appBar: AppBar(title: const Text('CFD Order Details')),
        body: SafeArea(
          child: Container(
              padding: const EdgeInsets.all(20.0),
              child: Column(children: [
                Center(child: Text(tradingPair, style: const TextStyle(fontSize: 24))),
                const SizedBox(height: 35),
                Chip(
                    label: Text(order.status.display,
                        style:
                            const TextStyle(fontSize: 24, color: Colors.black, letterSpacing: 2)),
                    labelPadding: const EdgeInsets.only(left: 30, right: 30, top: 5, bottom: 5),
                    backgroundColor: Colors.white,
                    shape: const StadiumBorder(
                        side: BorderSide(
                      width: 1,
                      color: Colors.orange,
                    ))),
                const SizedBox(height: 35),
                Expanded(
                  child: TtoTable([
                    TtoRow(
                        label: 'Position',
                        value: order.position == Position.long ? 'Long' : 'Short'),
                    TtoRow(label: 'Opening Price', value: '\$ $openPrice'),
                    TtoRow(
                        label: 'Unrealized P/L', value: unrealizedPL, icon: Icons.currency_bitcoin),
                    TtoRow(label: 'Margin', value: margin, icon: Icons.currency_bitcoin),
                    TtoRow(label: 'Expiry', value: expiry),
                    TtoRow(label: 'Liquidation Price', value: '\$ $liquidationPrice'),
                    TtoRow(label: 'Quantity', value: quantity),
                    TtoRow(
                        label: 'Estimated fees', value: estimatedFees, icon: Icons.currency_bitcoin)
                  ]),
                ),
                Container(
                  margin: const EdgeInsets.fromLTRB(0, 0, 0, 30),
                  child: Row(
                    children: [
                      Visibility(
                          visible: confirm,
                          child: OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  confirm = false;
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                  side: const BorderSide(width: 1.0, color: Colors.orange),
                                  backgroundColor: Colors.white),
                              child: const Text('Cancel'))),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Visibility(
                              visible: OrderStatus.open == order.status && !confirm,
                              child: ElevatedButton(
                                  onPressed: () {
                                    setState(() {
                                      confirm = true;
                                    });
                                  },
                                  child: const Text('Settle')),
                            ),
                            Visibility(
                              visible: confirm,
                              child: ElevatedButton(
                                  onPressed: () {
                                    // mock cfd has been closed.
                                    Timer(const Duration(seconds: 2), () {
                                      order.status = OrderStatus.closed;
                                      cfdTradingService.persist(order);
                                    });

                                    context.go(CfdTrading.route);
                                  },
                                  child: const Text('Confirm')),
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              ])),
        ));
  }
}
