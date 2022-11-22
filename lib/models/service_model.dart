import 'package:flutter/material.dart';

enum ServiceGroup { wallet, trade, bets, invest }

extension ServiceGroupExtension on ServiceGroup {
  static const labels = {
    ServiceGroup.wallet: "Wallet",
    ServiceGroup.trade: "Trading",
    ServiceGroup.bets: "Bets",
    ServiceGroup.invest: "Stacking"
  };
  static const icons = {
    ServiceGroup.wallet: Icons.wallet,
    ServiceGroup.trade: Icons.query_stats,
    ServiceGroup.bets: Icons.casino,
    ServiceGroup.invest: Icons.table_rows
  };

  String get label => labels[this]!;
  IconData get icon => icons[this]!;
}

enum Service { cfd, sportsbet, exchange, savings }

extension ServiceExtension on Service {
  static const labels = {
    Service.cfd: "CFD Trading",
    Service.sportsbet: "Sports Bets",
    Service.exchange: "Taro Exchange",
    Service.savings: "Saving"
  };
  static const shortLabels = {
    Service.cfd: "CFDs",
    Service.sportsbet: "Bets",
    Service.exchange: "Exchange",
    Service.savings: "Savings"
  };
  static const icons = {
    Service.cfd: Icons.insights,
    Service.sportsbet: Icons.sports_football,
    Service.exchange: Icons.currency_exchange,
    Service.savings: Icons.savings
  };

  String get label => labels[this]!;
  String get shortLabel => shortLabels[this]!;
  IconData get icon => icons[this]!;
}
