// ignore_for_file: avoid_print

import 'dart:developer';
import 'dart:io';
import 'dart:isolate';

import 'package:ten_ten_one/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vm_service/vm_service_io.dart';

void main() {
  print('integration_test/main.dart starts!');

  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('end-to-end test', () {
    testWidgets('test if the app loads the dashboard', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();
      // run many times to see memory leaks or other problems
      for (var i = 0; i < 20; ++i) {
        await tester.pumpAndSettle();
        expect(find.textContaining('Create Wallet Backup'), findsOneWidget);

        Future.delayed(const Duration(milliseconds: 50));

        // see https://github.com/fzyzcjy/flutter_rust_bridge/issues/19 for details
        await _maybeGC(
            '[NOTE: even if `externalUsage` increases, this is NOT a bug! It is because Flutter\'s ImageCache, which will cache about 100MB. See #19]');
      }
    });
  });
}

// https://stackoverflow.com/questions/63730179/can-we-force-the-dart-garbage-collector
Future<void> _maybeGC([String hint = '']) async {
  final serverUri = (await Service.getInfo()).serverUri;

  if (serverUri == null) {
    print('Please run the application with the --observe parameter!');
    exit(1);
  }

  final isolateId = Service.getIsolateID(Isolate.current)!;
  final vmService = await vmServiceConnectUri(_toWebSocket(serverUri));

  // notice this variable is also large and can consume megabytes of memory...
  final profileAfterMaybeGc =
      await vmService.getAllocationProfile(isolateId, reset: true, gc: true);
  print('Memory usage after maybe GC $hint: ${profileAfterMaybeGc.memoryUsage} '
      'dateLastServiceGC=${profileAfterMaybeGc.dateLastServiceGC} now=${DateTime.now().millisecondsSinceEpoch}');
}

List<String> _cleanupPathSegments(Uri uri) {
  final pathSegments = <String>[];
  if (uri.pathSegments.isNotEmpty) {
    pathSegments.addAll(uri.pathSegments.where(
      (s) => s.isNotEmpty,
    ));
  }
  return pathSegments;
}

String _toWebSocket(Uri uri) {
  final pathSegments = _cleanupPathSegments(uri);
  pathSegments.add('ws');
  return uri.replace(scheme: 'ws', pathSegments: pathSegments).toString();
}
