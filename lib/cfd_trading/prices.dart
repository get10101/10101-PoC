import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class Prices extends StatelessWidget {
  final int bid;
  final int ask;
  final int index;

  const Prices(this.bid, this.ask, this.index, {super.key});

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.decimalPattern('en');
    final fmtBid = formatter.format(bid);
    final fmtAsk = formatter.format(ask);
    final fmtIndex = formatter.format(index);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Text("bid $fmtBid"),
        Text("ask $fmtAsk"),
        Text("index $fmtIndex"),
      ],
    );
  }
}
