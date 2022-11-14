import 'package:ten_ten_one/models/amount.model.dart';

class PaymentHistoryItem {
  PaymentType type;
  PaymentStatus status;
  Amount amount;

  PaymentHistoryItem(this.amount, this.type, this.status);
}

enum PaymentStatus { pending, finalized }

enum PaymentType {
  // Bitcoin only
  deposit,
  withdraw,

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
    PaymentType.deposit: "Bitcoin Deposited",
    PaymentType.withdraw: "Bitcoin Withdrawn",
    PaymentType.channelOpen: "Channel Opened",
    PaymentType.channelClose: "Channel Closed",
    PaymentType.send: "Payment Sent",
    PaymentType.receive: "Payment Received",
    PaymentType.cfdOpen: "CFD Opened",
    PaymentType.cfdClose: "CFD Closed",
    PaymentType.sportsbetOpen: "Sports Bet Started",
    PaymentType.sportsbetClose: "Sports Bet Ended",
  };

  static const displayBitcoin = {
    PaymentType.deposit: true,
    PaymentType.withdraw: true,
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
}
