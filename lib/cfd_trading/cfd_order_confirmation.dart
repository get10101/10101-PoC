import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ten_ten_one/utilities/tto_table.dart';

class CfdOrderConfirmation extends StatelessWidget {
  static const subRouteName = 'cfd-order-confirmation';

  const CfdOrderConfirmation({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.decimalPattern('en');

    // mock data
    const margin = 0.0025;
    const openPrice = 19656;
    const unrealizedPL = -0.00005566;
    const liquidationPrice = 13104;
    final expiry = DateTime.now();
    const contracts = 100;
    const double estimatedFees = -0.0000000004;

    final fmtOpenPrice = formatter.format(openPrice);
    final fmtLiquidationPrice = formatter.format(liquidationPrice);
    final fmtEstimatedFees = estimatedFees.toStringAsFixed(10);
    final fmtMargin = margin.toStringAsFixed(10);
    final fmtUnrealizedPL = unrealizedPL.toStringAsFixed(10);

    return Scaffold(
        appBar: AppBar(title: const Text('CFD Order Confirmation')),
        body: Container(
          padding: const EdgeInsets.only(top: 15, right: 30, left: 30),
          child: Column(children: [
            const Center(child: Text('BTCUSD', style: TextStyle(fontSize: 24))),
            const SizedBox(height: 25),
            TtoTable([
              const TtoRow(label: 'Position', value: 'Long'),
              TtoRow(label: 'Open Price', value: '\$ $fmtOpenPrice'),
              TtoRow(label: 'Unrealized P/L', value: fmtUnrealizedPL, icon: Icons.currency_bitcoin),
              TtoRow(label: 'Margin', value: fmtMargin, icon: Icons.currency_bitcoin),
              TtoRow(label: 'Expiry', value: DateFormat('dd.MM.yy-kk:mm').format(expiry)),
              TtoRow(label: 'Liquidation Price', value: '\$ $fmtLiquidationPrice'),
              const TtoRow(label: 'Contracts', value: '$contracts'),
              TtoRow(label: 'Estimated fees', value: fmtEstimatedFees, icon: Icons.currency_bitcoin)
            ]),
            const SizedBox(height: 20),
            const Text(
                'This will open a position and lock up $margin BTC in a channel. Would you like to proceed',
                style: TextStyle(fontSize: 20)),
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(0, 0, 20, 30),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [ElevatedButton(onPressed: () {}, child: const Text('Confirm'))],
                    ),
                  ],
                ),
              ),
            )
          ]),
        ));
  }
}
