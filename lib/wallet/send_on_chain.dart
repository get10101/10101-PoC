import 'package:flutter/material.dart';

class SendOnChain extends StatefulWidget {
  const SendOnChain({Key? key}) : super(key: key);

  static const route = '/' + subRouteName;
  static const subRouteName = 'send-on-chain';

  @override
  State<SendOnChain> createState() => _SendOnChainState();
}

class _SendOnChainState extends State<SendOnChain> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send Bitcoin'),
      ),
      body: const SafeArea(child: Text("tbd")),
    );
  }
}
