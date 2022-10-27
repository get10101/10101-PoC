import 'dart:async';

import 'package:flutter/material.dart' hide Size;
import 'package:ten_ten_one/off_topic_code.dart';

import 'ffi.io.dart' if (dart.library.html) 'ffi.web.dart';
export 'ffi.io.dart' if (dart.library.html) 'ffi.web.dart' show api;

// Simple Flutter code. If you are not familiar with Flutter, this may sounds a bit long. But indeed
// it is quite trivial and Flutter is just like that. Please refer to Flutter's tutorial to learn Flutter.

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // start with some simple balance to see whether we get anything out of BDK
  String? walletBalance;
  String? exampleText;

  @override
  void initState() {
    super.initState();
    _callInitWallet();
    _callExampleFfiTwo();
  }

  @override
  Widget build(BuildContext context) => buildPageUi(
        walletBalance,
        exampleText,
      );

  Future<void> _callExampleFfiTwo() async {
    final receivedText = await api.passingComplexStructs(root: createExampleTree());
    if (mounted) setState(() => exampleText = receivedText);
  }

  Future<void> _callInitWallet() async {
    final receivedText = await api.initWallet();
    if (mounted) setState(() => walletBalance = receivedText);
  }
}
