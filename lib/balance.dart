import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'models/balance_model.dart';

class Balance extends StatelessWidget {
  const Balance({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.decimalPattern('en');
    return Consumer<BalanceModel>(
      builder: (context, balance, child) {
        var amountDisplay = balance.amount.display();
        return Container(
          margin: const EdgeInsets.only(top: 15),
          child: Column(
            children: [
              Center(
                  child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(formatter.format(amountDisplay.value),
                      key: const Key('balance'),
                      style: const TextStyle(fontSize: 42, fontWeight: FontWeight.bold)),
                  Text(amountDisplay.label,
                      style: const TextStyle(fontSize: 20, color: Colors.grey)),
                ],
              ))
            ],
          ),
        );
      },
    );
  }
}
