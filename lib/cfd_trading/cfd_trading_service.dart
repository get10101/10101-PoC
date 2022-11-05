import 'package:flutter/material.dart';
import 'package:ten_ten_one/models/order.dart';

// Responsible for managing the state across the different Cfd Trading screens.
class CfdTradingService extends ChangeNotifier {
  final List<Order> _orders = [];

  // the selected index needs to be managed in an app state as otherwise
  // a the order confirmation screen could not change tabs to the cfd overview
  // screen.
  int selectedIndex = 0;

  List<Order> listOrders() {
    return _orders;
  }

  void persist(Order order) {
    final index = _orders.indexWhere((o) => o.id == order.id);

    if (index >= 0) {
      _orders.removeAt(index);
    }

    _orders.add(order);

    super.notifyListeners();
  }
}
