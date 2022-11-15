import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:math' as math;

import '../models/payment.model.dart';

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
        switch (data.type) {
          case PaymentType.receive:
          case PaymentType.deposit:
            statusIcon = Transform.rotate(
              angle: -135 * math.pi / 180,
              child: IconButton(
                icon: Icon(
                  FontAwesomeIcons.arrowLeft,
                  color: Colors.red[800],
                ),
                onPressed: null,
              ),
            );
            break;
          case PaymentType.send:
          case PaymentType.withdraw:
            statusIcon = Transform.rotate(
              angle: 135 * math.pi / 180,
              child: IconButton(
                icon: Icon(
                  FontAwesomeIcons.arrowLeft,
                  color: Colors.green[800],
                ),
                onPressed: null,
              ),
            );
            break;
          case PaymentType.channelOpen:
          case PaymentType.channelClose:
          case PaymentType.cfdOpen:
          case PaymentType.cfdClose:
          case PaymentType.sportsbetOpen:
          case PaymentType.sportsbetClose:
            // TODO: Handle these cases.
            statusIcon = Icon(Icons.check_circle_outline, color: Colors.green[800]);
            break;
        }
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
