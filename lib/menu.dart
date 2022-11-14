import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:ten_ten_one/model/service_model.dart';

class Menu extends StatelessWidget {
  const Menu({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        // Important: Remove any padding from the ListView.
        padding: EdgeInsets.zero,
        children: [
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
                const Text("One-Stop ⚡️ Wallet", style: TextStyle(fontSize: 16)),
                const Text(
                  "Trading, Bets & More",
                  style: TextStyle(fontSize: 14, color: Colors.orange),
                )
              ],
            ),
          ),
          ListTile(
            title: Text(ServiceGroup.wallet.label),
            leading: Icon(ServiceGroup.wallet.icon),
            onTap: () {
              GoRouter.of(context).go("/");
            },
          ),
          ExpansionTile(
            title: Text(ServiceGroup.trade.label),
            leading: Icon(ServiceGroup.trade.icon),
            initiallyExpanded: true,
            children: [
              ListTile(
                title: Text(Service.cfd.label),
                leading: Icon(Service.cfd.icon),
                onTap: () {
                  GoRouter.of(context).go("/cfd-trading");
                },
              ),
            ],
          ),
          ExpansionTile(
            title: Text(ServiceGroup.bets.label),
            leading: Icon(ServiceGroup.bets.icon),
            initiallyExpanded: true,
            children: [
              ListTile(
                title: Text(Service.sportsbet.label),
                leading: Icon(Service.sportsbet.icon),
                onTap: () {
                  // TODO: PLug in sports bets screen
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
