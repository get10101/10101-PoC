import 'package:f_logs/f_logs.dart';
import 'package:flutter/material.dart' hide Flow;
import 'package:ten_ten_one/bridge_generated/bridge_definitions.dart';
import 'package:ten_ten_one/models/amount.model.dart';
import 'package:ten_ten_one/models/payment.model.dart';

import 'package:ten_ten_one/ffi.io.dart' if (dart.library.html) 'ffi.web.dart';

class WalletInfoChangeNotifier extends ChangeNotifier {
  WalletInfo walletInfo = WalletInfo(
      balance: Balance(
          onChain: OnChain(trustedPending: 0, untrustedPending: 0, confirmed: 0),
          offChain: OffChain(available: 0, pendingClose: 0)),
      bitcoinHistory: List.empty(),
      lightningHistory: List.empty());

  List<PaymentHistoryItem> history = List.empty();

  Amount pending() {
    OffChain offChain = walletInfo.balance.offChain;
    OnChain onChain = walletInfo.balance.onChain;
    return Amount(onChain.untrustedPending + onChain.trustedPending + offChain.pendingClose);
  }

  Amount totalOnChain() {
    OnChain onChain = walletInfo.balance.onChain;
    return Amount(onChain.confirmed + pending().asSats);
  }

  Future<void> update(WalletInfo walletInfo) async {
    this.walletInfo = walletInfo;
    var lth = walletInfo.lightningHistory.map((e) {
      var amount = Amount(e.sats);
      PaymentType type;
      switch (e.flow) {
        case Flow.Inbound:
          type = PaymentType.receive;
          amount = Amount(e.sats);
          break;
        case Flow.Outbound:
          type = PaymentType.send;
          amount = Amount(-e.sats);
          break;
      }
      PaymentStatus status;
      switch (e.status) {
        case HTLCStatus.Failed:
        case HTLCStatus.Expired:
          status = PaymentStatus.failed;
          break;
        case HTLCStatus.Succeeded:
          status = PaymentStatus.finalized;
          break;
        case HTLCStatus.Pending:
          status = PaymentStatus.pending;
          break;
      }
      return PaymentHistoryItem(amount, type, status, e.createdTimestamp, e);
    }).toList();

    var bph = walletInfo.bitcoinHistory.map((bitcoinTxHistoryItem) {
      var amount = bitcoinTxHistoryItem.sent != 0
          ? Amount((bitcoinTxHistoryItem.sent -
                  bitcoinTxHistoryItem.received -
                  bitcoinTxHistoryItem.fee) *
              -1)
          : Amount(bitcoinTxHistoryItem.received);

      var type =
          bitcoinTxHistoryItem.sent != 0 ? PaymentType.sendOnChain : PaymentType.receiveOnChain;

      var status =
          bitcoinTxHistoryItem.isConfirmed ? PaymentStatus.finalized : PaymentStatus.pending;
      return PaymentHistoryItem(
          amount, type, status, bitcoinTxHistoryItem.timestamp, bitcoinTxHistoryItem);
    }).toList();

    final combinedList = [...bph, ...lth];
    combinedList.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    history = combinedList;

    FLog.trace(text: 'Successfully synced payment history');
    super.notifyListeners();
  }

  Future<void> refreshWalletInfo() async {
    try {
      final walletInfo = await api.refreshWalletInfo();
      await update(walletInfo);
      FLog.trace(text: 'Successfully refreshed wallet info');
    } catch (error) {
      FLog.error(text: "Failed to get wallet info:" + error.toString());
    }
  }

  List<PaymentHistoryItem> bitcoinHistory() {
    return history.where((element) => element.type.isBitcoin()).toList();
  }

  List<PaymentHistoryItem> lightningHistory() {
    return history.where((element) => element.type.isLightning()).toList();
  }
}
