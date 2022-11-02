import 'package:flutter/material.dart';

enum ServiceGroup { wallet, trade, bets }

extension ServiceGroupExtension on ServiceGroup {
  static const labels = {
    ServiceGroup.wallet: "Wallet",
    ServiceGroup.trade: "Trading",
    ServiceGroup.bets: "Bets"
  };
  static const icons = {
    ServiceGroup.wallet: Icons.wallet,
    ServiceGroup.trade: Icons.query_stats,
    ServiceGroup.bets: Icons.casino
  };

  String get label => labels[this]!;
  IconData get icon => icons[this]!;
}

enum Service { cfd, sportsbet }

extension ServiceExtension on Service {
  static const labels = {Service.cfd: "CFD Trading", Service.sportsbet: "Sports Bets"};
  static const icons = {Service.cfd: Icons.insights, Service.sportsbet: Icons.sports_football};

  String get label => labels[this]!;
  IconData get icon => icons[this]!;
}
