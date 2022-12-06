import 'package:f_logs/f_logs.dart';
import 'package:flutter/material.dart' hide Divider;
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:ten_ten_one/balance.dart';

import 'package:ten_ten_one/models/balance_model.dart';
import 'package:ten_ten_one/utilities/submit_button.dart';
import 'package:ten_ten_one/utilities/divider.dart';
import 'package:ten_ten_one/wallet/channel_change_notifier.dart';

class OpenChannel extends StatefulWidget {
  const OpenChannel({Key? key}) : super(key: key);

  static const route = '/' + subRouteName;
  static const subRouteName = 'open-channel';

  // Max allowed amount is 500_000 sats. This is to protect the maker from running low on liquidity.
  static const maxChannelAmount = 500000;

  @override
  State<OpenChannel> createState() => _OpenChannelState();
}

class _OpenChannelState extends State<OpenChannel> {
  late int takerChannelAmount;
  bool submitting = false;

  final _formKey = GlobalKey<FormState>();
  static const minValue = 1000;

  @override
  void initState() {
    final bitcoinBalance = context.read<BitcoinBalance>();

    final totalBalance = bitcoinBalance.confirmed.asSats +
        bitcoinBalance.pendingInternal.asSats +
        bitcoinBalance.pendingExternal.asSats;

    final maxTakerChannelAmount = (totalBalance).clamp(0, OpenChannel.maxChannelAmount);

    takerChannelAmount = maxTakerChannelAmount;

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final bitcoinBalance = context.watch<BitcoinBalance>();
    final totalBalance = bitcoinBalance.confirmed.asSats +
        bitcoinBalance.pendingInternal.asSats +
        bitcoinBalance.pendingExternal.asSats;

    final maxTakerChannelAmount = (totalBalance).clamp(0, OpenChannel.maxChannelAmount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Open Channel'),
      ),
      body: Form(
        key: _formKey,
        child: SafeArea(
            child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: const [
                    Balance(balanceSelector: BalanceSelector.bitcoin),
                    SizedBox(height: 10),
                    Padding(
                      padding: EdgeInsets.only(left: 20.0, right: 20.0),
                      child: Divider(),
                    )
                  ]),
                  const SizedBox(height: 10),
                  const Center(child: Icon(Icons.private_connectivity_outlined, size: 80)),
                  const SizedBox(height: 10),
                  ListTile(
                      leading: addCircle("1"),
                      title: const Text("Fund your bitcoin wallet"),
                      subtitle: const Text(
                          "In order to establish a Lightning channel between 10101 and you we need to lock some bitcoin on chain.",
                          style: TextStyle(color: Colors.grey))),
                  const SizedBox(height: 15),
                  ListTile(
                      leading: addCircle("2"),
                      title: const Text("Enter channel outbound liquidity"),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              "Define the amount of bitcoin you want to lock into the Lightning channel. 10101 will double it for great inbound liquidity. The max amount you can use is currently $maxTakerChannelAmount sats.",
                              style: const TextStyle(color: Colors.grey)),
                          TextFormField(
                            initialValue: ThousandsSeparatorInputFormatter()
                                .formatEditUpdate(TextEditingValue.empty,
                                    TextEditingValue(text: takerChannelAmount.toString()))
                                .text,
                            readOnly: submitting,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              border: UnderlineInputBorder(),
                            ),
                            inputFormatters: <TextInputFormatter>[
                              FilteringTextInputFormatter.digitsOnly,
                              ThousandsSeparatorInputFormatter(),
                            ],
                            onChanged: (value) {
                              setState(() {
                                try {
                                  takerChannelAmount = int.parse(value.replaceAll(",", ""));
                                } on Exception {
                                  takerChannelAmount = 0;
                                }
                              });

                              _formKey.currentState!.validate();
                            },
                            validator: (value) {
                              if (value == null) {
                                return "Enter channel outbound liquidity";
                              }

                              try {
                                int intVal = int.parse(value.replaceAll(",", ""));

                                if (intVal > totalBalance) {
                                  return "Insufficient balance ($totalBalance)";
                                }

                                if (intVal > maxTakerChannelAmount) {
                                  return "Max channel amount is $maxTakerChannelAmount";
                                }
                                if (intVal < minValue) {
                                  return "Min channel amount is $minValue";
                                }
                              } on Exception {
                                return "Enter channel outbound liquidity";
                              }

                              return null;
                            },
                          )
                        ],
                      )),
                  const SizedBox(height: 15),
                  ListTile(
                      leading: addCircle("3"),
                      title: const Text("Select your maker"),
                      subtitle: const Text(
                          "In this version you can only trade with 10101, but in the future you will be able to choose who to connect to.",
                          style: TextStyle(color: Colors.grey))),
                  const SizedBox(height: 15),
                  ListTile(
                      leading: addCircle("4"),
                      title: const Text("Ready!"),
                      subtitle: const Text(
                          "Hit the 'Open Channel' button and the channel will be created in a few moments.",
                          style: TextStyle(color: Colors.grey))),
                  const SizedBox(height: 15),
                ],
              ),
            ),
            Padding(
                padding: const EdgeInsets.only(right: 20.0),
                child: Container(
                  alignment: Alignment.bottomRight,
                  child: SubmitButton(
                    onPressed: openChannel,
                    label: 'Open Channel',
                    isButtonDisabled:
                        _formKey.currentState == null ? false : !_formKey.currentState!.validate(),
                  ),
                ))
          ],
        )),
      ),
    );
  }

  Future<void> openChannel() async {
    FLog.info(text: "Opening Channel with capacity " + takerChannelAmount.toString());

    // We don't await here because we display the status on the "open channel" card on the Dashboard
    await context.read<ChannelChangeNotifier>().open(takerChannelAmount).then((value) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Waiting for channel to get established"),
      ));
      context.go('/');
    }).catchError((error) {
      FLog.error(text: "Failed to open channel.", exception: error);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: Colors.red,
        content: Text("Failed to open channel. Error: " + error.toString()),
      ));
    });
  }

  Container addCircle(String value) {
    return Container(
      width: 45,
      height: 45,
      decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(100)),
      child: Center(
          child: Text(
        value,
        style: const TextStyle(color: Colors.white, fontSize: 20),
      )),
    );
  }
}

class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  static const separator = ',';

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Handle "deletion" of separator character
    String oldValueText = oldValue.text.replaceAll(separator, '');
    String newValueText = newValue.text.replaceAll(separator, '');

    if (oldValue.text.endsWith(separator) && oldValue.text.length == newValue.text.length + 1) {
      newValueText = newValueText.substring(0, newValueText.length - 1);
    }

    // Only process if the old value and new value are different
    if (oldValueText != newValueText) {
      int selectionIndex = newValue.text.length - newValue.selection.extentOffset;
      final chars = newValueText.split('');

      String newString = '';
      for (int i = chars.length - 1; i >= 0; i--) {
        if ((chars.length - 1 - i) % 3 == 0 && i != chars.length - 1) {
          newString = separator + newString;
        }
        newString = chars[i] + newString;
      }

      return TextEditingValue(
        text: newString.toString(),
        selection: TextSelection.collapsed(
          offset: newString.length - selectionIndex,
        ),
      );
    }

    // If the new value and old value are the same, just return as-is
    return newValue;
  }
}
