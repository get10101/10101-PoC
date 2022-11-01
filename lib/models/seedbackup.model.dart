import 'package:flutter/foundation.dart';

class SeedBackupModel extends ChangeNotifier {
  bool backup = false;

  void update() {
    backup = true;
    super.notifyListeners();
  }
}
