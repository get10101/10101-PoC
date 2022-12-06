import 'package:f_logs/model/flog/flog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';
import 'package:provider/provider.dart';
import 'package:ten_ten_one/app_info_change_notifier.dart';
import 'package:ten_ten_one/ffi.io.dart';
import 'package:ten_ten_one/menu.dart';
import 'package:ten_ten_one/utilities/tto_table.dart';

class Settings extends StatefulWidget {
  static const route = "/" + subRouteName;
  static const subRouteName = "settings";

  const Settings({Key? key}) : super(key: key);

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  String makerPeerInfo = 'undefined';
  String nodeId = 'undefined';

  @override
  void initState() {
    _callGetSettingsInfo();
    super.initState();
  }

  Future<void> _callGetSettingsInfo() async {
    try {
      final _makerPeerInfo = await api.makerPeerInfo();
      final _nodeId = await api.nodeId();
      setState(() {
        makerPeerInfo = _makerPeerInfo;
        nodeId = _nodeId;
      });
    } on FfiException catch (error) {
      FLog.error(text: "Failed to fetch info. Error: " + error.message, exception: error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appInfoChangeNotifier = context.read<AppInfoChangeNotifier>();
    final version = appInfoChangeNotifier.appVersion;
    final network = appInfoChangeNotifier.network;

    var rows = [
      TtoRow(label: '10101 App Version', value: version, type: ValueType.text),
      TtoRow(label: 'Bitcoin Network', value: network, type: ValueType.text),
      TtoRow(label: 'Maker Peer Info', value: makerPeerInfo, type: ValueType.text),
      TtoRow(label: 'Your Node Id', value: nodeId, type: ValueType.text),
    ];

    return Scaffold(
      drawer: const Menu(),
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SafeArea(
          child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: TtoTable(rows),
      )),
    );
  }
}
