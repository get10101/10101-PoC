import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:ten_ten_one/models/order.dart';

// Responsible for managing the state across the different Cfd Trading screens.
class CfdTradingState extends ChangeNotifier {
  final List<Order> _orders = [];

  // a cache holding the orders which are currently worked on.
  final ListQueue<Order> _cache = ListQueue();

  // the selected index needs to be managed in an app state as otherwise
  // a the order confirmation screen could not change tabs to the cfd overview
  // screen.
  int selectedIndex = 0;

  void push(Order order) {
    _cache.addLast(order);
  }

  int size() {
    return _cache.length;
  }

  Order peek() {
    return _cache.last;
  }

  Order pop() {
    Order last = _cache.last;
    _cache.removeLast();
    return last;
  }

  List<Order> listOrders() {
    return _orders;
  }

  void persist(Order order) {
    _orders.add(order);
  }

  void notify() {
    super.notifyListeners();
  }
}
