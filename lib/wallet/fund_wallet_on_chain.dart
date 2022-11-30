import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:ten_ten_one/wallet/drain_faucet.dart';
import 'package:ten_ten_one/wallet/receive_on_chain.dart';

class FundWalletOnChain extends StatelessWidget {
  const FundWalletOnChain({Key? key}) : super(key: key);

  static const route = '/' + subRouteName;
  static const subRouteName = 'fund-wallet-on-chain';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fund Wallet'),
      ),
      body: SafeArea(
          child: Container(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            SizedBox(
                child: Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(100),
              ),
              child: const RotatedBox(
                quarterTurns: 1,
                child: IconButton(
                  icon: Icon(
                    FontAwesomeIcons.arrowRightToBracket,
                    color: Colors.white,
                  ),
                  onPressed: null,
                ),
              ),
            )),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Text("Fund your wallet",
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Flexible(
                  child: Text(
                    "Get bitcoin from our faucet or deposit on-chain to get started.",
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView(
                children: [
                  const Divider(),
                  InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const DrainFaucet()),
                        );
                      },
                      child: const ListTile(
                        title: Text("Drain faucet"),
                        trailing: Icon(FontAwesomeIcons.chevronRight),
                      )),
                  const Divider(),
                  InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ReceiveOnChain()),
                        );
                      },
                      child: const ListTile(
                        title: Text("Deposit bitcoin"),
                        trailing: Icon(FontAwesomeIcons.chevronRight),
                      )),
                  const Divider(),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                    onPressed: () {
                      context.go("/");
                    },
                    child: const Text('Do this later'))
              ],
            ),
          ],
        ),
      )),
    );
  }
}
