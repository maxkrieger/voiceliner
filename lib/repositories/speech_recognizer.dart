import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:google_speech/google_speech.dart';
import 'package:path_provider/path_provider.dart';
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

  Future<String?> recognize(Note note) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final outPath = "${tempDir.path}/${note.id}.wav";
      await flutterSoundHelper.convertFile(
          note.filePath, Codec.aacADTS, outPath, Codec.pcm16);
      final outFile = File(outPath);
      final outFileBytes = await outFile.readAsBytes();
      final res = await _speechToText.recognize(_config, outFileBytes);
      await outFile.delete();
      if (res.results.isEmpty || res.results.first.alternatives.isEmpty) {
        return null;
      }
      final fst = res.results.first.alternatives.first.transcript;
      return fst;
    } catch (err) {
      print(err);
      return null;
    }
  }
}
