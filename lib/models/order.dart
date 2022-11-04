import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';

enum Position {
  long,
  short,
}

enum TradingPair {
  btcusd,
  ethusd,
}

extension TradingPairExtension on TradingPair {
  static const icons = {TradingPair.btcusd: FontAwesomeIcons.bitcoin, TradingPair.ethusd: FontAwesomeIcons.ethereum};
  IconData get icon => icons[this]!;
}

class Order {
  int liquidationPrice;
  int openPrice;
  int quantity;
  int leverage;

  double fundingRate;
  double margin;
  double unrealizedPL;
  double estimatedFees;

  DateTime expiry;

  TradingPair tradingPair;
  Position position;

  Order({
    required this.fundingRate,
    required this.margin,
    required this.expiry,
    required this.liquidationPrice,
    required this.openPrice,
    required this.unrealizedPL,
    required this.quantity,
    required this.estimatedFees,
    this.tradingPair = TradingPair.btcusd,
    this.position = Position.long,
    this.leverage = 2,
  });
}
