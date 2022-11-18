import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';
import 'package:ten_ten_one/bridge_generated/bridge_definitions.dart';
import 'package:ten_ten_one/ffi.io.dart' if (dart.library.html) 'ffi.web.dart';

extension ContractSymbolExtension on ContractSymbol {
  static const icons = {
    ContractSymbol.BtcUsd: FontAwesomeIcons.bitcoin,
  };
  IconData get icon => icons[this]!;
}

// TODO: That's a quick fix to easily access the order methods. However the cfd should
// probably contain the order from which it has been created, since the properties is anyways
// contained in the cfd.
extension CfdToOrder on Cfd {
  Order getOrder() {
    return Order(
        bridge: api,
        leverage: leverage,
        quantity: quantity,
        contractSymbol: contractSymbol,
        position: position,
        openPrice: openPrice);
  }
}
