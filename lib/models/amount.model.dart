import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

class Amount {
  Decimal sats = Decimal.zero;

  // We don't expect balance above 99,999 BTC

  final formatterSat = NumberFormat("#,###,###,###,###", "en");
  final formatterBtc = NumberFormat("##,##0.00000000", "en");

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
      return AmountDisplay(
          signPrefix + formatterBtc.format(sats.shift(-8).toDouble()), AmountUnit.bitcoin);
    }

    return AmountDisplay(signPrefix + formatterSat.format(sats.toDouble()), AmountUnit.satoshi);
  }

  static final zero = Amount(0);
}

enum Currency { btc, usd }

class AmountDisplay {
  String value;
  AmountUnit unit;

  AmountDisplay(this.value, this.unit);
}

enum AmountUnit {
  bitcoin,
  satoshi,
}

/// Creates a round icon with a background color.
// ignore: must_be_immutable
class AmountItem extends StatelessWidget {
  String text;
  AmountUnit unit;
  Color iconColor;
  double fontSize;
  double iconSize;
  AmountItem({
    Key? key,
    required this.text,
    required this.unit,
    required this.iconColor,
    this.iconSize = 24.0,
    this.fontSize = 16.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    WidgetSpan icon;
    switch (unit) {
      case AmountUnit.bitcoin:
        icon = const WidgetSpan(child: Icon(FontAwesomeIcons.bitcoin));
        break;
      case AmountUnit.satoshi:
        icon = WidgetSpan(
            child: SvgPicture.asset(
          "assets/satoshi_regular_black.svg",
          height: iconSize,
          color: iconColor,
        ));
        break;
    }

    return Text.rich(
      TextSpan(
        style: const TextStyle(fontSize: 18, wordSpacing: 10),
        children: [
          TextSpan(
            text: text,
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: fontSize),
          ),
          const WidgetSpan(child: SizedBox(width: 2)), // space between text and icons
          icon
        ],
      ),
    );
  }
}
