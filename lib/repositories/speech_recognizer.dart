import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:google_speech/google_speech.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart' as sentry;
import 'package:tuple/tuple.dart';
import 'package:voice_outliner/data/note.dart';

class SpeechRecognizer {
  SpeechRecognizer();
  late SpeechToText _speechToText;
  final _config = RecognitionConfig(
      encoding: AudioEncoding.LINEAR16,
      languageCode: "en-US",
      sampleRateHertz: 44100,
      model: RecognitionModel.basic);
  Future<void> init() async {
    final serviceAccount = ServiceAccount.fromString(
        await rootBundle.loadString('assets/speech_acct.json'));

    _speechToText = SpeechToText.viaServiceAccount(serviceAccount);
  }

  Future<Tuple2<bool, String?>> recognize(Note note, String path) async {
    if (note.duration != null &&
        note.duration!.compareTo(const Duration(minutes: 10)) > 0) {
      return const Tuple2(true, null);
    }
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
        return const Tuple2(false, null);
      }
      final outFileBytes = await outFile.readAsBytes();
      final res = await _speechToText.recognize(_config, outFileBytes);
      if (res.results.isEmpty || res.results.first.alternatives.isEmpty) {
        return const Tuple2(true, null);
      }
      final fst = res.results.first.alternatives.first.transcript;
      return Tuple2(true, fst);
    } catch (err, st) {
      await sentry.Sentry.captureException(err, stackTrace: st);
      return const Tuple2(false, null);
    }
  }
}
