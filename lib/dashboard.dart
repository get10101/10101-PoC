import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ten_ten_one/balance.dart';
import 'package:ten_ten_one/cfd_trading.dart';
import 'package:ten_ten_one/models/service.model.dart';
import 'package:ten_ten_one/seed.dart';
import 'package:ten_ten_one/service_card.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({Key? key}) : super(key: key);

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Dashboard'),
        ),
        body: ListView(children: [
          const Balance(),
          Expanded(
              // Sized box necessary to achieve nested ListViews
              child: SizedBox(
            height: 110.0,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 15, right: 15),
              children: [
                GestureDetector(
                  onTap: () => {GoRouter.of(context).go(CfdTrading.route)},
                  child: const ServiceCard(Service.cfd),
                ),
                const ServiceCard(Service.sportsbet),
              ],
            ),
          )),
          const Divider(
            height: 30,
            thickness: 7,
            color: Colors.grey,
            indent: 30,
            endIndent: 30,
          ),
          GestureDetector(
              onTap: () => {GoRouter.of(context).go(Seed.route)},
              child: Card(
                shape: const Border(left: BorderSide(color: Colors.blueGrey, width: 5)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const <Widget>[
                    ListTile(
                      leading: Icon(Icons.warning),
                      title: Text('Create Wallet Backup'),
                      subtitle: Text(
                          'You have not backed up your wallet yet, make sure you create a backup!'),
                    ),
                  ],
                ),
              ))
        ]));
  }
}
