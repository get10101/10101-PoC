import 'package:flutter/material.dart';

class Withdraw extends StatefulWidget {
  const Withdraw({Key? key}) : super(key: key);

  static const route = '/' + subRouteName;
  static const subRouteName = 'withdraw';

  @override
  State<Withdraw> createState() => _WithdrawState();
}

class _WithdrawState extends State<Withdraw> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Withdraw Bitcoin'),
      ),
      body: const SafeArea(child: Text("tbd")),
    );
  }
}
