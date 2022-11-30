import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ten_ten_one/bridge_generated/bridge_definitions.dart';
import 'package:ten_ten_one/utilities/tto_table.dart';

import 'package:ten_ten_one/ffi.io.dart' if (dart.library.html) 'ffi.web.dart';

class BitcoinTxDetail extends StatelessWidget {
  static const subRouteName = 'btc-tx';

  final BitcoinTxHistoryItem transaction;

  const BitcoinTxDetail({required this.transaction, super.key});

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat();
    formatter.minimumFractionDigits = 0;
    formatter.maximumFractionDigits = 0;

    String explorerUrl = "";
    switch (api.network()) {
      case "regtest":
        explorerUrl = "http://localhost:5000/tx";
        break;
      case "testnet":
        explorerUrl = "https://mempool.space/testnet/tx";
        break;
      case "mainnet":
        explorerUrl = "https://mempool.space/tx";
        break;
      default:
        explorerUrl = "https://mempool.space/tx";
        break;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Bitcoin Transaction Detail')),
      body: SafeArea(
        child: Container(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                TtoTable([
                  TtoRow(
                      label: "Transaction Id",
                      value: transaction.txid.substring(0, 5) +
                          "..." +
                          transaction.txid
                              .substring(transaction.txid.length - 4, transaction.txid.length),
                      type: ValueType.link,
                      meta: explorerUrl + "/" + transaction.txid),
                  TtoRow(
                      label: "Timestamp",
                      value: DateFormat('dd.MM.yy-kk:mm').format(
                          DateTime.fromMillisecondsSinceEpoch(transaction.timestamp * 1000)),
                      type: ValueType.date),
                  TtoRow(
                      label: "Fees",
                      value: formatter.format(transaction.fee),
                      type: ValueType.satoshi),
                  TtoRow(
                      label: "Confirmed",
                      value: transaction.isConfirmed.toString(),
                      type: ValueType.text),
                  TtoRow(
                      label: transaction.sent > 0 ? "Sent" : "Received",
                      value: formatter.format(transaction.sent > 0
                          ? (transaction.sent - transaction.received - transaction.fee)
                          : transaction.received),
                      type: ValueType.satoshi),
                ])
              ],
            )),
      ),
    );
  }
}
