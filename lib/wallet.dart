/// Code in this file is more about Flutter than our package, `flutter rust bridge`.
/// To understand this package, you do not need to have a deep understanding of this file and Flutter.
/// Thus, we put it in this "utility" file, instead of the "main" file.
import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:ten_ten_one/generated/bridge_definitions.dart';

Widget buildWalletPage(WalletInfo? walletInfo) {
  return MaterialApp(
    home: Scaffold(
      appBar: AppBar(title: const Text('TenTenOne Wallet')),
      body: ListView(
        children: [
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Card(
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      child: Column(
                        children: [
                          const Text("Wallet Info", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          (walletInfo != null ? Text('Address: ' + walletInfo!.address + ', Balance: ' + walletInfo!.balance.toString()) : Text('Waiting for wallet info!')),
                        ],
                      )
                  )
              )
          ),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Card(
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      child: Column(
                        children: [
                          const Text("Seed phrase", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          (walletInfo != null ? Text(walletInfo.phrase.toString()) : Text('Waiting for wallet info!')),
                        ],
                      )
                  )
              )
          ),
        ],
      ),
    ),
  );
}