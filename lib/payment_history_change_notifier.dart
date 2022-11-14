import 'package:flutter/material.dart';
import 'models/payment.model.dart';

class PaymentHistory extends ChangeNotifier {
  List<PaymentHistoryItem> history = List.empty();

  void update(List<PaymentHistoryItem> history) {
    this.history = history;
    super.notifyListeners();
  }

  List<PaymentHistoryItem> bitcoinHistory() {
    return history.where((element) => element.type.isBitcoin()).toList();
  }
}
