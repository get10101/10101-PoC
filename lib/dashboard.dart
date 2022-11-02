import 'package:flutter/material.dart' hide Divider;
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:ten_ten_one/balance.dart';
import 'package:ten_ten_one/cfd_trading/cfd_trading.dart';
import 'package:ten_ten_one/menu.dart';
import 'package:ten_ten_one/models/seed_backup_model.dart';
import 'package:ten_ten_one/models/service_model.dart';
import 'package:ten_ten_one/receive.dart';
import 'package:ten_ten_one/receive.dart';
import 'package:ten_ten_one/seed.dart';
import 'package:ten_ten_one/send.dart';
import 'package:ten_ten_one/service_card.dart';
import 'package:ten_ten_one/utilities/divider.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';

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
      body: ListView(padding: const EdgeInsets.only(left: 25, right: 25), children: widgets),
      floatingActionButton: SpeedDial(
        icon: Icons.import_export,
        iconTheme: const IconThemeData(size: 35),
        activeIcon: Icons.close,
        backgroundColor: Colors.orange[800],
        foregroundColor: Colors.white,
        activeBackgroundColor: Colors.grey,
        activeForegroundColor: Colors.white,
        buttonSize: const Size(56.0, 56.0),
        visible: true,
        closeManually: false,
        curve: Curves.bounceIn,
        overlayColor: Colors.black,
        overlayOpacity: 0.5,
        elevation: 8.0,
        shape: const CircleBorder(),
        children: [
          SpeedDialChild(
            child: const Icon(Icons.download_sharp),
            backgroundColor: Colors.orange[600],
            foregroundColor: Colors.white,
            label: 'Receive',
            labelStyle: const TextStyle(fontSize: 18.0),
            onTap: () => GoRouter.of(context).go(Receive.route),
          ),
          SpeedDialChild(
            child: const Icon(Icons.upload_sharp),
            backgroundColor: Colors.orange[600],
            foregroundColor: Colors.white,
            label: 'Send',
            labelStyle: const TextStyle(fontSize: 18.0),
            onTap: () => GoRouter.of(context).go(Send.route),
          ),
        ],
      ),
    );
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
