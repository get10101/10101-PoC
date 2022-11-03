import 'package:decimal/decimal.dart';

class Amount {
  Decimal sats = Decimal.zero;

  Amount(int sats) {
    this.sats = Decimal.fromInt(sats);
  }

  int get asSats => sats.toBigInt().toInt();

  // Defaults to sats
  AmountDisplay display([Currency? currency, Decimal? price]) {
    if (currency != null && currency == Currency.usd) {
      if (price == null) {
        // TODO throw error
      }

      // TODO: conversion into USD using given price
      throw UnimplementedError();
    }

    if (currency != null && currency == Currency.btc) {
      return AmountDisplay(sats.shift(-8).toDouble(), 'btc');
    }

    return AmountDisplay(sats.toDouble(), 'sat');
  }

  static final zero = Amount(0);
}

enum Currency { btc, usd }

class AmountDisplay {
  double value;
  String label;

  AmountDisplay(this.value, this.label);
}
