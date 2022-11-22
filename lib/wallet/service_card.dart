import 'package:flutter/material.dart';
import 'package:ten_ten_one/models/service_model.dart';

class ServiceCard extends StatelessWidget {
  const ServiceCard(this.service, {Key? key}) : super(key: key);

  final Service service;

  @override
  Widget build(BuildContext context) {
    return Center(
        child: Card(
      elevation: 4,
      color: Theme.of(context).colorScheme.primary,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15.0),
          side: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 1,
          )),
      child: SizedBox(
        width: 80,
        height: 80,
        child: Center(
            child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              service.icon,
              color: Colors.white,
              size: 30.0,
              semanticLabel: 'Text to announce in accessibility modes',
            ),
            SizedBox(
                width: 60,
                child: Text(
                  service.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ))
          ],
        )),
      ),
    ));
  }
}
