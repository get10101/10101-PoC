import 'dart:math';

import '../models/amount.model.dart';
import '../models/payment.model.dart';

List<PaymentHistoryItemItem> mockPaymentHistory(int count) {
  return List<PaymentHistoryItemItem>.generate(count, (index) => mockPaymentHistoryItem());
}

List<PaymentHistoryItemItem> mockPaymentHistoryLightning(int count) {
  return List<PaymentHistoryItemItem>.generate(count, (index) => mockPaymentHistoryItem());
}

List<PaymentHistoryItemItem> mockPaymentHistoryBitcoin(int count) {
  return List<PaymentHistoryItemItem>.generate(count, (index) => mockPaymentHistoryItemBitcoin());
}

PaymentHistoryItemItem mockPaymentHistoryItem() {
  const min = -10000;
  const max = 10000;
  final randomAmount = Random().nextInt(max - min) + min;
  final randomType = Random().nextInt(7);

  return PaymentHistoryItemItem(
      Amount(randomAmount), PaymentType.values[randomType], PaymentStatus.finalized);
}

PaymentHistoryItemItem mockPaymentHistoryItemBitcoin() {
  const min = -10000;
  const max = 10000;
  final randomAmount = Random().nextInt(max - min) + min;
  final randomBitcoinType = Random().nextInt(3);

  return PaymentHistoryItemItem(
      Amount(randomAmount), PaymentType.values[randomBitcoinType], PaymentStatus.finalized);
}

PaymentHistoryItemItem mockPaymentHistoryItemLightning() {
  const min = -10000;
  const max = 10000;
  final randomAmount = Random().nextInt(max - min) + min;
  final randomLightningType = Random().nextInt(5) + 2;

  return PaymentHistoryItemItem(
      Amount(randomAmount), PaymentType.values[randomLightningType], PaymentStatus.finalized);
}
