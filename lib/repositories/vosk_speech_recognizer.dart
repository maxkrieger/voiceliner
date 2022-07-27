import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_archive/flutter_archive.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voice_outliner/consts.dart';

const androidPlatform = MethodChannel("voiceoutliner.saga.chat/androidtx");

const voskModelsURL = "https://alphacephei.com/vosk/models/model-list.json";

class VoskModel {
  String url;
  String sizeText;
  String languageText;
  String languageCode;
  VoskModel(this.url, this.sizeText, this.languageText, this.languageCode);
}

Future<List<VoskModel>> retrieveVoskModels() async {
  try {
    final res = await http.get(Uri.parse(voskModelsURL));
    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);
      if (decoded is List) {
        final parsed = decoded
            .where((element) =>
                element["type"] == "small" && element["obsolete"] == "false")
            .map((element) => VoskModel(element["url"], element["size_text"],
                element["lang_text"], element["lang"]))
            .toList(growable: false);
        parsed.sort((a, b) => a.languageCode.compareTo(b.languageCode));
        return parsed;
      }
    }
    print("Status code is ${res.statusCode}");
    return [];
  } catch (err, tr) {
    print(err);
    Sentry.captureException(err, stackTrace: tr);
    return [];
  }
}

Future<String?> voskSpeechRecognize(String path) async {
  if (!Platform.isAndroid) {
    print("Not Android");
    return null;
  }
  try {
    final result =
        await androidPlatform.invokeMethod("transcribe", {"path": path});
    return result;
  } catch (err, tr) {
    Sentry.captureException(err, stackTrace: tr);
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
  } catch (err, tr) {
    Sentry.captureException(err, stackTrace: tr);
    return err.toString();
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
    final req = await HttpClient().getUrl(uri);
    final res = await req.close();
    final zipFile = File("${tmpDir.path}/downloaded.zip");
    await res.pipe(zipFile.openWrite());
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
  } catch (err, tr) {
    Sentry.captureException(err, stackTrace: tr);
    return err.toString();
  }
}
