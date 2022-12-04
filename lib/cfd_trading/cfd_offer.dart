import 'package:flutter/services.dart';
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
import 'package:ten_ten_one/wallet/channel_change_notifier.dart';

class CfdOffer extends StatefulWidget {
  static const leverages = [1, 2, 3, 4, 5, 10];

  const CfdOffer({Key? key}) : super(key: key);

  @override
  State<CfdOffer> createState() => _CfdOfferState();
}

class _CfdOfferState extends State<CfdOffer> {
  late Order order;

  static const minQuantity = 1;
  static const maxQuantity = 1000;

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();

    order = Order(
        openPrice: 0,
        quantity: 10,
        leverage: 2,
        contractSymbol: ContractSymbol.BtcUsd,
        position: Position.Long,
        bridge: api);
  }

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat();
    formatter.minimumFractionDigits = 2;
    formatter.maximumFractionDigits = 2;

    final cfdOffersChangeNotifier = context.watch<CfdOfferChangeNotifier>();

    final receivedOffer = cfdOffersChangeNotifier.offer;
    final noOffer = receivedOffer == null;
    final offer = receivedOffer ?? Offer(bid: 0, ask: 0, index: 0);

    final fmtBid = "\$" + formatter.format(offer.bid);
    final fmtAsk = "\$" + formatter.format(offer.ask);
    final fmtIndex = "\$" + formatter.format(offer.index);

    order.openPrice = order.position == Position.Long ? offer.ask : offer.bid;

    final liquidationPrice = formatter.format(order.calculateLiquidationPrice());
    final expiry = DateFormat('dd.MM.yy-kk:mm')
        .format(DateTime.fromMillisecondsSinceEpoch((order.calculateExpiry() * 1000)));
    final margin = Amount.fromBtc(order.marginTaker()).display(currency: Currency.sat).value;

    final balance = context.watch<LightningBalance>().amount.asSats;
    final channel = context.watch<ChannelChangeNotifier>();
    final int takerAmount = Amount.fromBtc(order.marginTaker()).asSats;

    var showActionButton = true;
    Message? channelError;
    if (!channel.isInitialising() && !channel.isAvailable()) {
      channelError = Message(
          title: 'No channel with 10101 maker',
          details: 'You need an open channel with the 10101 maker before you can open a CFD.',
          type: AlertType.warning);
      showActionButton = false;
    } else if (channel.isInitialising()) {
      channelError = Message(
          title: 'Channel not confirmed',
          details: 'Please wait until your channel has 1 confirmation.',
          type: AlertType.warning);
      showActionButton = false;
    } else if (!channel.isAvailable()) {
      channelError = Message(
          title: 'Channel not available',
          details: 'It looks like the channel is not available, maybe you lost connection.',
          type: AlertType.warning);
      showActionButton = false;
    } else if (noOffer) {
      channelError = Message(
          title: 'No offer available',
          details: 'You cannot open a position without an offer.',
          type: AlertType.warning);
      showActionButton = false;
    } else if (takerAmount > balance) {
      channelError = Message(
          title: 'Insufficient funds',
          details: 'The required margin is higher than the available balance.',
          type: AlertType.warning);
      showActionButton = false;
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
      ListView(shrinkWrap: true, children: [
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
        const SizedBox(height: 10),
        PositionSelection(
            onChange: (position) {
              setState(() {
                order.position = position!;
                order.openPrice = Position.Long == position ? offer.ask : offer.bid;
              });
            },
            value: order.position),
        Padding(
          padding: const EdgeInsets.only(top: 20.0, bottom: 5.0),
          // Add box constraints to make sure that the row does not push the elements below down when the quantity text field displays a validation error
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 70),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.only(bottom: 0.0),
                        alignLabelWithHint: true,
                        enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                                color: Theme.of(context).colorScheme.primary, width: 2.0)),
                        labelText: "* Quantity",
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(fontSize: 18.0),
                      initialValue: order.quantity.toString(),
                      onChanged: (value) {
                        setState(() {
                          try {
                            order.quantity = int.parse(value);
                          } on Exception {
                            order.quantity = 0;
                          }
                        });

                        _formKey.currentState!.validate();
                      },
                      validator: (value) {
                        if (value == null) {
                          return "Enter quantity";
                        }

                        try {
                          int intVal = int.parse(value);

                          if (intVal > maxQuantity) {
                            return "Max quantity is $maxQuantity";
                          }
                          if (intVal < minQuantity) {
                            return "Min quantity is $minQuantity";
                          }
                        } on Exception {
                          return "Enter a number";
                        }

                        return null;
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 10, right: 10),
                    child: Dropdown(
                        values: [ContractSymbol.BtcUsd.name.toUpperCase()],
                        onChange: (contractSymbol) {
                          order.contractSymbol = ContractSymbol.values
                              .firstWhere((e) => e.name == contractSymbol!.toLowerCase());
                        },
                        value: order.contractSymbol.name.toUpperCase()),
                  ),
                  Dropdown(
                      values: CfdOffer.leverages.map((l) => 'x$l').toList(),
                      onChange: (leverage) {
                        setState(() {
                          order.leverage = int.parse(leverage!.substring(1));
                        });
                      },
                      value: 'x' + order.leverage.toString()),
                ]),
          ),
        ),
        Column(mainAxisAlignment: MainAxisAlignment.start, children: <Widget>[
          TtoTable([
            TtoRow(
                label: 'Liquidation Price',
                value: liquidationPrice.toString(),
                type: ValueType.usd),
            TtoRow(label: 'Margin', value: margin, type: ValueType.satoshi),
            TtoRow(label: 'Expiry', value: expiry, type: ValueType.date),
          ]),
        ]),
      ])
    ];

    widgets.addAll(warnings);

    return Scaffold(
      body: Form(
        key: _formKey,
        child: Padding(
            padding: const EdgeInsets.only(left: 25, right: 25), child: Column(children: widgets)),
      ),
      floatingActionButton: Visibility(
        visible: showActionButton,
        child: FloatingActionButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              GoRouter.of(context).go(
                CfdTrading.route + '/' + CfdOrderConfirmation.subRouteName,
                extra: CfdOrderConfirmationArgs(order, channelError),
              );
            }
          },
          child: const Icon(Icons.shopping_cart_checkout),
        ),
      ),
    );
  }
}
