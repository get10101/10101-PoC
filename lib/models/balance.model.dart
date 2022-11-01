import 'package:flutter/material.dart';

class BalanceModel extends ChangeNotifier {
  // TODO: Change to 0, just to see that it updates :)
  int amount = -1;

  void update(int amount) {
    this.amount = amount;
    super.notifyListeners();
  }
}
