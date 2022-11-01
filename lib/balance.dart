import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'models/balance.model.dart';

class Balance extends StatelessWidget {
  const Balance({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var formatter = NumberFormat.decimalPattern('en');
    return Consumer<BalanceModel>(
      builder: (context, balance, child) {
        return Container(
          padding: const EdgeInsets.only(top: 8.0, left: 8.0, right: 8.0),
          child: Column(
            children: [
              Center(
                  child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(formatter.format(balance.amount),
                      key: const Key('balance'),
                      style: const TextStyle(fontSize: 42, fontWeight: FontWeight.bold)),
                  const Text('sat', style: TextStyle(fontSize: 20, color: Colors.grey)),
                ],
              )),
              const Divider(
                height: 30,
                thickness: 7,
                color: Colors.grey,
                indent: 30,
                endIndent: 30,
              )
            ],
          ),
        );
      },
    );
  }
}
