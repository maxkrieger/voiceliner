import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:voice_outliner/consts.dart';
import 'package:voice_outliner/state/outline_state.dart';
import 'package:voice_outliner/views/vosk_transcription_setup_view.dart';

import '../repositories/ios_speech_recognizer.dart';
import 'drive_settings_view.dart';
import 'ios_transcription_setup_view.dart';

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
    final showCompleted =
        context.select<OutlinesModel, bool>((value) => value.showCompleted);
    final allowRetranscription = context
        .select<OutlinesModel, bool>((value) => value.allowRetranscription);
    final shouldTranscribe = (isInited
        ? (sharedPreferences.getBool(shouldTranscribeKey) ?? true)
        : false);
    return Scaffold(
        appBar: AppBar(
          title: const Text("Settings"),
        ),
        body: !isInited
            ? const CircularProgressIndicator()
            : SettingsList(
                sections: [
                  SettingsSection(title: const Text("Transcription"), tiles: [
                    SettingsTile.switchTile(
                      leading: const Icon(Icons.voicemail),
                      initialValue: shouldTranscribe,
                      onToggle: (v) async {
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
                      },
                      title: const Text("Transcribe Recordings"),
                    ),
                    if (Platform.isIOS)
                      SettingsTile.navigation(
                        enabled: shouldTranscribe,
                        onPressed: (c) => Navigator.push(
                            c,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const IOSTranscriptionSetupView())),
                        leading: const Icon(Icons.language),
                        title: const Text("Transcription Language"),
                        description: const Text("uses iOS transcription"),
                      ),
                    if (Platform.isAndroid)
                      SettingsTile.navigation(
                        enabled: shouldTranscribe,
                        leading: const Icon(Icons.language),
                        title: const Text("Transcription Setup"),
                        description: const Text("uses Vosk transcription"),
                        onPressed: (c) => Navigator.push(
                            c,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const VoskTranscriptionSetupView())),
                      ),
                  ]),
                  SettingsSection(title: const Text("Backup"), tiles: [
                    SettingsTile.navigation(
                      title: const Text("Backup Settings"),
                      leading: const Icon(Icons.backup),
                      onPressed: (c) => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const DriveSettingsView())),
                    )
                  ]),
                  SettingsSection(title: const Text("Location"), tiles: [
                    SettingsTile.switchTile(
                      leading: const Icon(Icons.location_pin),
                      title: const Text("Attach Location"),
                      description: const Text("remember where you took a note"),
                      initialValue:
                          sharedPreferences.getBool(shouldLocateKey) ?? false,
                      onToggle: toggleLocation,
                    ),
                  ]),
                  SettingsSection(title: const Text("Display"), tiles: [
                    SettingsTile.switchTile(
                        initialValue: showCompleted,
                        leading: const Icon(Icons.check_circle),
                        onToggle: (v) =>
                            context.read<OutlinesModel>().setShowCompleted(v),
                        title: const Text("Show Completed Notes")),
                    SettingsTile.switchTile(
                        initialValue: showArchived,
                        leading: const Icon(Icons.archive),
                        onToggle: (v) =>
                            context.read<OutlinesModel>().toggleShowArchived(),
                        title: const Text("Show Archived Outlines")),
                    SettingsTile.switchTile(
                        initialValue:
                            shouldTranscribe ? allowRetranscription : false,
                        onToggle: (v) {
                          context
                              .read<OutlinesModel>()
                              .setAllowRetranscription(v);
                        },
                        enabled: shouldTranscribe,
                        leading: const Icon(Icons.replay),
                        title: const Text("Re-transcription Option"))
                  ]),
                  SettingsSection(title: const Text("About"), tiles: [
                    SettingsTile.navigation(
                      leading: const Icon(Icons.favorite),
                      title: const Text("Send Tip"),
                      onPressed: (c) => launchUrl(
                          Uri.parse("https://github.com/sponsors/maxkrieger")),
                    ),
                    SettingsTile.navigation(
                      leading: const Icon(Icons.privacy_tip),
                      title: const Text("Privacy"),
                      onPressed: (_) => launchUrl(Uri.parse(
                          "https://gist.github.com/maxkrieger/301352ae9b7a9e51f49d843fb851d823")),
                    ),
                    SettingsTile.navigation(
                      leading: const Icon(Icons.bug_report),
                      title: const Text("Report Issue"),
                      onPressed: (_) => launchUrl(Uri.parse(
                          "https://github.com/maxkrieger/voiceliner/issues")),
                    ),
                    SettingsTile.navigation(
                      leading: const Icon(Icons.code),
                      title: const Text("View Source Code"),
                      onPressed: (_) => launchUrl(Uri.parse(
                          "https://github.com/maxkrieger/voiceliner")),
                    ),
                    SettingsTile.navigation(
                        leading: const Icon(Icons.help),
                        title: const Text("Show Tutorial"),
                        onPressed: (_) => showOnboarding())
                  ])
                ],
              ));
  }
}
