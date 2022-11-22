import 'package:flutter/material.dart';

class Divider extends StatelessWidget {
  const Divider({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
        margin: const EdgeInsets.only(top: 5, bottom: 5),
        decoration: BoxDecoration(
            border: Border.all(color: Colors.transparent),
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              stops: const [
                0.1,
                0.5,
                0.9,
              ],
              colors: [
                Theme.of(context).colorScheme.primary.withAlpha(10),
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.primary.withAlpha(10),
              ],
            ),
            borderRadius: BorderRadius.circular(20)),
        child: const SizedBox(height: 1));
  }
}
