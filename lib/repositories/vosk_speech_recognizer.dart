import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_archive/flutter_archive.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voice_outliner/consts.dart';

const androidPlatform = MethodChannel("voiceoutliner.saga.chat/androidtx");

// from https://alphacephei.com/vosk/models
const voskModels = {
  "en-us":
      "https://alphacephei.com/vosk/models/vosk-model-small-en-us-0.15.zip",
  "en-in": "https://alphacephei.com/vosk/models/vosk-model-small-en-in-0.4.zip",
  "cn": "https://alphacephei.com/vosk/models/vosk-model-small-cn-0.3.zip",
  "ru": "https://alphacephei.com/vosk/models/vosk-model-small-ru-0.22.zip",
  "fr": "https://alphacephei.com/vosk/models/vosk-model-small-fr-0.22.zip",
  "de": "https://alphacephei.com/vosk/models/vosk-model-small-de-0.15.zip",
  "es": "https://alphacephei.com/vosk/models/vosk-model-small-es-0.3.zip",
  "pt": "https://alphacephei.com/vosk/models/vosk-model-small-pt-0.3.zip",
  "tr": "https://alphacephei.com/vosk/models/vosk-model-small-tr-0.3.zip",
  "vn": "https://alphacephei.com/vosk/models/vosk-model-small-vn-0.3.zip",
  "it": "https://alphacephei.com/vosk/models/vosk-model-small-it-0.4.zip",
  "ca": "https://alphacephei.com/vosk/models/vosk-model-small-ca-0.4.zip",
  "fa": "https://alphacephei.com/vosk/models/vosk-model-small-fa-0.4.zip",
  "uk": "https://alphacephei.com/vosk/models/vosk-model-small-uk-v3-nano.zip",
  "kz": "https://alphacephei.com/vosk/models/vosk-model-small-kz-0.15.zip",
  "ja": "https://alphacephei.com/vosk/models/vosk-model-small-ja-0.22.zip",
  "eo": "https://alphacephei.com/vosk/models/vosk-model-small-eo-0.22.zip"
};

Future<String?> voskSpeechRecognize(String path) async {
  if (!Platform.isAndroid) {
    print("wrong platform");
    return null;
  }
  try {
    final tempDir = await getTemporaryDirectory();
    final outPath = "${tempDir.path}/converted.wav";
    await flutterSoundHelper.convertFile(
        path, Codec.aacADTS, outPath, Codec.pcm16);
    final outFile = File(outPath);
    final exists = await outFile.exists();
    if (!exists) {
      print("Could not convert");
      return null;
    }
    final result =
        await androidPlatform.invokeMethod("transcribe", {"path": outPath});
    return result;
  } catch (err) {
    print(err);
    return null;
  }
}

/// Returns null if success
Future<String?> voskInitModel(String path) async {
  if (!Platform.isAndroid) {
    return "Not Android";
  }
  try {
    // TODO: is this fallible to the sandbox path changing?
    final res = await androidPlatform.invokeMethod("initModel", {"path": path});
    if (res != null) {
      return res.toString();
    }
    return null;
  } catch (e) {
    return e.toString();
  }
}

/// returns null if success, error message if not
Future<String?> voskDownloadAndInitModel(String url) async {
  if (!Platform.isAndroid) {
    return "Not Android";
  }
  try {
    final cacheDirs = await getExternalCacheDirectories();
    if (cacheDirs == null || cacheDirs.isEmpty) {
      return "Couldn't get cache";
    }
    final uri = Uri.parse(url);
    final cacheDir = cacheDirs.first;
    final modelsDir = await Directory("${cacheDir.path}/vosk_models").create();
    final tmpDir = await getTemporaryDirectory();
    print("Downloading from $url");
    final req = await HttpClient().getUrl(uri);
    final res = await req.close();
    print("Download complete");
    final zipFile = File("${tmpDir.path}/downloaded.zip");
    await res.pipe(zipFile.openWrite());
    print("Write complete, unzipping");
    await ZipFile.extractToDirectory(
        zipFile: zipFile, destinationDir: modelsDir);
    final folderName = uri.pathSegments.last.replaceAll(".zip", "");
    final modelDir = Directory("${modelsDir.path}/$folderName");
    final initResult = await androidPlatform
        .invokeMethod("initModel", {"path": modelDir.path});
    if (initResult != null) {
      return initResult.toString();
    }
    final sharedPreferences = await SharedPreferences.getInstance();
    await sharedPreferences.setString(modelDirKey, modelDir.path);
    return null;
  } catch (err) {
    return err.toString();
  }
}
