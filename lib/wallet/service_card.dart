import 'package:flutter/material.dart';
import 'package:ten_ten_one/model/service_model.dart';

class ServiceCard extends StatelessWidget {
  const ServiceCard(this.service, {Key? key}) : super(key: key);

  final Service service;

  @override
  Widget build(BuildContext context) {
    return Center(
        child: Card(
      elevation: 5,
      color: Theme.of(context).colorScheme.surfaceVariant,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15.0),
      ),
      child: SizedBox(
        width: 100,
        height: 100,
        child: Center(
            child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              service.icon,
              color: Colors.black,
              size: 60.0,
              semanticLabel: 'Text to announce in accessibility modes',
            ),
            Text(service.label)
          ],
        )),
      ),
    ));
  }
}
