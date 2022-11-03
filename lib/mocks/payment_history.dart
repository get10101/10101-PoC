import 'dart:math';

import '../models/amount.model.dart';
import '../models/payment.model.dart';

List<PaymentHistoryItem> mockPaymentHistory(int count) {
  return List<PaymentHistoryItem>.generate(count, (index) => mockPaymentHistoryItem());
}

PaymentHistoryItem mockPaymentHistoryItem() {
  const min = -10000;
  const max = 10000;
  final randomAmount = Random().nextInt(max - min) + min;
  final randomType = Random().nextInt(5);

  return PaymentHistoryItem(
      Amount(randomAmount), PaymentType.values[randomType], PaymentStatus.finalized);
}
