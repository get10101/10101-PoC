import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart' hide Size;
import 'bridge_definitions.dart';
import 'package:ten_ten_one/wallet.dart';

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
  String? address;

  late Wallet wallet;

  @override
  void initState() {
    super.initState();
    wallet = Wallet();

  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(appBar: AppBar(title: const Text('10101')),
      body: ListView(
        children: [
          Container(height: 16),
          Container(padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Card(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  ElevatedButton(
                    onPressed: buildWallet,
                    child: const Text('Build Wallet'),
                  ),
                  Container(height: 24),
                  const Text('Address: '),
                  Text(address ?? '', style: const TextStyle(fontSize: 12, color: Colors.black)),
                  Container(height: 8),
                ],
              ),
            ),
          ),
          ),
        ],
      ),
      ),
    );
  }

  Future<void> buildWallet() async {
    final tenTenOneAddress = await wallet.buildWallet();
    setState(() => address = tenTenOneAddress);
  }
}
