import 'package:flutter/material.dart';

class SeedBackupModel extends ChangeNotifier {
  bool backup = false;

  void update(bool newState) {
    backup = newState;
    super.notifyListeners();
  }
}
