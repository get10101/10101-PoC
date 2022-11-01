import 'package:flutter/material.dart';

class Divider extends StatelessWidget {
  const Divider({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
        margin: const EdgeInsets.fromLTRB(15, 15, 15, 15),
        child: const Card(elevation: 0, color: Colors.grey, child: SizedBox(height: 5)));
  }
}
