import 'package:flutter/material.dart';

class AppInfoChangeNotifier extends ChangeNotifier {
  late String appVersion;
  late String network;

  void set(String appVersion, String network) {
    this.appVersion = appVersion;
    this.network = network;
    super.notifyListeners();
  }
}
