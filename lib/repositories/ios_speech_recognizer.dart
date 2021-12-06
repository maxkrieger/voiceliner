import 'dart:io';

import 'package:flutter/services.dart';

const iosPlatform = MethodChannel("voiceoutliner.saga.chat/iostx");

Future<String?> recognizeNoteIOS(String path) async {
  try {
    final platformRes =
        await iosPlatform.invokeMethod("transcribe", {"path": path});
    if (platformRes is String) {
      return platformRes;
    } else {
      print(platformRes);
      return null;
    }
  } catch (err) {
    print(err);
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
