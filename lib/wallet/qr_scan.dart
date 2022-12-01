import 'package:f_logs/model/flog/flog.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:ten_ten_one/wallet/send.dart';

class QrScanChangeNotifier extends ChangeNotifier {
  String code = "";

  void update(String code) {
    this.code = code;
    super.notifyListeners();
  }
}

class QrScan extends StatefulWidget {
  const QrScan({Key? key}) : super(key: key);

  static const route = '/' + subRouteName;
  static const subRouteName = 'qr-scan';

  @override
  State<QrScan> createState() => _QrScanState();
}

class _QrScanState extends State<QrScan> {
  MobileScannerController cameraController = MobileScannerController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('QR Scanner'),
          actions: [
            IconButton(
              color: Colors.white,
              icon: ValueListenableBuilder(
                valueListenable: cameraController.torchState,
                builder: (context, state, child) {
                  switch (state as TorchState) {
                    case TorchState.off:
                      return const Icon(Icons.flash_off, color: Colors.grey);
                    case TorchState.on:
                      return const Icon(Icons.flash_on, color: Colors.yellow);
                  }
                },
              ),
              iconSize: 32.0,
              onPressed: () => cameraController.toggleTorch(),
            ),
            IconButton(
              color: Colors.white,
              icon: ValueListenableBuilder(
                valueListenable: cameraController.cameraFacingState,
                builder: (context, state, child) {
                  switch (state as CameraFacing) {
                    case CameraFacing.front:
                      return const Icon(Icons.camera_front);
                    case CameraFacing.back:
                      return const Icon(Icons.camera_rear);
                  }
                },
              ),
              iconSize: 32.0,
              onPressed: () => cameraController.switchCamera(),
            ),
          ],
        ),
        body: SafeArea(
          child: Container(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                Expanded(
                  child: MobileScanner(
                      allowDuplicates: false,
                      controller: cameraController,
                      onDetect: (barcode, args) {
                        if (barcode.rawValue == null) {
                          handleFailure();
                        } else {
                          final String code = barcode.rawValue!;
                          handleSuccess(code);
                        }
                      }),
                ),
                const Divider(),
                Container(
                  alignment: Alignment.bottomRight,
                  child: ElevatedButton(
                      onPressed: () async {
                        context
                            .read<QrScanChangeNotifier>()
                            .update(""); // clear the previous result if nothing found
                        GoRouter.of(context).go(Send.route);
                        GoRouter.of(context).pop();
                      },
                      child: const Text('Close')),
                )
              ],
            ),
          ),
        ));
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  void handleFailure() {
    debugPrint('Failed to scan Barcode');
    FLog.info(text: "Failed to scan QR code");
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text("Failed to scan QR code"),
    ));
  }

  void handleSuccess(String code) {
    debugPrint('Found QR code: $code');
    FLog.info(text: "QR code found: $code");
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text("Found valid QR code"),
    ));
    context.read<QrScanChangeNotifier>().update(code);
    GoRouter.of(context).go(Send.route);
  }
}
