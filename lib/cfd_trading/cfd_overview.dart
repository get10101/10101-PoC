import 'package:flutter/material.dart' hide Divider;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:ten_ten_one/balance.dart';
import 'package:ten_ten_one/cfd_trading/cfd_order_detail.dart';
import 'package:ten_ten_one/cfd_trading/cfd_trading.dart';
import 'package:ten_ten_one/cfd_trading/cfd_trading_change_notifier.dart';
import 'package:ten_ten_one/models/amount.model.dart';
import 'package:ten_ten_one/utilities/divider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:ten_ten_one/models/order.dart';

class CfdOverview extends StatefulWidget {
  const CfdOverview({Key? key}) : super(key: key);

  @override
  State<CfdOverview> createState() => _CfdOverviewState();
}

class _CfdOverviewState extends State<CfdOverview> {
  @override
  Widget build(BuildContext context) {
    final cfdTradingService = context.watch<CfdTradingChangeNotifier>();
    final orders = cfdTradingService.listOrders();
    orders.sort((a, b) => b.updated.compareTo(a.updated));

    List<Widget> widgets = [
      const Balance(balanceSelector: BalanceSelector.lightning),
      const Divider()
    ];
    widgets.addAll(orders
        .where((order) => [OrderStatus.open, OrderStatus.pending].contains(order.status))
        .map((order) => CfdTradeItem(order: order))
        .toList());

    widgets.add(ExpansionTile(
      title: const Text('Closed', style: TextStyle(fontSize: 20)),
      onExpansionChanged: (changed) {
        cfdTradingService.expanded = true;
      },
      initiallyExpanded: cfdTradingService.expanded,
      children: orders
          .where((order) => [OrderStatus.closed].contains(order.status))
          .map((order) => CfdTradeItem(order: order))
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
  final Order order;

  const CfdTradeItem({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final updated = DateFormat('dd.MM.yy-kk:mm').format(order.updated);

    return GestureDetector(
      onTap: () {
        context.go(CfdTrading.route + '/' + CfdOrderDetail.subRouteName, extra: order);
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
                    SizedBox(width: 20, child: FaIcon(order.tradingPair.icon)),
                    const SizedBox(width: 15),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(order.status.display, style: const TextStyle(fontSize: 20)),
                      Text(updated, style: const TextStyle(color: Colors.grey, fontSize: 16))
                    ]),
                  ],
                ),
                Row(children: [
                  order.position == Position.long
                      ? const FaIcon(FontAwesomeIcons.arrowTrendUp, color: Colors.green)
                      : const FaIcon(FontAwesomeIcons.arrowTrendDown, color: Colors.red)
                ]),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Text(order.pl.display(sign: true, currency: Currency.sat).value,
                      style: TextStyle(
                          fontSize: 20,
                          color: order.pl.asSats.isNegative ? Colors.red : Colors.green)),
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
