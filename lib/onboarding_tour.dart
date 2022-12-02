import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onboarding/onboarding.dart';

class OnboardingTour extends StatefulWidget {
  static const route = "/" + subRouteName;
  static const subRouteName = "onboarding";

  const OnboardingTour({Key? key}) : super(key: key);

  @override
  State<OnboardingTour> createState() => _OnboardingTourState();
}

class _OnboardingTourState extends State<OnboardingTour> {
  late OutlinedButton skipButton;
  late int index;

  final onboardingPagesList = [
    PageModel(
      widget: OnboardingPage(
          title: "WELCOME TO 10101",
          description:
              "The one-stop Bitcoin app with non-custodial trading over Lightning. 10101 is all about keeping your keys where they belong: with you.",
          image:
              Image.asset('assets/Onboarding1-OneAppAllthingsBitcoin.png', fit: BoxFit.scaleDown)),
    ),
    PageModel(
      widget: OnboardingPage(
          title: "ONE APP, TWO WALLETS",
          description:
              "Upon first startup an on-chain wallet and Lightning wallet are created. The Lightning node runs on your phone. \nMake sure to back up the wallet seedphrase as instructed!",
          image: Image.asset('assets/Onboarding2-YourKeysYourBitcoin.png', fit: BoxFit.scaleDown)),
    ),
    PageModel(
      widget: OnboardingPage(
          title: "NOT JUST A WALLET",
          description:
              "10101 offers non-custodial trading over Lightning. No counterparty risk.\nThe app will guide you through (1) funding your wallet, (2) opening a channel and (3) non-custodial CFD trading.",
          image: Image.asset('assets/Onboarding3-TradeNonCustodial.png', fit: BoxFit.scaleDown)),
    ),
  ];

  @override
  void initState() {
    super.initState();
    skipButton = _skipButton();
    index = 0;
  }

  OutlinedButton _skipButton({void Function(int)? setIndex}) {
    return OutlinedButton(
        onPressed: () {
          if (setIndex != null) {
            index = 2;
            setIndex(2);
          }
        },
        child: const Text("Skip"));
  }

  ElevatedButton get _signupButton {
    return ElevatedButton(
        onPressed: () {
          GoRouter.of(context).go('/');
        },
        child: const Text("Get Started"));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: SafeArea(
            child: Onboarding(
      pages: onboardingPagesList,
      onPageChange: (int pageIndex) {
        index = pageIndex;
      },
      startPageIndex: 0,
      footerBuilder: (context, dragDistance, pagesLength, setIndex) {
        return ColoredBox(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.all(45.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CustomIndicator(
                  netDragPercent: dragDistance,
                  pagesLength: pagesLength,
                  indicator: Indicator(
                    activeIndicator: ActiveIndicator(color: Theme.of(context).colorScheme.primary),
                    closedIndicator: ClosedIndicator(color: Theme.of(context).colorScheme.primary),
                    indicatorDesign: IndicatorDesign.polygon(
                        polygonDesign: PolygonDesign(polygon: DesignType.polygon_circle)),
                  ),
                ),
                index == pagesLength - 1 ? _signupButton : _skipButton(setIndex: setIndex)
              ],
            ),
          ),
        );
      },
    )));
  }
}

class OnboardingPage extends StatelessWidget {
  static const pageTitleStyle = TextStyle(
    fontSize: 20.0,
    wordSpacing: 1,
    letterSpacing: 1.2,
    fontWeight: FontWeight.bold,
    color: Colors.black,
  );
  static const pageInfoStyle = TextStyle(
    color: Colors.black,
    letterSpacing: 0.7,
    height: 1.5,
  );

  const OnboardingPage({
    required this.title,
    required this.description,
    required this.image,
    Key? key,
  }) : super(key: key);

  final String description;
  final String title;
  final Widget image;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
        child: SingleChildScrollView(
      controller: ScrollController(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 45.0,
              vertical: 45.0,
            ),
            child: Container(
                constraints: const BoxConstraints(minHeight: 200, maxHeight: 400), child: image),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 45.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                style: pageTitleStyle,
                textAlign: TextAlign.left,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 45.0, vertical: 10.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                description,
                style: pageInfoStyle,
                textAlign: TextAlign.left,
              ),
            ),
          ),
        ],
      ),
    ));
  }
}
