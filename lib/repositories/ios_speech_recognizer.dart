import 'dart:io';

import 'package:flutter/services.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

const iosPlatform = MethodChannel("voiceoutliner.saga.chat/iostx");

Future<String?> recognizeNoteIOS(String path, String locale) async {
  try {
    final platformRes = await iosPlatform
        .invokeMethod("transcribe", {"path": path, "locale": locale});
    if (platformRes is String) {
      return platformRes;
    } else {
      return null;
    }
  } catch (err, tr) {
    print(err);
    Sentry.captureException(err, stackTrace: tr);
    return null;
  }
}

Future<bool> tryTxPermissionIOS() async {
  if (!Platform.isIOS) {
    print("Not IOS");
    return false;
  }
  try {
    final res = await iosPlatform.invokeMethod("requestPermission");
    return res;
  } catch (err) {
    print(err);
    return false;
  }
}

/// Returns a map {"en-US": "English (US)"}
Future<Map<String, String>> getLocaleOptions() async {
  if (!Platform.isIOS) {
    print("Not IOS");
    return {};
  }
  try {
    final res = await iosPlatform.invokeMethod("getLocaleOptions");
    return Map<String, String>.from(res);
  } catch (err, tr) {
    Sentry.captureException(err, stackTrace: tr);
    return {};
  }
}
