import 'package:flutter/material.dart';

class Divider extends StatelessWidget {
  const Divider({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
        margin: const EdgeInsets.only(top: 10, bottom: 10),
        decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            color: Colors.grey,
            borderRadius: BorderRadius.circular(20)),
        child: const SizedBox(height: 5));
  }
}
