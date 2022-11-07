import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';

class Amount {
  Decimal sats = Decimal.zero;

  // We don't expect sat / btc values above 99999 BTC

  final formatterSat = NumberFormat("#############", "en");
  final formatterBtc = NumberFormat("####0.00000000", "en");

  Amount(int sats) {
    this.sats = Decimal.fromInt(sats);
  }

  int get asSats => sats.toBigInt().toInt();

  // Defaults to sats
  AmountDisplay display({Currency? currency, bool? sign, Decimal? price}) {
    var signPrefix = '';
    if (sign != null && sign && !sats.toBigInt().isNegative) {
      signPrefix = '+';
    }

    if (currency != null && currency == Currency.usd) {
      if (price == null) {
        // TODO throw error
      }

      // TODO: conversion into USD using given price
      throw UnimplementedError();
    }

    if (currency != null && currency == Currency.btc) {
      return AmountDisplay(signPrefix + formatterBtc.format(sats.shift(-8).toDouble()), 'btc');
    }

    return AmountDisplay(signPrefix + formatterSat.format(sats.toDouble()), 'sat');
  }

  static final zero = Amount(0);
}

enum Currency { btc, usd }

class AmountDisplay {
  String value;
  String label;

  AmountDisplay(this.value, this.label);
}
