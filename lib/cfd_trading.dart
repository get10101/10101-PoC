import 'package:flutter/material.dart';

class CfdTrading extends StatelessWidget {
  const CfdTrading({Key? key}) : super(key: key);

  static const routeName = '/cfd-trading';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('CFD Trading'),
        ),
        body: ListView(children: const [Center(child: Text("CFD Trading tbd"))]));
  }
}
