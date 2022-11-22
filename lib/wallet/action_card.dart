import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ActionCard extends StatelessWidget {
  const ActionCard(
      {required this.route, required this.title, required this.subtitle, IconData? icon, Key? key})
      : super(key: key);

  final String title;
  final String route;
  final String subtitle;
  final IconData icon = Icons.warning;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTap: () => {GoRouter.of(context).go(route)},
        child: Card(
          elevation: 4,
          child: ClipPath(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: Theme.of(context).colorScheme.primary, width: 5),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  ListTile(
                    leading: Icon(icon),
                    title: Text(title),
                    subtitle: Text(subtitle, textAlign: TextAlign.justify),
                  ),
                ],
              ),
            ),
            clipper: ShapeBorderClipper(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5))),
          ),
        ));
  }
}
