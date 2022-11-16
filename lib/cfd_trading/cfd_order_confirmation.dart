import 'package:f_logs/model/flog/flog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:ten_ten_one/cfd_trading/cfd_trading.dart';
import 'package:ten_ten_one/models/amount.model.dart';
import 'package:ten_ten_one/cfd_trading/cfd_trading_change_notifier.dart';
import 'package:ten_ten_one/models/order.dart';
import 'package:ten_ten_one/utilities/tto_table.dart';

import 'package:ten_ten_one/ffi.io.dart' if (dart.library.html) 'ffi.web.dart';

class CfdOrderConfirmation extends StatelessWidget {
  static const subRouteName = 'cfd-order-confirmation';

  final Order? order;

  const CfdOrderConfirmation({this.order, super.key});

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.decimalPattern('en');

    final cfdTradingService = context.read<CfdTradingChangeNotifier>();
    Order order = this.order!;

    final openPrice = formatter.format(order.openPrice);
    final liquidationPrice = formatter.format(order.liquidationPrice);
    final estimatedFees = order.estimatedFees.display(currency: Currency.btc).value;
    final margin = order.margin.display(currency: Currency.btc).value;
    final unrealizedPL = order.pl.display(currency: Currency.btc).value;
    final expiry = DateFormat('dd.MM.yy-kk:mm').format(order.expiry);
    final quantity = order.quantity.toString();
    final tradingPair = order.tradingPair.name.toUpperCase();

    return Scaffold(
        appBar: AppBar(title: const Text('CFD Order Confirmation')),
        body: SafeArea(
          child: Container(
            padding: const EdgeInsets.all(20.0),
            child: Column(children: [
              Center(child: Text(tradingPair, style: const TextStyle(fontSize: 16))),
              const SizedBox(height: 25),
              TtoTable([
                TtoRow(
                    label: 'Position', value: order.position == Position.long ? 'Long' : 'Short'),
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
                              onPressed: () async {
                                // switch index to cfd overview tab.
                                cfdTradingService.selectedIndex = 1;

                                // TODO: Plug in actual state changes

                                // clear draft order from cfd service state
                                cfdTradingService.draftOrder = null;

                                try {
                                  // TODO: Don't hardcode the taker amount
                                  await api.openCfd(takerAmount: 20000, leverage: order.leverage);
                                  FLog.info(text: 'OpenCfd returned successfully');
                                } on FfiException catch (error) {
                                  FLog.error(
                                      text: 'Failed to open CFD: ' + error.message,
                                      exception: error);

                                  order.status = OrderStatus.pending;
                                  order.updated = DateTime.now();
                                  // immediately set to open, because if adding the custom output succeeded we just go on
                                  order.status = OrderStatus.failed;
                                  cfdTradingService.persist(order);

                                  return;
                                }

                                order.status = OrderStatus.pending;
                                order.updated = DateTime.now();
                                // if adding the custom output succeeded, the CFD is open
                                order.status = OrderStatus.open;
                                cfdTradingService.persist(order);

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
          ),
        ));
  }
}
