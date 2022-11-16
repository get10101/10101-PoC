import 'package:ten_ten_one/bridge_generated/bridge_definitions.dart';
import 'package:ten_ten_one/ffi.io.dart' if (dart.library.html) 'ffi.web.dart';

class Environment {
  static Config parse() {
    Network network = getNetwork();
    String endpoint = const String.fromEnvironment('MAKER_IP', defaultValue: '127.0.0.1');
    // Maker PK is derived from our checked in regtest maker seed
    String makerPublicKey = const String.fromEnvironment("MAKER_PK",
        defaultValue: "02cb6517193c466de0688b8b0386dbfb39d96c3844525c1315d44bd8e108c08bc1");
    int lightningPort = const int.fromEnvironment("MAKER_PORT_LIGHTNING", defaultValue: 9045);
    int httpPort = const int.fromEnvironment("MAKER_PORT_HTTP", defaultValue: 8000);

    String p2pEndpoint = const String.fromEnvironment('MAKER_P2P_ENDPOINT');
    if (p2pEndpoint.contains("@")) {
      final split = p2pEndpoint.split("@");
      makerPublicKey = split[0];
      if (split[1].contains(':')) {
        endpoint = split[1].split(':')[0];
        lightningPort = int.parse(split[1].split(':')[1]);
      }
    }

    return Config(
        network: network,
        endpoint: endpoint,
        makerPublicKey: makerPublicKey,
        lightningPort: lightningPort,
        httpPort: httpPort,
        bridge: api);
  }

  static Network getNetwork() {
    String network = const String.fromEnvironment('NETWORK', defaultValue: "regtest");
    switch (network) {
      case 'testnet':
        return Network.Testnet;
      case 'mainnet':
        return Network.Mainnet;
      default:
        return Network.Regtest;
    }
  }
}
