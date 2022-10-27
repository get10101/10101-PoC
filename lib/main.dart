import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart' hide Size;
import 'package:ten_ten_one/generated/bridge_definitions.dart';
import 'package:ten_ten_one/off_topic_code.dart';

import 'generated/ffi.io.dart' if (dart.library.html) 'ffi.web.dart';
export 'generated/ffi.io.dart' if (dart.library.html) 'ffi.web.dart' show api;

// Simple Flutter code. If you are not familiar with Flutter, this may sounds a bit long. But indeed
// it is quite trivial and Flutter is just like that. Please refer to Flutter's tutorial to learn Flutter.

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Uint8List? exampleImage;
  String? exampleText;
  WalletInfo? walletInfo;

  late Stream<WalletInfo> feed;

  @override
  void initState() {
    super.initState();
    _callExampleFfiTwo();
    feed = api.run();
    listen();
  }

  Future<void> listen() async {
    feed.listen((event) {
      if (mounted) setState(() => walletInfo = event);
      print("Address: " + walletInfo!.address + ": " + walletInfo!.balance.toString());
    });
  }

  @override
  Widget build(BuildContext context) => buildPageUi(exampleImage, exampleText, walletInfo);

  Future<void> _callExampleFfiTwo() async {
    final receivedText = await api.passingComplexStructs(root: createExampleTree());
    if (mounted) setState(() => exampleText = receivedText);
  }
}
