import 'package:flutter/cupertino.dart';

class BalanceModel extends ChangeNotifier {
  int amount = 0;

  void update(int amount) {
    this.amount = amount;
    super.notifyListeners();
  }
}
