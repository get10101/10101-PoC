import 'package:flutter/material.dart';
import 'package:ten_ten_one/models/order.dart';

// Responsible for managing the state accross the different Cfd Trading screens.
class CfdTradingState extends ChangeNotifier {
  final List<Order> _orders = [];

  // the selected index needs to be managed in an app state as otherwise
  // a the order confirmation screen could not change tabs to the cfd overview
  // screen.
  int selectedIndex = 0;
  Order? _draftOrder;

  void startOrder(Order order) {
    _draftOrder = order;
  }

  Order getDraftOrder() {
    return _draftOrder!;
  }

  bool isStarted() {
    return _draftOrder != null;
  }

  List<Order> listOrders() {
    return _orders;
  }

  void finishOrder() {
    // transform draft order to pending order and add to orders.
    final order = _draftOrder!;
    order.status = OrderStatus.pending;
    order.updated = DateTime.now();
    _orders.add(order);

    // remove draft order from state.
    _draftOrder = null;
    // change tab to the cfds overview.
    selectedIndex = 1;

    super.notifyListeners();
  }
}
