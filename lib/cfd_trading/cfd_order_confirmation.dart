import 'package:f_logs/model/flog/flog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:ten_ten_one/bridge_generated/bridge_definitions.dart';
import 'package:ten_ten_one/cfd_trading/cfd_trading.dart';
import 'package:ten_ten_one/cfd_trading/validation_error.dart';
import 'package:ten_ten_one/models/amount.model.dart';
import 'package:ten_ten_one/cfd_trading/cfd_trading_change_notifier.dart';
import 'package:ten_ten_one/utilities/tto_table.dart';

import 'package:ten_ten_one/ffi.io.dart' if (dart.library.html) 'ffi.web.dart';

class CfdOrderConfirmationArgs {
  Order order;
  Message? channelError;

  CfdOrderConfirmationArgs(this.order, this.channelError);
}

class CfdOrderConfirmation extends StatefulWidget {
  static const subRouteName = 'cfd-order-confirmation';

  final CfdOrderConfirmationArgs args;

  const CfdOrderConfirmation({super.key, required this.args});

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
    final formatter = NumberFormat();
    formatter.minimumFractionDigits = 2;
    formatter.maximumFractionDigits = 2;

    final cfdTradingService = context.read<CfdTradingChangeNotifier>();
    final cfdTradingChangeNotifier = context.read<CfdTradingChangeNotifier>();
    Order order = widget.args.order;
    Message? channelError = widget.args.channelError;

    final openPrice = formatter.format(order.openPrice);

    final liquidationPrice = formatter.format(order.calculateLiquidationPrice());

    final estimatedFees = Amount(txFee).display(currency: Currency.sat).value;
    final margin = Amount.fromBtc(order.marginTaker()).display(currency: Currency.sat).value;
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
            Center(
                child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Column(
                      children: [
                        Text(quantity + ' ' + contractSymbol,
                            style: const TextStyle(
                                fontSize: 20, letterSpacing: 1, fontWeight: FontWeight.w600)),
                        const Text('@',
                            style: TextStyle(
                                color: Colors.grey,
                                fontSize: 20,
                                letterSpacing: 1,
                                fontWeight: FontWeight.w600)),
                        Text('\$' + openPrice,
                            style: const TextStyle(
                                fontSize: 20, letterSpacing: 1, fontWeight: FontWeight.w600))
                      ],
                    ))),
            const SizedBox(height: 25),
            Expanded(
              child: TtoTable([
                TtoRow(
                    label: 'Position',
                    value: 'x' + order.leverage.toString() + ' ' + order.position.name,
                    type: ValueType.text),
                // TtoRow(label: 'Quantity', value: quantity, type: ValueType.text),
                // TtoRow(label: 'Leverage', value: order.leverage.toString(), type: ValueType.text),
                TtoRow(label: 'Margin', value: margin, type: ValueType.satoshi),
                // TtoRow(label: 'Opening Price', value: openPrice, type: ValueType.usd),
                TtoRow(label: 'Liquidation Price', value: liquidationPrice, type: ValueType.usd),
                TtoRow(label: 'Estimated fees', value: estimatedFees, type: ValueType.satoshi),
                TtoRow(label: 'Expiry', value: expiry, type: ValueType.date)
              ]),
            ),
            Center(
              child: channelError == null
                  ? AlertMessage(
                      message: Message(
                          title:
                              'This will open a position and lock up $margin sats in the channel. Would you like to proceed?',
                          type: AlertType.info))
                  : AlertMessage(message: channelError),
            ),
            const SizedBox(height: 50),
          ]),
        ),
      ),
      floatingActionButton: ElevatedButton(
          onPressed: channelError == null
              ? () async {
                  try {
                    await api.openCfd(order: order);
                    FLog.info(text: 'OpenCfd returned successfully');

                    // clear draft order from cfd service state
                    cfdTradingChangeNotifier.draftOrder = null;

                    // switch index to cfd overview tab
                    cfdTradingChangeNotifier.selectedIndex = 1;

                    // refreshing cfd list after cfd has been opened
                    // will also implicitly propagate the index change
                    await cfdTradingService.refreshCfdList();

                    // navigate back to the trading route where the index has already been propagated
                    context.go(CfdTrading.route);
                  } on FfiException catch (error) {
                    FLog.error(text: 'Failed to open CFD: ' + error.message, exception: error);

                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      backgroundColor: Colors.red,
                      content: Text("Failed to open cfd"),
                    ));

                    return;
                  }

                  context.go(CfdTrading.route);
                }
              : null,
          child: const Text('Confirm')),
    );
  }
}
