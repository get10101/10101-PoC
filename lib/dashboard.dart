import 'package:flutter/material.dart' hide Divider;
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:ten_ten_one/balance.dart';
import 'package:ten_ten_one/menu.dart';
import 'package:ten_ten_one/models/seed_backup.model.dart';
import 'package:ten_ten_one/cfd_trading.dart';
import 'package:ten_ten_one/models/service.model.dart';
import 'package:ten_ten_one/seed.dart';
import 'package:ten_ten_one/service_card.dart';
import 'package:ten_ten_one/utilities/divider.dart';

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
    final seedBackupModel = context.watch<SeedBackupModel>();
    List<Widget> widgets = [
      const Balance(),
      const Divider(),
      const ServiceNavigation(),
      const Divider()
    ];

    if (!seedBackupModel.backup) {
      widgets.add(const BackupSeedCard());
    }

    return Scaffold(
        appBar: AppBar(
          title: Text(ServiceGroup.wallet.label),
        ),
        drawer: const Menu(),
        body: ListView(children: widgets));
  }
}

class ServiceNavigation extends StatelessWidget {
  const ServiceNavigation({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
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
    );
  }
}

class BackupSeedCard extends StatelessWidget {
  const BackupSeedCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTap: () => {GoRouter.of(context).go(Seed.route)},
        child: Card(
          margin: const EdgeInsets.only(left: 15, right: 15),
          shape: const Border(left: BorderSide(color: Colors.blueGrey, width: 5)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const <Widget>[
              ListTile(
                leading: Icon(Icons.warning),
                title: Text('Create Wallet Backup'),
                subtitle:
                    Text('You have not backed up your wallet yet, make sure you create a backup!'),
              ),
            ],
          ),
        ));
  }
}
