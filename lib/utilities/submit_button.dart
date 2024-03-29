import 'package:flutter/material.dart';

class SubmitButton extends StatefulWidget {
  final Future<void> Function() onPressed;
  final String label;
  final bool isButtonDisabled;

  const SubmitButton(
      {required this.onPressed, required this.label, this.isButtonDisabled = false, Key? key})
      : super(key: key);

  @override
  State<SubmitButton> createState() => _SubmitButtonState();
}

class _SubmitButtonState extends State<SubmitButton> {
  bool submitting = false;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
        label: Text(widget.label),
        icon: !submitting
            ? Container()
            : Container(
                width: 18,
                height: 18,
                padding: const EdgeInsets.all(2.0),
                child: const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              ),
        onPressed: submitting || widget.isButtonDisabled
            ? null
            : () async {
                setState(() {
                  submitting = true;
                });

                try {
                  await widget.onPressed();
                } on Exception {
                  rethrow;
                } finally {
                  setState(() {
                    submitting = false;
                  });
                }
              });
  }
}
