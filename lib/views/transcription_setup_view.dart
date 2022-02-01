import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voice_outliner/consts.dart';
import 'package:voice_outliner/repositories/ios_speech_recognizer.dart';
import 'package:voice_outliner/repositories/vosk_speech_recognizer.dart';

class TranscriptionSetupView extends StatefulWidget {
  const TranscriptionSetupView({Key? key}) : super(key: key);

  @override
  _TranscriptionSetupViewState createState() => _TranscriptionSetupViewState();
}

class _TranscriptionSetupViewState extends State<TranscriptionSetupView> {
  SharedPreferences? sharedPreferences;
  bool isInited = false;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    sharedPreferences = await SharedPreferences.getInstance();

    setState(() {
      isInited = true;
    });
  }

  Future<void> _onLanguageSelected(String? language) async {
    if (language != null) {
      await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
                title: Text("Download $language?"),
                content: const Text(
                    "The download will be around 50mb, please wait for it to complete."),
                actions: [
                  TextButton(
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                      },
                      child: Text(
                        "cancel",
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface),
                      )),
                  TextButton(
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        setState(() {
                          loading = true;
                        });
                        final downloadResult = await voskDownloadAndInitModel(
                            voskModels[language]!);
                        if (downloadResult != null) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content:
                                  Text("Couldn't download: $downloadResult")));
                        } else {
                          await sharedPreferences?.setString(
                              modelLanguageKey, language);
                        }
                        setState(() {
                          loading = false;
                        });
                      },
                      child: Text(
                        "download",
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface),
                      ))
                ],
              ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = voskModels.keys
        .map((String lang) => DropdownMenuItem(child: Text(lang), value: lang))
        .toList(growable: false);
    final modelLanguage = sharedPreferences?.getString(modelLanguageKey);
    final transcriptionEnabled =
        sharedPreferences?.getBool(shouldTranscribeKey);
    final canProceed = modelLanguage != null || !(transcriptionEnabled ?? true);
    return Scaffold(
      appBar: AppBar(
        title: const Text("Transcription"),
        automaticallyImplyLeading: false,
      ),
      body: isInited
          ? Padding(
              padding: const EdgeInsets.all(20.0),
              child: Center(
                  child: Column(
                children: loading
                    ? const [
                        Text("downloading model..."),
                        SizedBox(height: 20),
                        CircularProgressIndicator()
                      ]
                    : [
                        Text(
                            "Your device transcribes your voice locally. ${(Platform.isAndroid) ? "Select a language to download the model (around 50mb)" : ""}",
                            style: const TextStyle(fontSize: 16)),
                        SwitchListTile(
                            secondary: const Icon(Icons.voicemail),
                            title: const Text("Transcribe Recordings"),
                            value: sharedPreferences
                                    ?.getBool(shouldTranscribeKey) ??
                                true,
                            onChanged: (v) async {
                              if (Platform.isIOS && v) {
                                final res = await tryTxPermissionIOS();
                                if (!res) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              "Couldn't get permission to transcribe")));
                                  return;
                                }
                              }
                              setState(() {
                                sharedPreferences?.setBool(
                                    shouldTranscribeKey, v);
                              });
                            }),
                        const SizedBox(height: 20),
                        if (transcriptionEnabled ?? true)
                          DropdownButton<String>(
                            icon: const Icon(Icons.language),
                            menuMaxHeight: 300,
                            hint: const Text("Select a language..."),
                            isExpanded: true,
                            items: items,
                            onChanged: _onLanguageSelected,
                            value: modelLanguage,
                          ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                            onPressed: canProceed
                                ? () => Navigator.pushNamedAndRemoveUntil(
                                    context, "/", (route) => false)
                                : null,
                            child: Text(canProceed
                                ? "continue"
                                : "select a language to continue"))
                      ],
              )))
          : const CircularProgressIndicator(),
    );
  }
}
