import 'package:flutter/material.dart';

class PositionTabs extends StatelessWidget {
  final List<Widget> tabs;
  final List<Widget> content;

  final EdgeInsetsGeometry padding;

  const PositionTabs({super.key, required this.padding, required this.tabs, required this.content});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: tabs.length,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          TabBar(
            labelColor: Colors.orange,
            unselectedLabelColor: Colors.black,
            tabs: tabs.map((tab) => Padding(padding: padding, child: tab)).toList(),
          ),
          Container(
              height: 400, // a height needs to be defined as otherwise nothing will be rendered.
              decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey, width: 0.5))),
              child: TabBarView(
                  children: content.map((c) => Padding(padding: padding, child: c)).toList())),
        ],
      ),
    );
  }
}
