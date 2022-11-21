import 'package:ten_ten_one/cfd_trading/cfd_order_confirmation.dart';
import 'package:flutter/material.dart' hide Divider;
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:ten_ten_one/balance.dart';
import 'package:ten_ten_one/bridge_generated/bridge_definitions.dart' hide Balance;
import 'package:ten_ten_one/cfd_trading/cfd_offer_change_notifier.dart';
import 'package:ten_ten_one/cfd_trading/cfd_trading.dart';
import 'package:ten_ten_one/cfd_trading/cfd_trading_change_notifier.dart';
import 'package:ten_ten_one/cfd_trading/position_selection.dart';
import 'package:ten_ten_one/cfd_trading/validation_error.dart';
import 'package:ten_ten_one/models/amount.model.dart';
import 'package:ten_ten_one/models/balance_model.dart';
import 'package:ten_ten_one/utilities/divider.dart';
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
  late Order order;

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.decimalPattern('en');

    final cfdTradingService = context.watch<CfdTradingChangeNotifier>();
    final cfdOffersChangeNotifier = context.watch<CfdOfferChangeNotifier>();

    final offer = cfdOffersChangeNotifier.offer ?? Offer(bid: 0, ask: 0, index: 0);

    final fmtBid = formatter.format(offer.bid);
    final fmtAsk = formatter.format(offer.ask);
    final fmtIndex = formatter.format(offer.index);

    cfdTradingService.draftOrder ??= Order(
        openPrice: offer.ask,
        quantity: 100,
        leverage: 2,
        contractSymbol: ContractSymbol.BtcUsd,
        position: Position.Long,
        bridge: api);

    order = cfdTradingService.draftOrder!;

    final liquidationPrice = formatter.format(order.calculateLiquidationPrice());
    final expiry = DateFormat('dd.MM.yy-kk:mm')
        .format(DateTime.fromMillisecondsSinceEpoch((order.calculateExpiry() * 1000)));
    final margin = Amount.fromBtc(order.marginTaker()).display(currency: Currency.sat).value;

    final balance = context.read<LightningBalance>().amount.asSats;
    final int takerAmount = Amount.fromBtc(order.marginTaker()).asSats;

    ChannelError? channelError;
    if (balance == 0) {
      channelError = ChannelError(
          title: 'No channel with 10101 maker',
          details: 'You need an open channel with the 10101 maker before you can open a CFD.');
    } else if (takerAmount > balance) {
      channelError = ChannelError(
          title: 'Insufficient funds',
          details: 'The required margin is higher than the available balance.');
    }

    return Scaffold(
      body: ListView(padding: const EdgeInsets.only(left: 25, right: 25), children: [
        const Balance(balanceSelector: BalanceSelector.lightning),
        const Divider(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Text("bid $fmtBid"),
            Text("ask $fmtAsk"),
            Text("index $fmtIndex"),
          ],
        ),
        const SizedBox(height: 30),
        PositionSelection(
            onChange: (position) {
              setState(() {
                order.position = position!;
                order.openPrice = Position.Long == position ? offer.ask : offer.bid;
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
                order.quantity = int.parse(contracts!);
              });
            },
            value: order.quantity.toString(),
          ),
          Dropdown(
              values: [ContractSymbol.BtcUsd.name.toUpperCase()],
              onChange: (contractSymbol) {
                order.contractSymbol = ContractSymbol.values
                    .firstWhere((e) => e.name == contractSymbol!.toLowerCase());
              },
              value: order.contractSymbol.name.toUpperCase()),
          Dropdown(
              values: CfdOffer.leverages.map((l) => 'x$l').toList(),
              onChange: (leverage) {
                setState(() {
                  order.leverage = int.parse(leverage!.substring(1));
                });
              },
              value: 'x' + order.leverage.toString()),
        ]),
        Column(mainAxisAlignment: MainAxisAlignment.start, children: <Widget>[
          Container(
            margin: const EdgeInsets.only(top: 25),
            child: TtoTable([
              TtoRow(label: 'Margin', value: margin, type: ValueType.satoshi),
              TtoRow(label: 'Expiry', value: expiry, type: ValueType.date),
              TtoRow(
                  label: 'Liquidation Price',
                  value: liquidationPrice.toString(),
                  type: ValueType.usd),
            ]),
          )
        ])
      ]),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          GoRouter.of(context).go(
            CfdTrading.route + '/' + CfdOrderConfirmation.subRouteName,
            extra: CfdOrderConfirmationArgs(order, channelError),
          );
        },
        backgroundColor: Colors.orange,
        child: const Icon(Icons.shopping_cart_checkout),
      ),
      bottomSheet: channelError != null ? ValidationError(channelError: channelError) : null,
    );
  }
}
