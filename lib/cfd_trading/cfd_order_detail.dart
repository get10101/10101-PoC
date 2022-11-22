import 'package:f_logs/f_logs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:ten_ten_one/bridge_generated/bridge_definitions.dart';
import 'package:ten_ten_one/cfd_trading/cfd_offer_change_notifier.dart';
import 'package:ten_ten_one/cfd_trading/cfd_trading.dart';
import 'package:ten_ten_one/cfd_trading/cfd_trading_change_notifier.dart';
import 'package:ten_ten_one/models/amount.model.dart';
import 'package:ten_ten_one/models/order.dart';
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
    final formatter = NumberFormat.decimalPattern('en');

    final cfdTradingService = context.read<CfdTradingChangeNotifier>();

    final cfdOffersChangeNotifier = context.watch<CfdOfferChangeNotifier>();
    final offer = cfdOffersChangeNotifier.offer ?? Offer(bid: 0, ask: 0, index: 0);

    Cfd cfd = widget.cfd!;
    Order order = cfd.getOrder();

    final openPrice = formatter.format(cfd.openPrice);
    final liquidationPrice = formatter.format(cfd.liquidationPrice);
    final margin = Amount.fromBtc(order.marginTaker()).display(currency: Currency.sat).value;
    final estimatedFees = Amount(txFee).display(currency: Currency.sat).value;

    final pnl = order.calculateProfitTaker(
        closingPrice: cfd.position == Position.Long ? offer.bid : offer.ask);

    final unrealizedPL = Amount.fromBtc(pnl).display(currency: Currency.sat, sign: true).value;

    final expiry =
        DateFormat('dd.MM.yy-kk:mm').format(DateTime.fromMillisecondsSinceEpoch(cfd.expiry * 1000));
    final quantity = cfd.quantity.toString();
    final contractSymbol = cfd.contractSymbol.name.toUpperCase();

    final cfdTradingChangeNotifier = context.read<CfdTradingChangeNotifier>();

    var rows = [
      TtoRow(label: 'Position', value: cfd.position.name, type: ValueType.satoshi),
      TtoRow(label: 'Opening Price', value: openPrice, type: ValueType.usd),
      TtoRow(label: 'Unrealized P/L', value: unrealizedPL, type: ValueType.satoshi),
      TtoRow(label: 'Margin', value: margin, type: ValueType.satoshi),
      TtoRow(label: 'Expiry', value: expiry, type: ValueType.date),
      TtoRow(label: 'Liquidation Price', value: liquidationPrice, type: ValueType.usd),
      TtoRow(label: 'Quantity', value: quantity, type: ValueType.satoshi),
      TtoRow(label: 'Estimated fees', value: estimatedFees, type: ValueType.satoshi),
    ];

    final double? closePrice = cfd.closePrice;
    if (closePrice != null) {
      rows.insert(2,
          TtoRow(label: 'Closing Price', value: formatter.format(closePrice), type: ValueType.usd));
    }

    return Scaffold(
        appBar: AppBar(title: const Text('CFD Order Details')),
        body: SafeArea(
          child: Container(
              padding: const EdgeInsets.all(20.0),
              child: Column(children: [
                Center(child: Text(contractSymbol, style: const TextStyle(fontSize: 24))),
                const SizedBox(height: 35),
                Chip(
                    label: Text(cfd.state.name,
                        style:
                            const TextStyle(fontSize: 24, color: Colors.black, letterSpacing: 2)),
                    labelPadding: const EdgeInsets.only(left: 30, right: 30, top: 5, bottom: 5),
                    backgroundColor: Colors.white,
                    shape: const StadiumBorder(
                        side: BorderSide(
                      width: 1,
                      color: Colors.orange,
                    ))),
                const SizedBox(height: 35),
                Expanded(
                  child: TtoTable(rows),
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
                                  side: const BorderSide(width: 1.0, color: Colors.orange),
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
                              child: ElevatedButton(
                                  onPressed: () async {
                                    try {
                                      await api.settleCfd(cfd: cfd, offer: offer);
                                      FLog.info(text: "Successfully settled cfd.");

                                      // switch index to cfd overview tab
                                      cfdTradingChangeNotifier.selectedIndex = 1;
                                      // refreshing cfd list after cfd has been closed
                                      // will also implicitely propagate the index change
                                      await cfdTradingService.refreshCfdList();

                                      // navigate back to the trading route where the index has already been propagated
                                      context.go(CfdTrading.route);
                                    } on FfiException catch (error) {
                                      FLog.error(
                                          text: 'Failed to settle CFD: ' + error.message,
                                          exception: error);

                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                        backgroundColor: Colors.red,
                                        content: Text("Failed to settle cfd"),
                                      ));
                                    }
                                  },
                                  child: const Text('Confirm')),
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
}
