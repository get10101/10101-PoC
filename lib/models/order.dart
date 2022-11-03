enum Position {
  long,
  short,
}

enum TradingPair {
  btcusd,
  ethusd,
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
