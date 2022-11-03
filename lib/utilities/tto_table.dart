import 'package:flutter/material.dart';

class TtoRow {
  final String label;
  final String value;
  final IconData? icon;

  const TtoRow({required this.label, required this.value, this.icon});
}

class TtoTable extends StatelessWidget {
  final List<TtoRow> rows;

  const TtoTable(this.rows, {super.key});

  @override
  Widget build(BuildContext context) {
    return Table(
      children: rows.map((row) => buildRow(row)).toList(),
    );
  }

  TableRow buildRow(TtoRow row) {
    return TableRow(children: [
      // Table Row do not yet support a height attribute, hence we need to use the SizedBox
      // workaround. see also https://github.com/flutter/flutter/issues/36936
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(row.label, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 15, width: 0)
      ]),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(
          children: [
            Visibility(visible: row.icon != null, child: Icon(row.icon)),
            Text(row.value, style: const TextStyle(fontSize: 20)),
          ],
        )
      ]),
    ]);
  }
}
