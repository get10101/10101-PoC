import 'package:f_logs/f_logs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';
import 'package:provider/provider.dart';
import 'package:ten_ten_one/models/seed_backup_model.dart';
import 'package:go_router/go_router.dart';

import 'ffi.io.dart' if (dart.library.html) 'ffi.web.dart';

class Seed extends StatefulWidget {
  const Seed({Key? key}) : super(key: key);

  static const route = '/' + subRouteName;
  static const subRouteName = 'seed';

  @override
  State<Seed> createState() => _SeedState();
}

class _SeedState extends State<Seed> {
  bool checked = false;
  bool visibility = false;

  // initialise the phrase with empty words - in order for the widget to not throw
  // an error while waiting for the rust api. Seems to be the easiest way of handling
  // uninitialised state, as the words will be ready immediately after the widget is
  // initialised and the words are not visible at first.
  List<String> phrase = ["", "", "", "", "", "", "", "", "", "", "", ""];

  @override
  void initState() {
    _callGetSeedPhrase();
    super.initState();
  }

  Future<void> _callGetSeedPhrase() async {
    try {
      final seedPhrase = await api.getSeedPhrase();
      setState(() {
        phrase = seedPhrase;
      });
    } on FfiException catch (error) {
      FLog.error(text: "Failed to fetch seed phrase: Error: " + error.message, exception: error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstColumn = phrase
        .getRange(0, 6)
        .toList()
        .asMap()
        .entries
        .map((entry) => SeedWord(entry.value, entry.key + 1, visibility))
        .toList();
    final secondColumn = phrase
        .getRange(6, 12)
        .toList()
        .asMap()
        .entries
        .map((entry) => SeedWord(entry.value, entry.key + 7, visibility))
        .toList();

    return Scaffold(
        appBar: AppBar(
          title: const Text('Backup Seed'),
        ),
        body: Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(30, 30, 30, 30),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Flexible(
                  child: RichText(
                      text: const TextSpan(
                          style: TextStyle(color: Colors.black, fontSize: 18),
                          children: [
                        TextSpan(
                            text:
                                "This list of words is your wallet backup. Save it somewhere safe (not on this phone)! "),
                        TextSpan(
                            text: "\n\nDo not share it with anyone. Do not lose it. ",
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        TextSpan(
                            text:
                                "If you lose your words list and your phone, you've lost your funds.")
                      ])),
                )
              ]),
            ),
            Row(
              children: [
                Expanded(
                    child: Container(
                        margin: const EdgeInsets.fromLTRB(55, 10, 10, 0),
                        child: Row(children: [
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.start, children: firstColumn)
                        ]))),
                Expanded(
                    child: Container(
                        margin: const EdgeInsets.fromLTRB(10, 10, 55, 0),
                        child: Row(children: [
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.start, children: secondColumn)
                        ]))),
              ],
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                      icon: visibility
                          ? const Icon(Icons.visibility)
                          : const Icon(Icons.visibility_off),
                      onPressed: () {
                        setState(() {
                          visibility = !visibility;
                        });
                      },
                      tooltip: visibility ? 'Hide Seed' : 'Show Seed'),
                  Text(visibility ? 'Hide Seed' : 'Show Seed')
                ],
              ),
            ),
            Expanded(
              child: Container(
                  margin: const EdgeInsets.fromLTRB(0, 0, 20, 30),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Checkbox(
                              value: checked,
                              onChanged: (bool? changed) {
                                setState(() {
                                  checked = changed!;
                                });
                              }),
                          const Text('I have made a backup of my seed'),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton(
                              onPressed: checked
                                  ? () {
                                      final seedBackupModel = context.read<SeedBackupModel>();
                                      seedBackupModel.update();
                                      context.go('/');
                                    }
                                  : null,
                              child: const Text('Done'))
                        ],
                      )
                    ],
                  )),
            )
          ],
        ));
  }
}

class SeedWord extends StatelessWidget {
  final String? word;
  final int? index;
  final bool visibility;

  const SeedWord(this.word, this.index, this.visibility, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: const EdgeInsets.fromLTRB(0, 10, 0, 0),
        child: Row(
            crossAxisAlignment: visibility ? CrossAxisAlignment.baseline : CrossAxisAlignment.end,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '#$index',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(width: 5),
              visibility
                  ? Text(
                      word!,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    )
                  : Container(
                      color: Colors.grey[300], child: const SizedBox(width: 100, height: 24))
            ]));
  }
}
