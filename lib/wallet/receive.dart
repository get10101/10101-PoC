import 'package:flutter/material.dart';

class Receive extends StatelessWidget {
  const Receive({Key? key}) : super(key: key);

  static const route = '/' + subRouteName;
  static const subRouteName = 'receive';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Receive Payment'),
        ),
        body: ListView(children: const [Center(child: Text("Receive Payment"))]));
  }
}
