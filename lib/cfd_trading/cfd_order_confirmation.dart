import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CfdOrderConfirmation extends StatelessWidget {
  static const subRouteName = 'cfd-order-confirmation';

  const CfdOrderConfirmation({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.decimalPattern('en');

    const margin = 0.0025;
    const openPrice = 19656;
    final fmtOpenPrice = formatter.format(openPrice);

    const liquidationPrice = 13104;
    final fmtLiquidationPrice = formatter.format(liquidationPrice);

    final expiry = DateTime.now();

    return Scaffold(
        appBar: AppBar(title: const Text('CFD Order Confirmation')),
        body: Container(
          padding: const EdgeInsets.only(top: 15, right: 30, left: 30),
          child: Column(children: [
            const Center(child: Text('BTCUSD', style: TextStyle(fontSize: 24))),
            const SizedBox(height: 25),
            Table(
              children: [
                buildRow('Position', 'Long', false),
                buildRow('Open Price', '\$$fmtOpenPrice', false),
                buildRow('Unrealized P/L', '-0.00005566', true),
                buildRow('Margin', '$margin', true),
                buildRow('Expiry', DateFormat('dd.MM.yy-kk:mm').format(expiry), false),
                buildRow('Liquidation Price', '\$$fmtLiquidationPrice', false),
                buildRow('Contracts', '100', false),
                buildRow('Estimated fees', '-0.0000000040', true)
              ],
            ),
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

  TableRow buildRow(String label, String value, bool bitcoin) {
    return TableRow(children: [
      // Table Row do not yet support a height attribute, hence we need to use the SizedBox
      // workaround. see also https://github.com/flutter/flutter/issues/36936
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 15, width: 0)
      ]),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(
          children: [
            bitcoin ? const Icon(Icons.currency_bitcoin) : const SizedBox(),
            Text(value, style: const TextStyle(fontSize: 20)),
          ],
        )
      ]),
    ]);
  }
}
