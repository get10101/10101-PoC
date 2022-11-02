import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ten_ten_one/cfd_trading/cfd_offer.dart';
import 'package:ten_ten_one/cfd_trading/cfd_order_confirmation.dart';
import 'package:ten_ten_one/menu.dart';

class CfdTrading extends StatefulWidget {
  static const route = '/cfd-trading';

  const CfdTrading({Key? key}) : super(key: key);

  @override
  State<CfdTrading> createState() => _CfdTradingState();
}

class _CfdTradingState extends State<CfdTrading> {
  int _selectedIndex = 0;
  final List<Widget> _pages = <Widget>[
    const CfdOffer(),
    Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Text("My CFDs"),
          Icon(Icons.format_list_bulleted_sharp),
        ],
      ),
    ),
    Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Text("Market"),
          Icon(Icons.candlestick_chart_sharp),
        ],
      ),
    ),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CFD Trading'),
      ),
      drawer: const Menu(),
      body: _pages.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.handshake),
            label: 'Trade',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.format_list_bulleted_sharp),
            label: 'My CFDs',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.candlestick_chart_sharp),
            label: 'Market',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.orange,
        onTap: _onItemTapped,
      ),
      floatingActionButton: Visibility(
        visible: _selectedIndex == 0,
        child: FloatingActionButton(
          onPressed: () {
            GoRouter.of(context).go(CfdTrading.route + '/' + CfdOrderConfirmation.subRouteName);
          },
          backgroundColor: Colors.orange,
          child: const Icon(Icons.shopping_cart_checkout),
        ),
      ),
    );
  }
}
