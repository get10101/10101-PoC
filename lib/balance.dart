import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'model/balance_model.dart';

enum BalanceSelector { bitcoin, lightning, both }

class Balance extends StatelessWidget {
  const Balance({required this.balanceSelector, Key? key}) : super(key: key);

  final BalanceSelector balanceSelector;

  @override
  Widget build(BuildContext context) {
    return Consumer2<LightningBalance, BitcoinBalance>(
      builder: (context, lightningBalance, bitcoinBalance, child) {
        var bitcoinBalanceDisplay = bitcoinBalance.amount.display();
        var lightningBalanceDisplay = lightningBalance.amount.display();

        var bitcoinBalanceWidget = BalanceRow(
            value: bitcoinBalanceDisplay.value,
            label: bitcoinBalanceDisplay.label,
            icon: Icons.currency_bitcoin_outlined,
            smaller: balanceSelector == BalanceSelector.both);
        var lightningBalanceWidget = BalanceRow(
            value: lightningBalanceDisplay.value,
            label: lightningBalanceDisplay.label,
            icon: Icons.bolt_outlined,
            smaller: balanceSelector == BalanceSelector.both);

        var balanceWidgets = Column();

        switch (balanceSelector) {
          case BalanceSelector.bitcoin:
            balanceWidgets = Column(children: [bitcoinBalanceWidget]);
            break;
          case BalanceSelector.lightning:
            balanceWidgets = Column(children: [lightningBalanceWidget]);
            break;
          case BalanceSelector.both:
            balanceWidgets = Column(children: [lightningBalanceWidget, bitcoinBalanceWidget]);
            break;
        }

        return Container(
          margin: const EdgeInsets.only(top: 15),
          child: balanceWidgets,
        );
      },
    );
  }
}

class BalanceRow extends StatelessWidget {
  const BalanceRow(
      {required this.value,
      required this.label,
      required this.icon,
      required this.smaller,
      Key? key})
      : super(key: key);

  final String value;
  final String label;
  final bool smaller;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final balanceFontSize = smaller ? 32.0 : 36.0;
    final labelFontSize = smaller ? 16.0 : 18.0;

    return Center(
        child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Icon(icon),
        Text(value,
            key: const Key('bitcoinBalance'),
            style: TextStyle(fontSize: balanceFontSize, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(fontSize: labelFontSize, color: Colors.grey)),
      ],
    ));
  }
}
