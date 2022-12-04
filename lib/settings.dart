import 'package:f_logs/model/flog/flog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';
import 'package:ten_ten_one/ffi.io.dart';
import 'package:ten_ten_one/menu.dart';

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
    return Scaffold(
      drawer: const Menu(),
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SafeArea(
          child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Table(
          columnWidths: const <int, TableColumnWidth>{
            0: FlexColumnWidth(),
            1: FlexColumnWidth(),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: <TableRow>[
            buildTableRow("Maker Peer Info", makerPeerInfo),
            buildTableRow("Your Node Id", nodeId),
          ],
        ),
      )),
    );
  }

  TableRow buildTableRow(String title, String field) {
    return TableRow(
      children: <Widget>[
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: Text(title),
        ),
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: SelectableText(field),
        ),
      ],
    );
  }
}
