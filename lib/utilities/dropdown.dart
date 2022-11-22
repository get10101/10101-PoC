import 'package:flutter/material.dart';

class Dropdown extends StatefulWidget {
  final List<String> values;
  final ValueChanged<String?>? onChange;
  final String? value;

  const Dropdown({super.key, required this.values, this.onChange, this.value});

  @override
  State<Dropdown> createState() => _DropdownState();
}

class _DropdownState extends State<Dropdown> {
  String? dropdownValue;

  @override
  Widget build(BuildContext context) {
    setState(() {
      dropdownValue = dropdownValue ?? widget.value ?? widget.values.first;
    });

    return DropdownButton<String>(
      value: dropdownValue,
      elevation: 16,
      style: const TextStyle(color: Colors.black),
      underline: Container(height: 2, color: Theme.of(context).colorScheme.primary),
      onChanged: (String? value) {
        if (widget.onChange != null) {
          widget.onChange!(value);
        }
        setState(() {
          dropdownValue = value!;
        });
      },
      items: widget.values.map<DropdownMenuItem<String>>((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value, style: const TextStyle(fontSize: 20)),
        );
      }).toList(),
    );
  }
}
