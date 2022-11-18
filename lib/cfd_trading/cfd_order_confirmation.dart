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

class CfdOrderConfirmation extends StatefulWidget {
  static const subRouteName = 'cfd-order-confirmation';

  final Order? order;

  const CfdOrderConfirmation({this.order, super.key});

  @override
  State<CfdOrderConfirmation> createState() => _CfdOrderConfirmationState();
}

class _CfdOrderConfirmationState extends State<CfdOrderConfirmation> {
  int txFee = 0;

  @override
  void initState() {
    super.initState();
    setFee();
  }

  Future<void> setFee() async {
    final recommendedFeeRate = await api.getFeeRecommendation();
    const estimatedVbytes = 500;
    setState(() {
      txFee = recommendedFeeRate * estimatedVbytes;
    });
  }

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.decimalPattern('en');

    final cfdTradingService = context.read<CfdTradingChangeNotifier>();

    final cfdTradingChangeNotifier = context.read<CfdTradingChangeNotifier>();
    Order order = widget.order!;

    final openPrice = formatter.format(order.openPrice);

    final liquidationPrice = formatter.format(order.calculateLiquidationPrice());

    final estimatedFees = Amount(fastestFee).display(currency: Currency.btc).value;
    final margin = Amount.fromDouble(order.calculateMargin()).display(currency: Currency.btc).value;
    final expiry = DateFormat('dd.MM.yy-kk:mm')
        .format(DateTime.fromMillisecondsSinceEpoch((order.calculateExpiry() * 1000)));

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
                TtoRow(label: 'Margin', value: margin, type: ValueType.satoshi),
                TtoRow(label: 'Expiry', value: expiry, type: ValueType.satoshi),
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
                                try {
                                  await api.openCfd(order: order);
                                  FLog.info(text: 'OpenCfd returned successfully');

                                  // refreshing cfd list after cfd has been opened
                                  await cfdTradingService.refreshCfdList();

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

                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                    backgroundColor: Colors.red,
                                    content: Text("Failed to open cfd"),
                                  ));
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
