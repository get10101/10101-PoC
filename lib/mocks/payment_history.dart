import 'dart:math';

import '../models/amount.model.dart';
import '../models/payment.model.dart';

List<PaymentHistoryItem> mockPaymentHistory(int count) {
  return List<PaymentHistoryItem>.generate(count, (index) => mockPaymentHistoryItem());
}

List<PaymentHistoryItem> mockPaymentHistoryLightning(int count) {
  return List<PaymentHistoryItem>.generate(count, (index) => mockPaymentHistoryItem());
}

List<PaymentHistoryItem> mockPaymentHistoryBitcoin(int count) {
  return List<PaymentHistoryItem>.generate(count, (index) => mockPaymentHistoryItemBitcoin());
}

PaymentHistoryItem mockPaymentHistoryItem() {
  const min = -10000;
  const max = 10000;
  final randomAmount = Random().nextInt(max - min) + min;
  final randomType = Random().nextInt(7);

  return PaymentHistoryItem(
      Amount(randomAmount), PaymentType.values[randomType], PaymentStatus.finalized);
}

PaymentHistoryItem mockPaymentHistoryItemBitcoin() {
  const min = -10000;
  const max = 10000;
  final randomAmount = Random().nextInt(max - min) + min;
  final randomBitcoinType = Random().nextInt(3);

  return PaymentHistoryItem(
      Amount(randomAmount), PaymentType.values[randomBitcoinType], PaymentStatus.finalized);
}

PaymentHistoryItem mockPaymentHistoryItemLightning() {
  const min = -10000;
  const max = 10000;
  final randomAmount = Random().nextInt(max - min) + min;
  final randomLightningType = Random().nextInt(5) + 2;

  return PaymentHistoryItem(
      Amount(randomAmount), PaymentType.values[randomLightningType], PaymentStatus.finalized);
}
