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
    PaymentType.deposit: "Deposit Bitcoin",
    PaymentType.withdraw: "Withdraw Bitcoin",
    PaymentType.channelOpen: "Channel Opened",
    PaymentType.channelClose: "Channel Closed",
    PaymentType.send: "Payment Sent",
    PaymentType.receive: "Payment Received",
    PaymentType.cfdOpen: "CFD Opened",
    PaymentType.cfdClose: "CFD Closed",
    PaymentType.sportsbetOpen: "Sports Bet Started",
    PaymentType.sportsbetClose: "Sports Bet Ended",
  };

  String get display => displays[this]!;
}
