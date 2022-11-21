import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';
import 'package:ten_ten_one/bridge_generated/bridge_definitions.dart';

extension ContractSymbolExtension on ContractSymbol {
  static const icons = {
    ContractSymbol.BtcUsd: FontAwesomeIcons.bitcoin,
  };
  IconData get icon => icons[this]!;
}
