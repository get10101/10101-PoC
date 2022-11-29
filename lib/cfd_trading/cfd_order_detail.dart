import 'package:f_logs/f_logs.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:ten_ten_one/bridge_generated/bridge_definitions.dart';
import 'package:ten_ten_one/cfd_trading/cfd_offer_change_notifier.dart';
import 'package:ten_ten_one/cfd_trading/cfd_trading.dart';
import 'package:ten_ten_one/cfd_trading/cfd_trading_change_notifier.dart';
import 'package:ten_ten_one/cfd_trading/validation_error.dart';
import 'package:ten_ten_one/models/amount.model.dart';
import 'package:ten_ten_one/models/order.dart';
import 'package:ten_ten_one/utilities/submit_button.dart';
import 'package:ten_ten_one/utilities/tto_table.dart';
import 'package:go_router/go_router.dart';

import 'package:ten_ten_one/ffi.io.dart' if (dart.library.html) 'ffi.web.dart';

class CfdOrderDetail extends StatefulWidget {
  static const subRouteName = 'cfd-order-detail';

  final Cfd? cfd;

  const CfdOrderDetail({this.cfd, super.key});

  @override
  State<CfdOrderDetail> createState() => _CfdOrderDetailState();
}

class _CfdOrderDetailState extends State<CfdOrderDetail> {
  bool confirm = false;
  int txFee = 0;

  @override
  void initState() {
    super.initState();
    setFee();
  }

  Future<void> setFee() async {
    final recommended = await api.getFeeRecommendation();
    const dummyVbytes = 500;
    setState(() {
      txFee = recommended * dummyVbytes;
    });
  }

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat();
    formatter.minimumFractionDigits = 2;
    formatter.maximumFractionDigits = 2;

    final cfdTradingChangeNotifier = context.read<CfdTradingChangeNotifier>();
    final cfdOffersChangeNotifier = context.watch<CfdOfferChangeNotifier>();
    final offer = cfdOffersChangeNotifier.offer ?? Offer(bid: 0, ask: 0, index: 0);

    Cfd cfd = widget.cfd!;
    Order order = cfd.getOrder();

    final openPrice = formatter.format(cfd.openPrice);
    final liquidationPrice = formatter.format(cfd.liquidationPrice);
    final margin = Amount.fromBtc(order.marginTaker()).display(currency: Currency.sat).value;
    final estimatedFees = Amount(txFee).display(currency: Currency.sat).value;

    final closingPrice = cfd.position == Position.Long ? offer.bid : offer.ask;
    final pnl = order.calculateProfitTaker(closingPrice: closingPrice);

    final closingPriceAsString = formatter.format(closingPrice);

    final pnlFmt = Amount.fromBtc(pnl).display(currency: Currency.sat, sign: true).value;

    final expiry =
        DateFormat('dd.MM.yy-kk:mm').format(DateTime.fromMillisecondsSinceEpoch(cfd.expiry * 1000));
    final quantity = cfd.quantity.toString();
    final contractSymbol = cfd.contractSymbol.name.toUpperCase();

    var rows = [
      TtoRow(
          label: 'Position',
          value: 'x' + order.leverage.toString() + ' ' + order.position.name,
          type: ValueType.text),
      TtoRow(label: 'Margin', value: margin, type: ValueType.satoshi),
      TtoRow(label: 'Opening Price', value: openPrice, type: ValueType.usd),
      TtoRow(label: 'Current Price', value: closingPriceAsString, type: ValueType.usd),
      TtoRow(
          label: CfdState.Closed == cfd.state ? 'P/L' : 'Unrealized P/L',
          value: pnlFmt,
          type: ValueType.satoshi),
      TtoRow(label: 'Liquidation Price', value: liquidationPrice, type: ValueType.usd),
      TtoRow(label: 'Estimated fees', value: estimatedFees, type: ValueType.satoshi),
      TtoRow(label: 'Expiry', value: expiry, type: ValueType.date),
    ];
    final double? closePrice = cfd.closePrice;
    if (closePrice != null) {
      rows.insert(6,
          TtoRow(label: 'Closing Price', value: formatter.format(closePrice), type: ValueType.usd));
    }

    return Scaffold(
        appBar: AppBar(title: const Text('Order Details')),
        body: SafeArea(
          child: Container(
              padding: const EdgeInsets.all(20.0),
              child: Column(children: [
                Center(
                    child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Column(
                          children: [
                            Text(quantity + ' ' + contractSymbol,
                                style: const TextStyle(
                                    fontSize: 20, letterSpacing: 1, fontWeight: FontWeight.w600)),
                          ],
                        ))),
                const SizedBox(height: 25),
                Chip(
                    label: Text(cfd.state.name,
                        style:
                            const TextStyle(fontSize: 20, color: Colors.black, letterSpacing: 2)),
                    labelPadding: const EdgeInsets.only(left: 30, right: 30, top: 5, bottom: 5),
                    backgroundColor: Colors.white,
                    shape: StadiumBorder(
                        side: BorderSide(
                      width: 1,
                      color: Theme.of(context).colorScheme.primary,
                    ))),
                const SizedBox(height: 25),
                Expanded(
                  child: TtoTable(rows),
                ),
                Center(
                  child: Visibility(
                    visible: CfdState.Open == cfd.state,
                    child: Container(
                        padding: const EdgeInsets.only(top: 5.0, bottom: 5.0),
                        child: AlertMessage(
                            message: Message(
                                title:
                                    'Clicking \'Settle\' will close this position at \$$closingPriceAsString. Would you like to proceed?',
                                type: AlertType.info))),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.fromLTRB(0, 0, 0, 30),
                  child: Row(
                    children: [
                      Visibility(
                          visible: confirm,
                          child: OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  confirm = false;
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                      width: 1.0, color: Theme.of(context).colorScheme.primary),
                                  backgroundColor: Colors.white),
                              child: const Text('Cancel'))),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Visibility(
                              visible: CfdState.Open == cfd.state && !confirm,
                              child: ElevatedButton(
                                  onPressed: () {
                                    setState(() {
                                      confirm = true;
                                    });
                                  },
                                  child: const Text('Settle')),
                            ),
                            Visibility(
                              visible: confirm,
                              child: SubmitButton(
                                  onPressed: () async {
                                    await settleCfd(cfd, offer, cfdTradingChangeNotifier);
                                  },
                                  label: 'Confirm'),
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              ])),
        ));
  }

  Future<void> settleCfd(
      Cfd cfd, Offer offer, CfdTradingChangeNotifier cfdTradingChangeNotifier) async {
    FLog.info(text: "Settling CFD ${cfd.id} with offer" + offer.toString());
    await api.settleCfd(cfd: cfd, offer: offer).then((value) async {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("CFD settled"),
      ));

      // switch index to cfd overview tab
      cfdTradingChangeNotifier.selectedIndex = 1;

      // refreshing cfd list after cfd has been settled
      // will also implicitly propagate the index change
      await cfdTradingChangeNotifier.refreshCfdList();

      context.go(CfdTrading.route);
    }).catchError((error) {
      FLog.error(text: "Failed to settle CFD.", exception: error);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: Colors.red,
        content: Text("Failed to settle CFD ${cfd.id}. Error: " + error.toString()),
      ));
    });
  }
}
