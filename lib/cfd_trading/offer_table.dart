import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class OfferTable extends StatelessWidget {
  final double fundingRate;
  final double margin;
  final DateTime expiry;
  final int liquidationPrice;

  const OfferTable(this.fundingRate, this.margin, this.expiry, this.liquidationPrice, {super.key});

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.decimalPattern('en');
    final fmtLiquidationPrice = formatter.format(liquidationPrice);

    return Table(
      children: [
        buildRow('Funding Rate', '$fundingRate', true),
        buildRow('Margin', '$margin', true),
        buildRow('Expiry', DateFormat('dd.MM.yy-kk:mm').format(expiry), false),
        buildRow('Liquidation Price', '\$$fmtLiquidationPrice', false)
      ],
    );
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
