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
        // Table Row do not yet support a height attribute, hence we need to use the SizedBox
        // workaround. see also https://github.com/flutter/flutter/issues/36936
        TableRow(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
            Text('Funding Rate', style: TextStyle(fontSize: 20)),
            SizedBox(height: 15, width: 0)
          ]),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(
              children: [
                const Icon(Icons.currency_bitcoin),
                Text('$fundingRate', style: const TextStyle(fontSize: 20)),
              ],
            )
          ]),
        ]),
        TableRow(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
            Text('Margin', style: TextStyle(fontSize: 20)),
            SizedBox(height: 15, width: 0)
          ]),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(
              children: [
                const Icon(Icons.currency_bitcoin),
                Text('$margin', style: const TextStyle(fontSize: 20)),
              ],
            )
          ]),
        ]),
        TableRow(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
            Text('Expiry', style: TextStyle(fontSize: 20)),
            SizedBox(height: 15, width: 0)
          ]),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(DateFormat('dd.MM.yy-kk:mm').format(expiry), style: const TextStyle(fontSize: 20))
          ]),
        ]),
        TableRow(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
            Text('Liquidation Price', style: TextStyle(fontSize: 20)),
            SizedBox(height: 15, width: 0)
          ]),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(
              children: [
                Text('\$$fmtLiquidationPrice', style: const TextStyle(fontSize: 20)),
              ],
            )
          ]),
        ]),
      ],
    );
  }
}
