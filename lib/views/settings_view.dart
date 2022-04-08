import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:voice_outliner/consts.dart';
import 'package:voice_outliner/repositories/ios_speech_recognizer.dart';
import 'package:voice_outliner/state/outline_state.dart';
import 'package:voice_outliner/views/drive_settings_view.dart';
import 'package:voice_outliner/views/ios_transcription_setup_view.dart';
import 'package:voice_outliner/views/vosk_transcription_setup_view.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({Key? key}) : super(key: key);

  @override
  _SettingsViewState createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  late SharedPreferences sharedPreferences;
  bool isInited = false;
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

  void _resetDB() {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text("Reset everything?"),
              content: const Text(
                  "This deletes the database and files. Relaunch the app afterward."),
              actions: [
                TextButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                    },
                    child: Text(
                      "cancel",
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface),
                    )),
                TextButton(
                    onPressed: () async {
                      /*await ctx.read<DBRepository>().resetDB();
                      await ctx
                          .read<PlayerModel>()
                          .recordingsDirectory
                          .delete(recursive: true);*/
                      Navigator.of(ctx).pop();
                    },
                    child: Text(
                      "reset",
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface),
                    ))
              ],
            ));
  }

  Future<void> toggleLocation(bool enable) async {
    if (enable) {
      bool permissioned = await locationInstance.serviceEnabled();
      if (!permissioned) {
        permissioned = await locationInstance.requestService();
        if (!permissioned) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Couldn't get location")));
          return;
        }
      }
      try {
        final testLoc = await locationInstance.getLocation();
        if (testLoc.latitude == null) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Couldn't get location")));
          return;
        }
      } catch (err) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Couldn't get location permission")));
        return;
      }
    }
    setState(() {
      sharedPreferences.setBool(shouldLocateKey, enable);
    });
  }

  void showOnboarding() {
    Navigator.pushNamedAndRemoveUntil(context, "/onboarding", (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final showArchived =
        context.select<OutlinesModel, bool>((value) => value.showArchived);
    return Scaffold(
        appBar: AppBar(
          title: const Text("Settings"),
        ),
        body: isInited
            ? Column(
                children: [
                  const SizedBox(height: 10.0),
                  if (Platform.isIOS) ...[
                    SwitchListTile(
                        secondary: const Icon(Icons.voicemail),
                        title: const Text("Transcribe Recordings"),
                        subtitle: const Text("uses local transcription"),
                        value: sharedPreferences.getBool(shouldTranscribeKey) ??
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
                            sharedPreferences.setBool(shouldTranscribeKey, v);
                          });
                        }),
                    if (sharedPreferences.getBool(shouldTranscribeKey) ?? true)
                      ListTile(
                        leading: const Icon(Icons.language),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        title: const Text("Transcription Language"),
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const IOSTranscriptionSetupView())),
                      ),
                  ],
                  if (Platform.isAndroid)
                    ListTile(
                      leading: const Icon(Icons.voicemail),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      title: const Text("Transcription Setup"),
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const VoskTranscriptionSetupView())),
                    ),
                  SwitchListTile(
                    secondary: const Icon(Icons.location_pin),
                    title: const Text("Attach Location"),
                    subtitle: const Text("remember where you took a note"),
                    value: sharedPreferences.getBool(shouldLocateKey) ?? false,
                    onChanged: toggleLocation,
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.archive),
                    title: const Text("Show Archived Outlines"),
                    value: showArchived,
                    onChanged: (_) =>
                        context.read<OutlinesModel>().toggleShowArchived(),
                  ),
                  ListTile(
                    leading: const Icon(Icons.backup),
                    title: const Text("Backup"),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const DriveSettingsView())),
                  ),
                  ListTile(
                    leading: const Icon(Icons.favorite),
                    title: const Text("Send Tip"),
                    onTap: () =>
                        launch("https://github.com/sponsors/maxkrieger"),
                  ),
                  ListTile(
                    leading: const Icon(Icons.bug_report),
                    title: const Text("Report Issue"),
                    onTap: () => launch(
                        "https://github.com/maxkrieger/voiceliner/issues"),
                  ),
                  ListTile(
                    leading: const Icon(Icons.privacy_tip),
                    title: const Text("Privacy"),
                    onTap: () => launch(
                        "https://gist.github.com/maxkrieger/301352ae9b7a9e51f49d843fb851d823"),
                  ),
                  AboutListTile(
                    icon: const Icon(Icons.info),
                    aboutBoxChildren: [
                      const Text(
                        "made by Max Krieger",
                        textAlign: TextAlign.center,
                      ),
                      TextButton(
                          onPressed: () => launch(
                              "https://github.com/maxkrieger/voiceliner"),
                          child: Text(
                            "fork on GitHub",
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface),
                          ))
                    ],
                  ),
                  ListTile(
                      leading: const Icon(Icons.help),
                      title: const Text("Show Tutorial"),
                      onTap: showOnboarding),
                ],
              )
            : const CircularProgressIndicator());
  }
}
