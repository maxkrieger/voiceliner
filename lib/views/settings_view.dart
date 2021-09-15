import 'package:binder/binder.dart';
import 'package:flutter/material.dart';
import 'package:voice_outliner/repositories/db_repository.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({Key? key}) : super(key: key);

  @override
  _SettingsViewState createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  void _resetDB() {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: Text("Reset everything?"),
              content: Text(
                  "This deletes the database and files. Relaunch the app afterward."),
              actions: [
                TextButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                    },
                    child: Text("cancel")),
                TextButton(
                    onPressed: () {
                      ctx.use(dbRepositoryRef).resetDB();
                      Navigator.of(ctx).pop();
                    },
                    child: Text("reset"))
              ],
            ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text("Settings")),
        body: Column(
          children: [
            ElevatedButton(onPressed: _resetDB, child: Text("reset everything"))
          ],
        ));
  }
}
