import 'package:flutter/material.dart';

class Send extends StatelessWidget {
  const Send({Key? key}) : super(key: key);

  static const route = '/' + subRouteName;
  static const subRouteName = 'send';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Send Payment'),
        ),
        body: ListView(children: const [Center(child: Text("Send Payment"))]));
  }
}
