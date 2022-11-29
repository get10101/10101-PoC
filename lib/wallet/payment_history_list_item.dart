import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ten_ten_one/models/amount.model.dart';
import 'dart:math' as math;

import 'package:ten_ten_one/models/payment.model.dart';
import 'package:ten_ten_one/wallet/bitcoin_tx_detail.dart';

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
    var layer = "on-chain";
    var layerIcon = Icons.link;
    switch (data.type) {
      case PaymentType.receive:
        statusIcon = receiveOffChainIcon();
        layer = "off-chain";
        layerIcon = Icons.bolt;
        break;
      case PaymentType.receiveOnChain:
        statusIcon = receiveOnChainIcon();
        layer = "on-chain";
        layerIcon = Icons.link;
        break;
      case PaymentType.send:
        statusIcon = sendOffChainIcon();
        layer = "off-chain";
        layerIcon = Icons.bolt;
        break;
      case PaymentType.sendOnChain:
        statusIcon = sendOnChainIcon();
        layer = "on-chain";
        layerIcon = Icons.link;
        break;
      case PaymentType.cfdOpen:
        statusIcon = cfdOpenIcon();
        layer = "off-chain";
        layerIcon = Icons.bolt;
        break;
      case PaymentType.cfdClose:
        statusIcon = cfdClosedIcon();
        layer = "off-chain";
        layerIcon = Icons.bolt;
        break;
      case PaymentType.channelOpen:
        statusIcon = channelOpenIcon();
        layer = "on-chain";
        layerIcon = Icons.bolt;
        break;
      case PaymentType.channelClose:
        statusIcon = channelClosedIcon();
        layer = "on-chain";
        layerIcon = Icons.link;
        break;
      case PaymentType.sportsbetOpen:
      case PaymentType.sportsbetClose:
        // TODO: Handle these cases.
        statusIcon = Icon(Icons.check_circle_outline, color: Colors.green[800]);
        layer = "off-chain";
        layerIcon = Icons.bolt;
        break;
    }

    switch (data.status) {
      case PaymentStatus.pending:
        statusIcon = const SizedBox(width: 20, height: 20, child: CircularProgressIndicator());
        break;
      case PaymentStatus.failed:
        statusIcon = Icon(FontAwesomeIcons.xmark, color: Colors.red[800]);
        break;
      case PaymentStatus.finalized:
        // Already handled by data type switch statement
        break;
    }

    final amountDisplay = data.amount.display(sign: true, currency: Currency.sat);

    final date = data.status == PaymentStatus.pending
        ? "pending"
        : DateFormat("MMM d, ''yy H:mm")
            .format(DateTime.fromMicrosecondsSinceEpoch(data.timestamp.toInt() * 1000 * 1000));
    return Column(children: [
      const Divider(),
      GestureDetector(
        onTap: () {
          GoRouter.of(context).go(
            '/' + BitcoinTxDetail.subRouteName,
            extra: data.data,
          );
        },
        child: ListTile(
            leading: statusIcon,
            title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(data.type.display,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Row(children: [Icon(layerIcon), Text(layer)]),
                ]),
            dense: true,
            minLeadingWidth: 0,
            contentPadding: const EdgeInsets.only(left: 0.0, right: 0.0),
            trailing: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      AmountItem(
                          text: amountDisplay.value,
                          unit: AmountUnit.satoshi,
                          iconColor: Colors.grey)
                    ],
                  ),
                  Text(date),
                ])),
      ),
    ]);
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

  // TODO: come up with a lightning receive icon
  Transform receiveOffChainIcon() {
    return Transform.rotate(
        angle: -135 * math.pi / 180,
        child: Icon(
          FontAwesomeIcons.arrowLeft,
          color: Colors.green[800],
        ));
  }

  // TODO: come up with a lightning send icon
  Transform sendOffChainIcon() {
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
