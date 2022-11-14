import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';
import 'package:ten_ten_one/model/amount.dart';
import 'package:uuid/uuid.dart';

enum Position {
  long,
  short,
}

enum TradingPair {
  btcusd,
  ethusd,
}

extension TradingPairExtension on TradingPair {
  static const icons = {
    TradingPair.btcusd: FontAwesomeIcons.bitcoin,
    TradingPair.ethusd: FontAwesomeIcons.ethereum
  };
  IconData get icon => icons[this]!;
}

enum OrderStatus {
  draft,
  pending,
  open,
  closed,
}

extension OrderStatusExtension on OrderStatus {
  static const displays = {
    OrderStatus.draft: "Draft",
    OrderStatus.pending: "Contract Setup",
    OrderStatus.open: "Open",
    OrderStatus.closed: "Closed",
  };

  String get display => displays[this]!;
}

class Order {
  late String id;

  OrderStatus status;

  int liquidationPrice;
  int openPrice;
  int quantity;
  int leverage;

  Amount fundingRate;
  Amount margin;
  Amount pl;
  Amount estimatedFees;

  DateTime expiry;
  late DateTime updated;

  TradingPair tradingPair;
  Position position;

  Order(
      {required this.fundingRate,
      required this.margin,
      required this.expiry,
      required this.liquidationPrice,
      required this.openPrice,
      required this.pl,
      required this.quantity,
      required this.estimatedFees,
      this.tradingPair = TradingPair.btcusd,
      this.position = Position.long,
      this.leverage = 2,
      this.status = OrderStatus.draft}) {
    updated = DateTime.now();
    id = const Uuid().v4();
  }
}
