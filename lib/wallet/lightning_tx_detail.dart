import 'package:flutter/material.dart' hide Flow;
import 'package:intl/intl.dart';
import 'package:ten_ten_one/bridge_generated/bridge_definitions.dart';
import 'package:ten_ten_one/utilities/tto_table.dart';

class LightningTxDetail extends StatelessWidget {
  static const subRouteName = 'ldk-tx';

  final LightningTransaction transaction;

  const LightningTxDetail({required this.transaction, super.key});

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat();
    formatter.minimumFractionDigits = 0;
    formatter.maximumFractionDigits = 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Lightning Payment Detail')),
      body: SafeArea(
        child: Container(
            padding: const EdgeInsets.all(20.0),
            child: TtoTable([
              TtoRow(
                  label: "Timestamp",
                  value: DateFormat('dd.MM.yy-kk:mm')
                      .format(DateTime.fromMillisecondsSinceEpoch(transaction.timestamp * 1000)),
                  type: ValueType.date),
              TtoRow(
                  label: transaction.flow == Flow.Inbound ? "Received" : "Sent",
                  value: formatter.format(transaction.sats),
                  type: ValueType.satoshi),
              TtoRow(label: "Type", value: transaction.txType.name, type: ValueType.text),
              TtoRow(label: "Status", value: transaction.status.name, type: ValueType.text),
            ])),
      ),
    );
  }
}
