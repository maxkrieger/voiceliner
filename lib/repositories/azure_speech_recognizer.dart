import 'dart:convert';
import 'dart:io';

import 'package:flutter_sound/flutter_sound.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart' as sentry;
import 'package:tuple/tuple.dart';
import 'package:voice_outliner/data/note.dart';

const _apiKey = String.fromEnvironment("AZURE_SPEECH_KEY");
Future<Tuple2<bool, String?>> azureRecognize(Note note, String path) async {
  if (_apiKey.isEmpty) {
    await sentry.Sentry.captureMessage("API key empty!",
        level: sentry.SentryLevel.error);
    print("API key empty");
    return const Tuple2(false, null);
  }
  if (note.duration != null &&
      note.duration!.compareTo(const Duration(minutes: 10)) > 0) {
    return const Tuple2(true, null);
  }
  // Prevents Azure from thinking we're ddosing_I think
  await Future.delayed(const Duration(milliseconds: 200));
  try {
    final tempDir = await getTemporaryDirectory();
    final outPath = "${tempDir.path}/${note.id}.wav";
    await flutterSoundHelper.convertFile(
        path, Codec.aacADTS, outPath, Codec.pcm16);
    final outFile = File(outPath);
    final exists = await outFile.exists();
    if (!exists) {
      await sentry.Sentry.captureMessage(
          "Could not convert for speech recognition",
          level: sentry.SentryLevel.error);
      print("Could not convert");
      return const Tuple2(false, null);
    }
    final outFileBytes = await outFile.readAsBytes();
    final res = await http.post(
        Uri.parse(
            'https://eastus.stt.speech.microsoft.com/speech/recognition/conversation/cognitiveservices/v1?language=en-US'),
        headers: <String, String>{
          "Content-Type": "audio/wav; codecs=audio/pcm; samplerate=16000",
          "Ocp-Apim-Subscription-Key": _apiKey
        },
        body: outFileBytes);
    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);
      final recognitionStatus = decoded["RecognitionStatus"];
      if (recognitionStatus == "Success") {
        final displayText = decoded["DisplayText"];
        return Tuple2(true, displayText);
      } else {
        print("Didn't succeed in transcribing");
        return const Tuple2(true, null);
      }
    }
    await sentry.Sentry.captureMessage(
        "Couldn't contact Azure: status code ${res.statusCode}",
        level: sentry.SentryLevel.error);
    print("Couldn't contact Azure: status code ${res.statusCode}");
    return const Tuple2(false, null);
  } catch (err, st) {
    print("$err $st");
    await sentry.Sentry.captureException(err, stackTrace: st);
    return const Tuple2(false, null);
  }
}
