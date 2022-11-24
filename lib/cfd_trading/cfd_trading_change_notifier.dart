import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ten_ten_one/bridge_generated/bridge_definitions.dart';
import 'package:ten_ten_one/ffi.io.dart' if (dart.library.html) 'ffi.web.dart';

/// Responsible for managing the state across the different Cfd Trading screens.
class CfdTradingChangeNotifier extends ChangeNotifier {
  List<Cfd> cfds = [];

  // the selected tab index needs to be managed in an app state as otherwise
  // a the order confirmation screen could not change tabs to the cfd overview
  // screen.
  int selectedIndex = 0;

  // the expanded flag is manage here to remember if the user has collapsed the
  // closed orders or not. It seems after routing the ephemeral state gets lost,
  // hence we have to manage that state here as app state.
  bool expanded = false;

  void notify() {
    super.notifyListeners();
  }

  Future<void> refreshCfdList() async {
    cfds = await api.listCfds();
    super.notifyListeners();
  }

  CfdTradingChangeNotifier init() {
    refreshCfdList();
    Timer.periodic(const Duration(seconds: 20), (timer) {
      refreshCfdList();
    });
    return this;
  }
}
