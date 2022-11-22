import 'package:flutter/material.dart' hide Divider;
import 'package:ten_ten_one/utilities/divider.dart';

import 'package:ten_ten_one/balance.dart';

extension BalanceSelectorExtension on BalanceSelector {
  static const preferredHeightVals = {
    BalanceSelector.both: 110.0,
    BalanceSelector.bitcoin: 90.0,
    BalanceSelector.lightning: 90.0,
  };

  double get preferredHeight => preferredHeightVals[this]!;
}

class AppBarWithBalance extends StatelessWidget {
  const AppBarWithBalance({
    required this.balanceSelector,
    Key? key,
  }) : super(key: key);

  final BalanceSelector balanceSelector;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(children: [
          AppBar(
            elevation: 0,
            backgroundColor: Colors.transparent,
            iconTheme: const IconThemeData(color: Colors.black),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 20.0, bottom: 10.0),
            child: Balance(balanceSelector: balanceSelector),
          )
        ]),
        const Padding(
          padding: EdgeInsets.only(left: 20.0, right: 20.0),
          child: Divider(),
        )
      ],
    );
  }
}
