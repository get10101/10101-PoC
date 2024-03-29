import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class TtoRow {
  final String label;
  final String value;
  final ValueType type;
  final String? meta;

  const TtoRow({required this.label, required this.value, required this.type, this.meta});
}

enum ValueType { bitcoin, satoshi, usd, date, contracts, text, link }

class TtoTable extends StatelessWidget {
  final List<TtoRow> rows;

  const TtoTable(this.rows, {super.key});

  @override
  Widget build(BuildContext context) {
    return Table(
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: rows.map((row) => buildRow(row)).toList(),
    );
  }

  TableRow buildRow(TtoRow row) {
    Widget valueChild;
    const fontSize = 18.0;
    switch (row.type) {
      case ValueType.bitcoin:
        valueChild = Text.rich(TextSpan(
          style: const TextStyle(fontSize: fontSize, wordSpacing: 10),
          children: [
            TextSpan(
              text: row.value,
              style: const TextStyle(color: Colors.black, fontSize: fontSize),
            ),
            const WidgetSpan(child: SizedBox(width: 2)), // space between text and icons
            const WidgetSpan(child: Icon(FontAwesomeIcons.bitcoin))
          ],
        ));
        break;
      case ValueType.satoshi:
        valueChild = Text.rich(TextSpan(
          style: const TextStyle(fontSize: fontSize, wordSpacing: 10),
          children: [
            WidgetSpan(
                child: SvgPicture.asset(
              "assets/satoshi_regular_black.svg",
              height: 24,
              color: Colors.black,
            )),
            const WidgetSpan(child: SizedBox(width: 2)), // space between text and icons
            TextSpan(
              text: row.value,
              style: const TextStyle(color: Colors.black, fontSize: fontSize),
            ),
          ],
        ));
        break;
      case ValueType.usd:
        // valueChild = Text(row.value + ' \$', style: const TextStyle(fontSize: fontSize));
        valueChild = Text.rich(TextSpan(
          style: const TextStyle(fontSize: fontSize, wordSpacing: 10),
          children: [
            const WidgetSpan(
                child: Text(
              '\$',
              style: TextStyle(fontSize: fontSize),
            )),
            const WidgetSpan(child: SizedBox(width: 3)), // space between text and icons
            TextSpan(
              text: row.value,
              style: const TextStyle(color: Colors.black, fontSize: fontSize),
            ),
          ],
        ));
        break;
      case ValueType.text:
        valueChild = Text(row.value, style: const TextStyle(fontSize: fontSize));
        break;
      case ValueType.date:
        valueChild = Text.rich(TextSpan(
          style: const TextStyle(fontSize: fontSize, wordSpacing: 10),
          children: [
            TextSpan(
              text: row.value,
              style: const TextStyle(color: Colors.black, fontSize: fontSize),
            ),
          ],
        ));
        break;
      case ValueType.contracts:
        valueChild = Text.rich(TextSpan(
          style: const TextStyle(fontSize: fontSize, wordSpacing: 10),
          children: [
            TextSpan(
              text: row.value,
              style: const TextStyle(color: Colors.black, fontSize: fontSize),
            ),
          ],
        ));
        break;
      case ValueType.link:
        valueChild = Text.rich(TextSpan(
          style: const TextStyle(fontSize: fontSize, wordSpacing: 10),
          children: [
            TextSpan(
              text: row.value,
              style: const TextStyle(color: Colors.black, fontSize: fontSize),
            ),
            const WidgetSpan(child: SizedBox(width: 5)), // space between text and icons
            WidgetSpan(
                child: GestureDetector(
                    onTap: () {
                      launch(row.meta!);
                    },
                    child: const Icon(Icons.open_in_new, color: Colors.blue)))
          ],
        ));
        break;
    }

    return TableRow(
        decoration:
            const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey, width: 0.5))),
        children: [
          // Table Row do not yet support a height attribute, hence we need to use the SizedBox
          // workaround. see also https://github.com/flutter/flutter/issues/36936
          Container(
            padding: const EdgeInsets.only(top: 10, bottom: 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(row.label,
                  style: const TextStyle(fontSize: fontSize, fontWeight: FontWeight.w500))
            ]),
          ),
          Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(top: 10, bottom: 10, left: 25),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(
                children: [valueChild],
              )
            ]),
          ),
        ]);
  }

  Future<void> launch(String url) async {
    if (!await launchUrl(Uri.parse(url))) {
      throw 'Could not launch $url';
    }
  }
}
