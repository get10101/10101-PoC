import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ten_ten_one/models/amount.model.dart';

import 'models/balance_model.dart';

enum BalanceSelector { bitcoin, lightning, both }

class Balance extends StatelessWidget {
  const Balance({required this.balanceSelector, Key? key}) : super(key: key);

  final BalanceSelector balanceSelector;

  @override
  Widget build(BuildContext context) {
    return Consumer2<LightningBalance, BitcoinBalance>(
      builder: (context, lightningBalance, bitcoinBalance, child) {
        var bitcoinBalanceTotalDisplay = bitcoinBalance.total().display(currency: Currency.sat);
        var bitcoinBalanceConfirmedDisplay =
            bitcoinBalance.confirmed.display(currency: Currency.sat);
        var bitcoinBalancePendingDisplay = bitcoinBalance.pending().display(currency: Currency.sat);

        var lightningBalanceDisplay = lightningBalance.amount.display(currency: Currency.sat);

        var bitcoinBalanceWidget = Tooltip(
            richMessage: TextSpan(
              text: 'Confirmed: ${bitcoinBalanceConfirmedDisplay.value} sats',
              style: const TextStyle(fontWeight: FontWeight.bold),
              children: [
                TextSpan(
                  text: '\nPending:      ${bitcoinBalancePendingDisplay.value} sats',
                  style: const TextStyle(fontWeight: FontWeight.normal),
                )
              ],
            ),
            child: BalanceRow(
                value: bitcoinBalanceTotalDisplay.value,
                unit: bitcoinBalanceTotalDisplay.unit,
                icon: Icons.link,
                smaller: balanceSelector == BalanceSelector.both));
        var lightningBalanceWidget = BalanceRow(
            value: lightningBalanceDisplay.value,
            unit: lightningBalanceDisplay.unit,
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

        return balanceWidgets;
      },
    );
  }
}

class BalanceRow extends StatelessWidget {
  const BalanceRow(
      {required this.value,
      required this.unit,
      required this.icon,
      required this.smaller,
      Key? key})
      : super(key: key);

  final String value;
  final AmountUnit unit;
  final bool smaller;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final balanceFontSize = smaller ? 26.0 : 32.0;
    final iconSize = smaller ? 24.0 : 28.0;

    return Center(
        child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Icon(icon, size: 32),
        AmountItem(
          text: value,
          unit: unit,
          iconColor: Colors.grey,
          iconSize: iconSize,
          fontSize: balanceFontSize,
        )
      ],
    ));
  }
}
