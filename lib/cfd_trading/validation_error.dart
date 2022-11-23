import 'package:flutter/material.dart';

enum AlertType { info, warning, error }

extension on AlertType {
  static const colors = {
    AlertType.info: Colors.blue,
    AlertType.warning: Colors.orange,
    AlertType.error: Colors.red,
  };
  static const icons = {
    AlertType.info: Icons.info,
    AlertType.warning: Icons.warning,
    AlertType.error: Icons.warning,
  };

  Color get color => colors[this]!;
  IconData get icon => icons[this]!;
}

class Message {
  String title;
  String? details;
  AlertType type;

  Message({required this.title, this.details, required this.type});
}

class AlertMessage extends StatelessWidget {
  const AlertMessage({
    Key? key,
    required this.message,
  }) : super(key: key);

  final Message message;

  @override
  Widget build(BuildContext context) {
    ListTile msg = ListTile(
      leading: Icon(message.type.icon, color: message.type.color),
      title: Text(message.title),
    );

    if (message.details != null) {
      msg = ListTile(
        leading: Icon(message.type.icon, color: message.type.color),
        title: Text(message.title),
        subtitle: Text(message.details!),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: message.type.color,
        ),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
      child: Container(padding: const EdgeInsets.only(top: 10.0, bottom: 10.0), child: msg),
    );
  }
}
