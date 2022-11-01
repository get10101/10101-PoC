import 'package:flutter/material.dart';

enum ServiceGroup { trade, bets }

extension ServiceGroupExtension on ServiceGroup {
  static const labels = {Service.cfd: "Trading", Service.sportsbet: "Bets"};
}

enum Service { cfd, sportsbet }

extension ServiceExtension on Service {
  static const labels = {Service.cfd: "CFD Trading", Service.sportsbet: "Sports Bets"};
  static const icons = {Service.cfd: Icons.insights, Service.sportsbet: Icons.sports_football};

  String get label => labels[this]!;
  IconData get icon => icons[this]!;
}
