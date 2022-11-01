import 'package:flutter/material.dart' hide Size;
import 'package:provider/provider.dart';
import 'package:ten_ten_one/dashboard.dart';
import 'package:ten_ten_one/models/balance.model.dart';
import 'package:ten_ten_one/seed.dart';

import 'dart:async';

import 'ffi.io.dart' if (dart.library.html) 'ffi.web.dart';

BalanceModel balanceModel = BalanceModel();

void main() =>
    runApp(ChangeNotifierProvider(create: (context) => balanceModel, child: const TenTenOneApp()));

class TenTenOneApp extends StatefulWidget {
  const TenTenOneApp({Key? key}) : super(key: key);

  @override
  State<TenTenOneApp> createState() => _TenTenOneState();
}

class _TenTenOneState extends State<TenTenOneApp> {
  @override
  void initState() {
    super.initState();
    _callInitWallet();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TenTenOne',
      theme: ThemeData(primarySwatch: Colors.teal),
      routes: {
        Seed.routeName: (context) => const Seed(),
      },
      home: const Dashboard(),
    );
  }

  Future<void> _callInitWallet() async {
    await api.initWallet();

    // initial sync
    _callSync();
    // consecutive syncs
    runPeriodically(_callSync);
  }

  Future<void> _callSync() async {
    final balance = await api.getBalance();
    if (mounted) setState(() => balanceModel.update(balance.confirmed));
  }
}

void runPeriodically(void Function() callback) =>
    Timer.periodic(const Duration(seconds: 20), (timer) => callback());
