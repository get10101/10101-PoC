import 'package:flutter/material.dart';
import 'package:ten_ten_one/models/amount.model.dart';

class BalanceModel extends ChangeNotifier {
  Amount amount = Amount.zero;

  void update(Amount amount) {
    this.amount = amount;
    super.notifyListeners();
  }
}
