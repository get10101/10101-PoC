import 'package:flutter/material.dart';
import 'package:ten_ten_one/bridge_generated/bridge_definitions.dart';

class PositionSelection extends StatefulWidget {
  final ValueChanged<Position?>? onChange;
  final Position? value;

  const PositionSelection({Key? key, this.onChange, this.value}) : super(key: key);

  @override
  State<PositionSelection> createState() => _PositionSelectionState();
}

class _PositionSelectionState extends State<PositionSelection> {
  Position? value;

  @override
  Widget build(BuildContext context) {
    setState(() {
      value = value ?? widget.value ?? Position.Long;
    });
    return Row(
      children: <Widget>[
        Expanded(child: buildButton("Buy / Long", Position.Long)),
        const SizedBox(width: 15),
        Expanded(child: buildButton("Sell / Short", Position.Short)),
      ],
    );
  }

  Widget buildButton(String text, Position position) {
    bool selected = value == position;
    Color color = Position.Long == position ? Colors.green : Colors.red;

    return OutlinedButton(
        onPressed: () {
          if (widget.onChange != null) {
            widget.onChange!(position);
          }
          setState(() {
            value = position;
          });
        },
        child: Text(text, style: TextStyle(color: selected ? Colors.white : color)),
        style: OutlinedButton.styleFrom(
            side: BorderSide(width: 1.0, color: color),
            backgroundColor: selected
                ? Position.Long == position
                    ? Colors.green
                    : Colors.red
                : Colors.white));
  }
}
