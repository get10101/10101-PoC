import 'package:flutter/material.dart' hide Size;
import 'package:provider/provider.dart';
import 'package:ten_ten_one/dashboard.dart';
import 'package:ten_ten_one/models/balance.model.dart';
import 'package:ten_ten_one/seed.dart';

void main() => runApp(
    ChangeNotifierProvider(create: (context) => BalanceModel(), child: const TenTenOneApp()));

class TenTenOneApp extends StatelessWidget {
  const TenTenOneApp({Key? key}) : super(key: key);

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
}
