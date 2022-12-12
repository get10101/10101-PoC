import 'package:flutter/material.dart';

class StartupChangeNotifier extends ChangeNotifier {
  bool _ready = false;
  String _message = "Starting 10101 ...";

  void ready() {
    _ready = true;
    super.notifyListeners();
  }

  bool isReady() => _ready;

  void set(String message) {
    _message = message;
    super.notifyListeners();
  }

  String message() => _message;
}
