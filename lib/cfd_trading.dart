import 'package:flutter/material.dart';
import 'package:ten_ten_one/menu.dart';

class CfdTrading extends StatelessWidget {
  const CfdTrading({Key? key}) : super(key: key);

  static const route = '/cfd-trading';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('CFD Trading'),
        ),
        drawer: const Menu(),
        body: ListView(children: const [Center(child: Text("CFD Trading tbd"))]));
  }
}
