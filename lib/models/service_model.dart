import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

enum ServiceGroup { wallet, trade, dca, invest }

extension ServiceGroupExtension on ServiceGroup {
  static const labels = {
    ServiceGroup.wallet: "Wallet",
    ServiceGroup.trade: "Trading",
    ServiceGroup.dca: "DCA",
    ServiceGroup.invest: "Stacking"
  };
  static const icons = {
    ServiceGroup.wallet: Icons.wallet,
    ServiceGroup.trade: Icons.query_stats,
    ServiceGroup.dca: FontAwesomeIcons.moneyBill1,
    ServiceGroup.invest: Icons.table_rows
  };

  String get label => labels[this]!;
  IconData get icon => icons[this]!;
}

enum Service { trade, dca, savings }

extension ServiceExtension on Service {
  static const labels = {
    Service.trade: "Trading",
    Service.dca: "Dollar Cost Average",
    Service.savings: "Saving"
  };
  static const shortLabels = {
    Service.trade: "Trade",
    Service.dca: "DCA",
    Service.savings: "Savings"
  };
  static const icons = {
    Service.trade: Icons.insights,
    Service.dca: FontAwesomeIcons.moneyBill1,
    Service.savings: Icons.savings
  };
  static const routes = {
    Service.trade: "/trading",
    Service.dca: "/dca",
    Service.savings: "/savings"
  };

  String get label => labels[this]!;
  String get shortLabel => shortLabels[this]!;
  IconData get icon => icons[this]!;
  String get route => routes[this]!;
}
