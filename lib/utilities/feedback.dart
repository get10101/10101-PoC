import 'dart:io';
import 'dart:typed_data';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:f_logs/model/flog/flog.dart';
import 'package:feedback/feedback.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:path_provider/path_provider.dart';

Future<void> submitFeedback(UserFeedback feedback) async {
  final screenshotFilePath = await writeImageToStorage(feedback.screenshot);
  final logs = await FLog.exportLogs();

  final deviceInfoPlugin = DeviceInfoPlugin();
  String info = "";
  if (Platform.isAndroid) {
    final deviceInfo = await deviceInfoPlugin.androidInfo;
    info = deviceInfo.model.toString() +
        ", Android " +
        deviceInfo.version.sdkInt.toString() +
        ", Release: " +
        deviceInfo.version.release;
  } else {
    final deviceInfo = await deviceInfoPlugin.iosInfo;
    info = deviceInfo.name! + ", " + deviceInfo.systemName! + " " + deviceInfo.systemVersion!;
  }

  final Email email = Email(
    body: feedback.text + '\n\n----------\n' + info,
    subject: '10101 Feedback',
    recipients: ['10101-devs@coblox.tech'],
    attachmentPaths: [screenshotFilePath, logs.path],
    isHTML: false,
  );
  await FlutterEmailSender.send(email);
}

Future<String> writeImageToStorage(Uint8List feedbackScreenshot) async {
  final Directory output = await getTemporaryDirectory();
  final String screenshotFilePath = '${output.path}/feedback.png';
  final File screenshotFile = File(screenshotFilePath);
  await screenshotFile.writeAsBytes(feedbackScreenshot);
  return screenshotFilePath;
}
