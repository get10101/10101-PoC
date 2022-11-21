import 'package:flutter/material.dart';

class ChannelError {
  String title;
  String details;

  ChannelError({
    required this.title,
    required this.details,
  });
}

class ValidationError extends StatelessWidget {
  const ValidationError({
    Key? key,
    required this.channelError,
  }) : super(key: key);

  final ChannelError channelError;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20, left: 20, right: 60),
      child: ListTile(
        leading: const Icon(Icons.warning),
        title: Text(channelError.title),
        subtitle: Text(channelError.details),
      ),
    );
  }
}
