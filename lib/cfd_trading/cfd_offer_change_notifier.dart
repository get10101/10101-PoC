import 'package:flutter/material.dart';
import 'package:ten_ten_one/bridge_generated/bridge_definitions.dart';

class CfdOfferChangeNotifier extends ChangeNotifier {
  Offer? offer;

  void update(Offer offer) async {
    this.offer = offer;
    super.notifyListeners();
  }
}
