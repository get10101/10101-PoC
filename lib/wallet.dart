import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
// isolate package help us creating isolate and getting the port back easily.
import 'package:isolate/ports.dart';
import 'dart:io' show Directory;
import 'package:path_provider/path_provider.dart';

import 'ffi.io.dart' if (dart.library.html) 'ffi.web.dart';
export 'ffi.io.dart' if (dart.library.html) 'ffi.web.dart' show api;

class Wallet {

  Future<String> buildWallet() async {
    final completer = Completer<String>();
    // Create a SendPort that accepts only one message.
    final sendPort = singleCompletePort(completer);
    Directory appDocDir = await getApplicationDocumentsDirectory();
    String appDocPath = appDocDir.path;
    final res = await api.buildWallet(port: sendPort.nativePort, dataDir: appDocPath);

    if (res != 1) {
      _throwError();
    }
    return completer.future;
  }

  void _throwError() {
    print("error");
    throw "error";
  }
}