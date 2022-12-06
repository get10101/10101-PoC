import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CardDetails {
  final String title;
  String? route;
  final String subtitle;
  final Widget icon;
  bool disabled;

  CardDetails(
      {required this.title,
      this.route,
      required this.subtitle,
      required this.icon,
      this.disabled = false});
}

class ActionCard extends StatelessWidget {
  final CardDetails details;

  const ActionCard(this.details, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTap: details.disabled || details.route == null
            ? null
            : () => {GoRouter.of(context).go(details.route!)},
        child: Card(
          color: details.disabled ? Colors.grey.shade300 : Colors.white,
          elevation: 4,
          child: ClipPath(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                      color: details.disabled ? Colors.grey : Theme.of(context).colorScheme.primary,
                      width: 5),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  ListTile(
                    leading: details.icon,
                    title: Text(details.title),
                    subtitle: Text(details.subtitle, textAlign: TextAlign.justify),
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
