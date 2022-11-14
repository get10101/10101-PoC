import 'package:flutter/material.dart';

import '../model/payment.dart';

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

    final amountDisplay = data.amount.display(sign: true);

    return ListTile(
      leading: statusIcon,
      title: Text(data.type.display),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(amountDisplay.value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text(amountDisplay.label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        ],
      ),
    );
  }
}
