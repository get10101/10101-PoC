import 'package:flutter/material.dart' hide Divider;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:ten_ten_one/balance.dart';
import 'package:ten_ten_one/bridge_generated/bridge_definitions.dart' hide Balance;
import 'package:ten_ten_one/cfd_trading/cfd_offer_change_notifier.dart';
import 'package:ten_ten_one/cfd_trading/cfd_order_detail.dart';
import 'package:ten_ten_one/cfd_trading/cfd_trading.dart';
import 'package:ten_ten_one/cfd_trading/cfd_trading_change_notifier.dart';
import 'package:ten_ten_one/models/amount.model.dart';
import 'package:ten_ten_one/models/order.dart';
import 'package:ten_ten_one/utilities/divider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

class CfdOverview extends StatefulWidget {
  const CfdOverview({Key? key}) : super(key: key);

  @override
  State<CfdOverview> createState() => _CfdOverviewState();
}

class _CfdOverviewState extends State<CfdOverview> {
  @override
  Widget build(BuildContext context) {
    final cfdOffersChangeNotifier = context.watch<CfdOfferChangeNotifier>();
    final offer = cfdOffersChangeNotifier.offer ?? Offer(bid: 0, ask: 0, index: 0);
    final cfdTradingChangeNotifier = context.watch<CfdTradingChangeNotifier>();
    final cfds = cfdTradingChangeNotifier.cfds;
    cfds.sort((a, b) => b.updated.compareTo(a.updated));

    List<Widget> widgets = [
      const Balance(balanceSelector: BalanceSelector.lightning),
      const Divider()
    ];
    widgets.addAll(cfds
        .where((cfd) => [CfdState.Open].contains(cfd.state))
        .map((cfd) => CfdTradeItem(cfd: cfd, closingPrice: offer.index))
        .toList());

    widgets.add(ExpansionTile(
      title: const Text('Closed', style: TextStyle(fontSize: 20)),
      onExpansionChanged: (changed) {
        cfdTradingChangeNotifier.expanded = true;
      },
      initiallyExpanded: cfdTradingChangeNotifier.expanded,
      children: cfds
          .where((cfd) => [CfdState.Closed, CfdState.Failed].contains(cfd.state))
          .map((cfd) => CfdTradeItem(
              cfd: cfd,
              closingPrice: cfd.state == CfdState.Closed
                  ? cfd.closePrice!
                  : (cfd.position == Position.Long ? offer.bid : offer.ask)))
          .toList(),
    ));

    return Scaffold(
        body: ListView(
      padding: const EdgeInsets.only(left: 25, right: 25),
      children: widgets,
    ));
  }
}

class CfdTradeItem extends StatelessWidget {
  final Cfd cfd;
  final double closingPrice;

  const CfdTradeItem({super.key, required this.cfd, required this.closingPrice});

  @override
  Widget build(BuildContext context) {
    final updated = DateFormat('dd.MM.yy-kk:mm')
        .format(DateTime.fromMillisecondsSinceEpoch(cfd.updated * 1000));

    final pnl = cfd.getOrder().calculateProfitTaker(closingPrice: closingPrice);
    final fmtPnl = Amount.fromBtc(pnl).display(sign: true, currency: Currency.sat).value;

    return GestureDetector(
      onTap: () {
        context.go(CfdTrading.route + '/' + CfdOrderDetail.subRouteName, extra: cfd);
      },
      child: Container(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey, width: 0.5)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    SizedBox(width: 20, child: FaIcon(cfd.contractSymbol.icon)),
                    const SizedBox(width: 15),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(cfd.state.name, style: const TextStyle(fontSize: 20)),
                      Text(updated, style: const TextStyle(color: Colors.grey, fontSize: 16))
                    ]),
                  ],
                ),
                Row(children: [
                  cfd.position == Position.Long
                      ? const FaIcon(FontAwesomeIcons.arrowTrendUp, color: Colors.green)
                      : const FaIcon(FontAwesomeIcons.arrowTrendDown, color: Colors.red)
                ]),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Text(fmtPnl,
                      style: TextStyle(
                          fontSize: 20, color: pnl.isNegative ? Colors.red : Colors.green)),
                  const SizedBox(width: 5),
                  const Text(
                    'sat',
                    style: TextStyle(color: Colors.grey, fontSize: 20),
                  )
                ])
              ]),
        ),
      ),
    );
  }
}
