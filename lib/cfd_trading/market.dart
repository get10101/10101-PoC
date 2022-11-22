import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_flutter_plus/webview_flutter_plus.dart';

/// Widget rendering BTCUSD TradingView chart
class Market extends StatelessWidget {
  static const String tradingViewBtcUsd = """
<!-- TradingView Widget BEGIN -->
<div class="tradingview-widget-container">
  <div id="tradingview_d98d7"></div>
  <div class="tradingview-widget-copyright"><a href="https://www.tradingview.com/symbols/XBTUSD/?exchange=BITMEX" rel="noopener" target="_blank"><span class="blue-text">XBTUSD Chart</span></a> by TradingView</div>
  <script type="text/javascript" src="https://s3.tradingview.com/tv.js"></script>
  <script type="text/javascript">
  new TradingView.widget(
  {
  "autosize": true,
  "symbol": "BITMEX:XBTUSD",
  "interval": "D",
  "timezone": "Etc/UTC",
  "theme": "light",
  "style": "1",
  "locale": "en",
  "toolbar_bg": "#f1f3f6",
  "enable_publishing": false,
  "allow_symbol_change": true,
  "container_id": "tradingview_d98d7"
}
  );
  </script>
</div>
<!-- TradingView Widget END -->
  """;

  const Market({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (Platform.isAndroid || Platform.isIOS) {
      return WebViewPlus(
        javascriptMode: JavascriptMode.unrestricted,
        onWebViewCreated: (controller) {
          controller.loadString(tradingViewBtcUsd);
        },
      );
    } else {
      return const Text("Market widget is currently available only on iOS/Android.");
    }
  }
}
