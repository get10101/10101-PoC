import 'package:flutter/material.dart';
import 'package:ten_ten_one/models/amount.model.dart';

class LightningBalance extends ChangeNotifier {
  Amount amount = Amount.zero;

  void update(Amount amount) {
    this.amount = amount;
    super.notifyListeners();
  }
}

class BitcoinBalance extends ChangeNotifier {
  Amount confirmed = Amount.zero;
  Amount pendingInternal = Amount.zero;
  Amount pendingExternal = Amount.zero;
  Amount pendingChannelClose = Amount.zero;

  Amount pending() {
    return Amount(pendingExternal.asSats + pendingInternal.asSats + pendingChannelClose.asSats);
  }

  Amount total() {
    return Amount(confirmed.asSats + pending().asSats);
  }

  void update(Amount confirmed, Amount pendingInternal, Amount pendingExternal,
      Amount pendingChannelClose) {
    this.confirmed = confirmed;
    this.pendingInternal = pendingInternal;
    this.pendingExternal = pendingExternal;
    this.pendingChannelClose = pendingChannelClose;

    super.notifyListeners();
  }
}
