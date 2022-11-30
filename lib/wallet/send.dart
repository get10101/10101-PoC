import 'package:f_logs/f_logs.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ten_ten_one/bridge_generated/bridge_definitions.dart';
import 'package:ten_ten_one/cfd_trading/validation_error.dart';
import 'package:ten_ten_one/ffi.io.dart';
import 'package:ten_ten_one/utilities/submit_button.dart';
import 'package:ten_ten_one/utilities/tto_table.dart';

class Send extends StatefulWidget {
  const Send({Key? key}) : super(key: key);

  static const route = '/' + subRouteName;
  static const subRouteName = 'send';

  @override
  State<Send> createState() => _SendState();
}

class _SendState extends State<Send> {
  String encodedInvoice = "";
  LightningInvoice? invoice;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat();
    formatter.minimumFractionDigits = 0;
    formatter.maximumFractionDigits = 0;
    final widgets = [
      const Text("Encoded Invoice", style: TextStyle(color: Colors.grey, fontSize: 18)),
      Focus(
        onFocusChange: (hasFocus) async {
          if (encodedInvoice.isEmpty || hasFocus) {
            invoice = null;
            return;
          }

          try {
            invoice = await api.decodeInvoice(invoice: encodedInvoice);
            setState(() {
              invoice = invoice;
            });
          } catch (error) {
            FLog.error(text: "Failed to decode invoice $encodedInvoice.", exception: error);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              backgroundColor: Colors.red,
              content: Text("Failed to decode invoice. Error: " + error.toString()),
            ));
          }
        },
        child: TextFormField(
          initialValue: "",
          keyboardType: TextInputType.text,
          onChanged: (text) {
            setState(() {
              encodedInvoice = text;
            });
          },
        ),
      ),
      const SizedBox(
        height: 10.0,
      ),
    ];

    if (invoice != null) {
      widgets.add(const SizedBox(height: 10));
      widgets
          .add(const Text("Invoice Details", style: TextStyle(color: Colors.grey, fontSize: 18)));
      widgets.add(const SizedBox(height: 10));
      widgets.add(TtoTable([
        TtoRow(
            label: 'Amount', value: formatter.format(invoice!.amountSats), type: ValueType.satoshi),
        TtoRow(
            label: 'Created at',
            value: DateFormat('dd.MM.yy-kk:mm')
                .format(DateTime.fromMillisecondsSinceEpoch((invoice!.timestamp * 1000))),
            type: ValueType.date),
        TtoRow(
            label: 'Expires at',
            value: DateFormat('dd.MM.yy-kk:mm')
                .format(DateTime.fromMillisecondsSinceEpoch((invoice!.expiry * 1000))),
            type: ValueType.date),
      ]));

      widgets.add(const SizedBox(height: 20));
      if (invoice!.description.isNotEmpty) {
        widgets.add(const Text("Description", style: TextStyle(color: Colors.grey, fontSize: 18)));
        widgets.add(const SizedBox(height: 10));
        widgets.add(Text(invoice!.description, style: const TextStyle(fontSize: 18)));
      }
      widgets.add(const SizedBox(height: 20));
      widgets.add(AlertMessage(
          message: Message(
              title: "Do you want to send " +
                  formatter.format(invoice!.amountSats) +
                  " sats to " +
                  invoice!.payee +
                  "?",
              type: AlertType.info)));
    }

    return Scaffold(
        appBar: AppBar(
          title: const Text('Send payment'),
        ),
        body: SafeArea(
            child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: widgets),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            SubmitButton(
                                onPressed: send,
                                label: "Pay Invoice",
                                isButtonDisabled: invoice == null)
                          ],
                        ),
                      ],
                    ),
                  ),
                ]))));
  }

  Future<void> send() async {
    FLog.info(text: "Paying invoice $encodedInvoice");
    await api.sendLightningPayment(invoice: encodedInvoice).then((value) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Paid invoice $encodedInvoice"),
      ));

      context.go('/');
    }).catchError((error) {
      FLog.error(text: "Failed to pay invoice $encodedInvoice.", exception: error);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: Colors.red,
        content: Text("Failed to pay invoice $encodedInvoice. Error: " + error.toString()),
      ));
    });
  }
}
