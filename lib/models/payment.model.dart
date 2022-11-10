import 'package:ten_ten_one/models/amount.model.dart';

class PaymentHistoryItemItem {
  PaymentType type;
  PaymentStatus status;
  Amount amount;

  PaymentHistoryItemItem(this.amount, this.type, this.status);
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
