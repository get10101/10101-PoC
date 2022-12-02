import 'dart:io';

import 'package:feedback/feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:ten_ten_one/models/service_model.dart';
import 'package:ten_ten_one/utilities/feedback.dart';

final selectedTile = Colors.blue.withAlpha(20);

class Menu extends StatelessWidget {
  const Menu({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    List<Widget> items = [
      DrawerHeader(
        decoration: const BoxDecoration(
          color: Colors.white,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 60,
              width: 60,
              child: SvgPicture.asset("assets/10101_logo.svg"),
            ),
            const Text("One App - All things Bitcoin", style: TextStyle(fontSize: 16)),
            Text(
              "⚡️ Trading, Stacking & More",
              style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.primary),
            )
          ],
        ),
      ),
      ListTile(
        title: Text(ServiceGroup.wallet.label),
        selected: GoRouter.of(context).location == "/",
        selectedTileColor: selectedTile,
        leading: Icon(ServiceGroup.wallet.icon),
        onTap: () {
          Navigator.pop(context);
          GoRouter.of(context).go("/");
        },
      ),
      ListTile(
        title: Text(Service.trade.label),
        selected: GoRouter.of(context).location == Service.trade.route,
        selectedTileColor: selectedTile,
        leading: Icon(Service.trade.icon),
        onTap: () {
          Navigator.pop(context);
          GoRouter.of(context).go(Service.trade.route);
        },
      ),
      ExpansionTile(
          title: Text(ServiceGroup.invest.label),
          leading: Icon(ServiceGroup.invest.icon),
          initiallyExpanded: true,
          children: [
            ListTile(
              title: Text(Service.dca.label),
              leading: Icon(Service.dca.icon),
              selected: GoRouter.of(context).location == Service.dca.route,
              selectedTileColor: selectedTile,
              onTap: () {
                Navigator.pop(context);
                GoRouter.of(context).go(Service.dca.route);
              },
            ),
            ListTile(
              title: Text(Service.savings.label),
              leading: Icon(Service.savings.icon),
              selected: GoRouter.of(context).location == Service.savings.route,
              selectedTileColor: selectedTile,
              onTap: () {
                Navigator.pop(context);
                GoRouter.of(context).go(Service.savings.route);
              },
            ),
          ]),
      ListTile(
        title: Text(Service.settings.label),
        leading: Icon(Service.settings.icon),
        selected: GoRouter.of(context).location == Service.settings.route,
        selectedTileColor: selectedTile,
        onTap: () {
          Navigator.pop(context);
          GoRouter.of(context).go(Service.settings.route);
        },
      ),
    ];

    if (Platform.isAndroid || Platform.isIOS) {
      items.add(ListTile(
        title: const Text("Feedback"),
        leading: const Icon(Icons.feedback_outlined),
        onTap: () {
          Navigator.pop(context);
          BetterFeedback.of(context).show(submitFeedback);
        },
      ));
    }

    return Drawer(
      child: ListView(
        // Important: Remove any padding from the ListView.
        padding: EdgeInsets.zero,
        children: items,
      ),
    );
  }
}
