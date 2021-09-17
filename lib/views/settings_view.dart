import 'package:binder/binder.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voice_outliner/repositories/db_repository.dart';

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
                    child: const Text("cancel")),
                TextButton(
                    onPressed: () {
                      ctx.use(dbRepositoryRef).resetDB();
                      Navigator.of(ctx).pop();
                    },
                    child: const Text("reset"))
              ],
            ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text("Settings")),
        body: isInited
            ? Column(
                children: [
                  SwitchListTile(
                      secondary: const Icon(Icons.record_voice_over),
                      title: const Text("Transcribe recordings"),
                      value: sharedPreferences.getBool("should_transcribe") ??
                          false,
                      onChanged: (v) {
                        setState(() {
                          sharedPreferences.setBool("should_transcribe", v);
                        });
                      }),
                  const AboutListTile(
                    icon: Icon(Icons.info),
                    aboutBoxChildren: [Text("made by Max Krieger")],
                  ),
                  ListTile(
                      leading: const Icon(Icons.delete_forever),
                      onTap: _resetDB,
                      title: const Text("Reset database & files")),
                ],
              )
            : const CircularProgressIndicator());
  }
}
