import 'package:f_logs/model/flog/flog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:ten_ten_one/bridge_generated/bridge_definitions.dart';
import 'package:ten_ten_one/cfd_trading/cfd_trading.dart';
import 'package:ten_ten_one/models/amount.model.dart';
import 'package:ten_ten_one/cfd_trading/cfd_trading_change_notifier.dart';
import 'package:ten_ten_one/utilities/tto_table.dart';

import 'package:ten_ten_one/ffi.io.dart' if (dart.library.html) 'ffi.web.dart';

class CfdOrderConfirmation extends StatelessWidget {
  static const subRouteName = 'cfd-order-confirmation';

  final Order? order;

  const CfdOrderConfirmation({this.order, super.key});

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.decimalPattern('en');

    final cfdTradingChangeNotifier = context.read<CfdTradingChangeNotifier>();
    Order order = this.order!;

    final openPrice = formatter.format(order.openPrice);
    final liquidationPrice = formatter.format(api.calculateLiquidationPrice(
        initialPrice: order.openPrice,
        leverage: order.leverage,
        contractSymbol: order.contractSymbol,
        position: order.position));
    // TODO: Calculate or remove?
    final estimatedFees = Amount.zero.display(currency: Currency.sat).value;
    // TODO: Calculate
    final margin = Amount.zero.display(currency: Currency.sat).value;
    // TODO: Calculate
    final unrealizedPL = Amount.zero.display(currency: Currency.sat).value;
    final now = DateTime.now();
    final expiry = DateTime(now.year, now.month, now.day + 1);
    final quantity = order.quantity.toString();
    final contractSymbol = order.contractSymbol.name.toUpperCase();

    return Scaffold(
        appBar: AppBar(title: const Text('CFD Order Confirmation')),
        body: SafeArea(
          child: Container(
            padding: const EdgeInsets.all(20.0),
            child: Column(children: [
              Center(child: Text(contractSymbol, style: const TextStyle(fontSize: 16))),
              const SizedBox(height: 25),
              TtoTable([
                TtoRow(
                    label: 'Position',
                    value: order.position == Position.Long ? 'Long' : 'Short',
                    type: ValueType.satoshi),
                TtoRow(label: 'Opening Price', value: openPrice, type: ValueType.usd),
                TtoRow(label: 'Unrealized P/L', value: unrealizedPL, type: ValueType.satoshi),
                TtoRow(label: 'Margin', value: margin, type: ValueType.satoshi),
                TtoRow(
                    label: 'Expiry',
                    value: DateFormat('dd.MM.yy-kk:mm').format(expiry),
                    type: ValueType.satoshi),
                TtoRow(label: 'Liquidation Price', value: liquidationPrice, type: ValueType.usd),
                TtoRow(label: 'Quantity', value: quantity, type: ValueType.satoshi),
                TtoRow(label: 'Estimated fees', value: estimatedFees, type: ValueType.satoshi)
              ]),
              const SizedBox(height: 20),
              Text(
                  'This will open a position and lock up $margin BTC in a channel. Would you like to proceed?',
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
                                // TODO: Plug in actual state changes

                                try {
                                  // TODO: Don't hardcode the taker amount
                                  await api.openCfd(order: order);
                                  FLog.info(text: 'OpenCfd returned successfully');

                                  // clear draft order from cfd service state
                                  cfdTradingChangeNotifier.draftOrder = null;

                                  // switch index to cfd overview tab
                                  cfdTradingChangeNotifier.selectedIndex = 1;
                                  // propagate the index change
                                  cfdTradingChangeNotifier.notify();
                                  // trigger CFD list update
                                  cfdTradingChangeNotifier.update();

                                  // navigate back to the trading route where the index has already been propagated
                                  context.go(CfdTrading.route);
                                } on FfiException catch (error) {
                                  FLog.error(
                                      text: 'Failed to open CFD: ' + error.message,
                                      exception: error);

                                  // TODO display error that CFD open failed in UI
                                }
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
