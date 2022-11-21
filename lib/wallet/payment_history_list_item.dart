import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:ten_ten_one/models/amount.model.dart';
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
        statusIcon = const SizedBox(width: 20, height: 20, child: CircularProgressIndicator());
        break;
      case PaymentStatus.finalized:
        switch (data.type) {
          case PaymentType.receive:
          case PaymentType.receiveOnChain:
            statusIcon = receiveOnChainIcon();
            break;
          case PaymentType.send:
          case PaymentType.sendOnChain:
            statusIcon = sendOnChainIcon();
            break;
          case PaymentType.cfdOpen:
            statusIcon = cfdOpenIcon();
            break;
          case PaymentType.cfdClose:
            statusIcon = cfdClosedIcon();
            break;
          case PaymentType.channelOpen:
            statusIcon = channelOpenIcon();
            break;
          case PaymentType.channelClose:
            statusIcon = channelClosedIcon();
            break;
          case PaymentType.sportsbetOpen:
          case PaymentType.sportsbetClose:
            // TODO: Handle these cases.
            statusIcon = Icon(Icons.check_circle_outline, color: Colors.green[800]);
            break;
        }
        break;
      case PaymentStatus.failed:
        statusIcon = Icon(FontAwesomeIcons.xmark, color: Colors.red[800]);
        break;
    }

    final amountDisplay = data.amount.display(sign: true, currency: Currency.sat);

    return ListTile(
      leading: statusIcon,
      title: Text(data.type.display),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          AmountItem(text: amountDisplay.value, unit: AmountUnit.satoshi, iconColor: Colors.grey)
        ],
      ),
    );
  }

  Transform receiveOnChainIcon() {
    return Transform.rotate(
        angle: -135 * math.pi / 180,
        child: Icon(
          FontAwesomeIcons.arrowLeft,
          color: Colors.green[800],
        ));
  }

  Transform sendOnChainIcon() {
    return Transform.rotate(
      angle: 135 * math.pi / 180,
      child: Icon(
        FontAwesomeIcons.arrowLeft,
        color: Colors.red[800],
      ),
    );
  }

  Icon cfdOpenIcon() {
    return Icon(
      Icons.shopping_cart_checkout,
      color: Colors.orange[800],
    );
  }

  Icon cfdClosedIcon() {
    return Icon(
      Icons.remove_shopping_cart,
      color: Colors.orange[800],
    );
  }

  Icon channelOpenIcon() {
    return Icon(
      FontAwesomeIcons.bolt,
      color: Colors.yellow[800],
    );
  }

  Icon channelClosedIcon() {
    return Icon(
      FontAwesomeIcons.link,
      color: Colors.grey[800],
    );
  }
}
