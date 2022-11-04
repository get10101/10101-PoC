import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'models/payment.model.dart';

@immutable
class PaymentHistoryListItem extends StatelessWidget {
  final PaymentHistoryItem data;

  const PaymentHistoryListItem({
    super.key,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    Widget statusIcon;
    switch (data.status) {
      case PaymentStatus.pending:
        statusIcon = const CircularProgressIndicator();
        break;
      case PaymentStatus.finalized:
        statusIcon = Icon(Icons.check_circle_outline, color: Colors.green[800]);
        break;
    }

    final amountDisplay = data.amount.display();

    String label;
    switch (data.type) {
      case PaymentType.send:
        label = "Payment Sent";
        break;
      case PaymentType.receive:
        label = "Payment Received";
        break;
      case PaymentType.cfdOpen:
        label = "CFD Opened";
        break;
      case PaymentType.cfdClose:
        label = "CFD Closed";
        break;
      case PaymentType.sportsbetOpen:
        label = "Sports Bet Started";
        break;
      case PaymentType.sportsbetClose:
        label = "Sports Bet Ended";
        break;
    }

    var formatter = NumberFormat.decimalPattern('en');

    return ListTile(
      leading: statusIcon,
      title: Text(label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(formatter.format(amountDisplay.value),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text(amountDisplay.label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        ],
      ),
    );
  }
}
