import 'package:ten_ten_one/cfd_trading/cfd_order_confirmation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:ten_ten_one/bridge_generated/bridge_definitions.dart' hide Balance;
import 'package:ten_ten_one/cfd_trading/cfd_offer_change_notifier.dart';
import 'package:ten_ten_one/cfd_trading/cfd_trading.dart';
import 'package:ten_ten_one/cfd_trading/position_selection.dart';
import 'package:ten_ten_one/cfd_trading/validation_error.dart';
import 'package:ten_ten_one/models/amount.model.dart';
import 'package:ten_ten_one/models/balance_model.dart';
import 'package:ten_ten_one/utilities/dropdown.dart';
import 'package:ten_ten_one/utilities/tto_table.dart';
import 'package:ten_ten_one/ffi.io.dart' if (dart.library.html) 'ffi.web.dart';

class CfdOffer extends StatefulWidget {
  static const leverages = [1, 2];

  const CfdOffer({Key? key}) : super(key: key);

  @override
  State<CfdOffer> createState() => _CfdOfferState();
}

class _CfdOfferState extends State<CfdOffer> {
  late int quantity;
  late int leverage;
  late Position position;

  @override
  void initState() {
    super.initState();

    quantity = 100;
    leverage = 2;
    position = Position.Long;
  }

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat();
    formatter.minimumFractionDigits = 2;
    formatter.maximumFractionDigits = 2;

    final cfdOffersChangeNotifier = context.watch<CfdOfferChangeNotifier>();
    final offer = cfdOffersChangeNotifier.offer ?? Offer(bid: 0, ask: 0, index: 0);

    final fmtBid = "\$" + formatter.format(offer.bid);
    final fmtAsk = "\$" + formatter.format(offer.ask);
    final fmtIndex = "\$" + formatter.format(offer.index);

    var order = Order(
        openPrice: position == Position.Long ? offer.ask : offer.bid,
        quantity: quantity,
        leverage: leverage,
        contractSymbol: ContractSymbol.BtcUsd,
        position: position,
        bridge: api);

    final liquidationPrice = formatter.format(order.calculateLiquidationPrice());
    final expiry = DateFormat('dd.MM.yy-kk:mm')
        .format(DateTime.fromMillisecondsSinceEpoch((order.calculateExpiry() * 1000)));
    final margin = Amount.fromBtc(order.marginTaker()).display(currency: Currency.sat).value;

    final balance = context.read<LightningBalance>().amount.asSats;
    final int takerAmount = Amount.fromBtc(order.marginTaker()).asSats;

    Message? channelError;
    if (balance == 0) {
      channelError = Message(
          title: 'No channel with 10101 maker',
          details: 'You need an open channel with the 10101 maker before you can open a CFD.',
          type: AlertType.warning);
    } else if (takerAmount > balance) {
      channelError = Message(
          title: 'Insufficient funds',
          details: 'The required margin is higher than the available balance.',
          type: AlertType.warning);
    }

    List<Widget> warnings = [];
    if (channelError != null) {
      warnings.addAll([
        Expanded(child: Container()),
        AlertMessage(message: channelError),
        const SizedBox(height: 80)
      ]);
    }

    List<Widget> widgets = [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Row(
            children: [
              const Text("bid:"),
              const SizedBox(width: 2),
              Text(fmtBid, style: const TextStyle(fontWeight: FontWeight.w600))
            ],
          ),
          Row(
            children: [
              const Text("ask:"),
              const SizedBox(width: 2),
              Text(fmtAsk, style: const TextStyle(fontWeight: FontWeight.w600))
            ],
          ),
          Row(
            children: [
              const Text("index:"),
              const SizedBox(width: 2),
              Text(fmtIndex, style: const TextStyle(fontWeight: FontWeight.w600))
            ],
          ),
        ],
      ),
      const SizedBox(height: 30),
      PositionSelection(
          onChange: (position) {
            setState(() {
              position = position;
            });
          },
          value: order.position),
      const SizedBox(height: 15),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Dropdown(
          values: List<int>.generate(10, (i) => (i + 1) * 100)
              .map((quantity) => quantity.toString())
              .toList(),
          onChange: (contracts) {
            setState(() {
              quantity = int.parse(contracts!);
            });
          },
          value: order.quantity.toString(),
        ),
        Dropdown(
            values: [ContractSymbol.BtcUsd.name.toUpperCase()],
            onChange: (contractSymbol) {
              order.contractSymbol =
                  ContractSymbol.values.firstWhere((e) => e.name == contractSymbol!.toLowerCase());
            },
            value: order.contractSymbol.name.toUpperCase()),
        Dropdown(
            values: CfdOffer.leverages.map((l) => 'x$l').toList(),
            onChange: (lev) {
              setState(() {
                leverage = int.parse(lev!.substring(1));
              });
            },
            value: 'x' + order.leverage.toString()),
      ]),
      Column(mainAxisAlignment: MainAxisAlignment.start, children: <Widget>[
        Container(
          margin: const EdgeInsets.only(top: 25),
          child: TtoTable([
            TtoRow(
                label: 'Liquidation Price',
                value: liquidationPrice.toString(),
                type: ValueType.usd),
            TtoRow(label: 'Margin', value: margin, type: ValueType.satoshi),
            TtoRow(label: 'Expiry', value: expiry, type: ValueType.date),
          ]),
        )
      ]),
    ];

    widgets.addAll(warnings);

    return Scaffold(
      body: Container(
          padding: const EdgeInsets.only(left: 25, right: 25), child: Column(children: widgets)),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          GoRouter.of(context).go(
            CfdTrading.route + '/' + CfdOrderConfirmation.subRouteName,
            extra: CfdOrderConfirmationArgs(order, channelError),
          );
        },
        child: const Icon(Icons.shopping_cart_checkout),
      ),
    );
  }
}
