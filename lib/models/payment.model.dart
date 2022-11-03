import 'package:ten_ten_one/models/amount.model.dart';

class PaymentHistoryItem {
  PaymentType type;
  PaymentStatus status;
  Amount amount;

  PaymentHistoryItem(this.amount, this.type, this.status);
}

enum PaymentStatus { pending, finalized }

enum PaymentType {
  send,
  receive,
  cfdOpen,
  cfdClose,
  sportsbetOpen,
  sportsbetClose,
}
