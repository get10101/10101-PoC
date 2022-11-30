import 'package:ten_ten_one/models/amount.model.dart';

class PaymentHistoryItem {
  PaymentType type;
  PaymentStatus status;
  Amount amount;
  num timestamp;
  dynamic data;

  PaymentHistoryItem(this.amount, this.type, this.status, this.timestamp, this.data);
}

enum PaymentStatus { pending, finalized, failed }

enum PaymentType {
  // Bitcoin only
  receiveOnChain,
  sendOnChain,

  // Bitcoin and Lightning (reduce Bitcoin, add to Lightning)
  channelOpen,
  // Bitcoin and Lightning (reduce Lightning, add to Bitcoin)
  channelClose,

  // Lightning only
  send,
  receive,
  cfdOpen,
  cfdClose,
  sportsbetOpen,
  sportsbetClose,
}

extension PaymentTypeExtension on PaymentType {
  static const displays = {
    PaymentType.receiveOnChain: "You received",
    PaymentType.sendOnChain: "You sent",
    PaymentType.channelOpen: "Channel Opened",
    PaymentType.channelClose: "Channel Closed",
    PaymentType.send: "You sent",
    PaymentType.receive: "You received",
    PaymentType.cfdOpen: "CFD Opened",
    PaymentType.cfdClose: "CFD Closed",
    PaymentType.sportsbetOpen: "Sports Bet Started",
    PaymentType.sportsbetClose: "Sports Bet Ended",
  };

  static const displayBitcoin = {
    PaymentType.receiveOnChain: true,
    PaymentType.sendOnChain: true,
    PaymentType.channelOpen: true,
    PaymentType.channelClose: true,
    PaymentType.send: false,
    PaymentType.receive: false,
    PaymentType.cfdOpen: false,
    PaymentType.cfdClose: false,
    PaymentType.sportsbetOpen: false,
    PaymentType.sportsbetClose: false,
  };

  String get display => displays[this]!;

  bool isBitcoin() => displayBitcoin[this]!;

  bool isLightning() => !isBitcoin();
}
