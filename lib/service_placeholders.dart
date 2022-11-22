import 'package:flutter/material.dart';
import 'package:ten_ten_one/balance.dart';
import 'package:ten_ten_one/menu.dart';

import 'app_bar_with_balance.dart';
import 'models/service_model.dart';

class ServicePlaceholder extends StatelessWidget {
  const ServicePlaceholder({required this.service, required this.description, Key? key})
      : super(key: key);

  final Service service;
  final String description;

  @override
  Widget build(BuildContext context) {
    const balanceSelector = BalanceSelector.lightning;

    return Scaffold(
      drawer: const Menu(),
      appBar: PreferredSize(
          child: const AppBarWithBalance(balanceSelector: balanceSelector),
          preferredSize: Size.fromHeight(balanceSelector.preferredHeight)),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: Column(
            children: [
              SizedBox(height: 40, child: Icon(service.icon)),
              Text(service.label),
              const Divider(),
              Text(description)
            ],
          ),
        ),
      ),
    );
  }
}
