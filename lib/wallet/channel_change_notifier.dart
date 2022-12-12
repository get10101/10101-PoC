import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ten_ten_one/bridge_generated/bridge_definitions.dart';
import 'package:ten_ten_one/cfd_trading/validation_error.dart';
import 'package:ten_ten_one/ffi.io.dart' if (dart.library.html) 'ffi.web.dart';
import 'package:ten_ten_one/wallet/action_card.dart';
import 'package:ten_ten_one/wallet/open_channel.dart';

class ChannelChangeNotifier extends ChangeNotifier {
  ChannelState? state;

  bool isInitialising() => state == ChannelState.Establishing;

  bool isDisconnected() => state == ChannelState.Disconnected;

  bool isAvailable() => state == ChannelState.Available;

  bool isUnavailable() => state == ChannelState.Unavailable;

  Message? status() {
    if (isUnavailable()) {
      return Message(
          title: 'No channel with 10101',
          details: 'You need an open channel with 10101.',
          type: AlertType.warning);
    }

    if (isInitialising()) {
      return Message(
          title: 'Channel not yet confirmed',
          details: 'Please wait until your channel has 1 confirmation.',
          type: AlertType.warning);
    }

    if (isDisconnected()) {
      return Message(
          title: 'Not connected to the 10101 node',
          details: 'Automatically trying to reconnect to the 10101 Lightning node',
          type: AlertType.warning);
    }

    return null;
  }

  CardDetails? buildCardDetails() {
    switch (state) {
      case ChannelState.Unavailable:
        return CardDetails(
            route: OpenChannel.route,
            title: "Open Channel",
            subtitle: "Open a channel to enable trading on Lightning",
            icon: const Icon(Icons.launch));
      case ChannelState.Establishing:
        return CardDetails(
            title: "Establishing Channel",
            subtitle:
                "Waiting for channel to get established. This may take a while, waiting for one confirmation.",
            disabled: true,
            icon: _buildSpinningWheel());
      case ChannelState.Available:
        return null;
      case ChannelState.Disconnected:
        return CardDetails(
            title: "Disconnected from 10101 ",
            subtitle: "Automatically trying to reconnect to 10101 Lightning Node.",
            disabled: true,
            icon: _buildSpinningWheel());
      default:
        // no state has been synchronized yet. hence we will show no card until we have an actual channel state.
        return null;
    }
  }

  Widget _buildSpinningWheel() {
    return Container(
        width: 22,
        height: 22,
        padding: const EdgeInsets.all(2.0),
        child: const CircularProgressIndicator(
          color: Colors.grey,
          strokeWidth: 3,
        ));
  }

  Future<void> open(int amount) async {
    await api.openChannel(takerAmount: amount);
    state = ChannelState.Establishing;
    super.notifyListeners();
  }

  void update(ChannelState state) {
    this.state = state;
    super.notifyListeners();
  }
}
