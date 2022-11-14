import 'package:flutter/material.dart';
import 'package:ten_ten_one/model/amount.model.dart';

class LightningBalance extends ChangeNotifier {
  Amount amount = Amount.zero;

  void update(Amount amount) {
    this.amount = amount;
    super.notifyListeners();
  }
}

class BitcoinBalance extends ChangeNotifier {
  Amount amount = Amount.zero;

  void update(Amount amount) {
    this.amount = amount;
    super.notifyListeners();
  }
}
