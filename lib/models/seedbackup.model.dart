import 'package:flutter/material.dart';

class SeedBackupModel extends ChangeNotifier {
  bool backup = false;

  void update() {
    backup = true;
    super.notifyListeners();
  }
}
