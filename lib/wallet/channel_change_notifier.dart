import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ten_ten_one/bridge_generated/bridge_definitions.dart';
import 'package:ten_ten_one/ffi.io.dart' if (dart.library.html) 'ffi.web.dart';

class ChannelChangeNotifier extends ChangeNotifier {
  ChannelState state = ChannelState.Unavailable;

  bool isInitialising() => state == ChannelState.Establishing;

  bool isAvailable() => state == ChannelState.Available;

  Future<void> open(int amount) async {
    await api.openChannel(takerAmount: amount);
    state = ChannelState.Establishing;
    super.notifyListeners();
  }

  ChannelChangeNotifier init() {
    Timer.periodic(const Duration(seconds: 5), (timer) async {
      final channelState = await api.getChannelState();
      if (state != channelState) {
        state = channelState;
        super.notifyListeners();
      }
    });
    return this;
  }
}
