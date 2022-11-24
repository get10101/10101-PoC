import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ten_ten_one/ffi.io.dart' if (dart.library.html) 'ffi.web.dart';

class ChannelChangeNotifier extends ChangeNotifier {
  bool _init = false;
  bool isInitialising() => _init;

  Future<void> open(int amount) async {
    super.notifyListeners();
    _init = true;
    await api.openChannel(takerAmount: amount);
    Timer(const Duration(seconds: 60), () => _init = false);
  }
}
