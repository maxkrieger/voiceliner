import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timeago_flutter/timeago_flutter.dart';
import 'package:tuple/tuple.dart';
import 'package:voice_outliner/repositories/db_repository.dart';
import 'package:voice_outliner/repositories/drive_backup.dart';
import 'package:voice_outliner/state/outline_state.dart';

import '../consts.dart';

class DriveSettingsView extends StatefulWidget {
  const DriveSettingsView({Key? key}) : super(key: key);

  @override
  _DriveSettingsViewState createState() => _DriveSettingsViewState();
}

enum _DriveState { initing, inited, ready, backingUp, restoring }

class _DriveSettingsViewState extends State<DriveSettingsView> {
  SharedPreferences? sharedPreferences;
  StreamSubscription? googleAuthSub;
  GoogleSignInAccount? account;
  String usage = "";
  List<Tuple2<DateTime, String>> backups = [];

  _DriveState _state = _DriveState.initing;
  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    sharedPreferences = await SharedPreferences.getInstance();
    setState(() {
      _state = _DriveState.inited;
      account = googleSignIn.currentUser;
      googleAuthSub = googleSignIn.onCurrentUserChanged.listen((event) {
        setState(() {
          account = event;
          checkStatus();
        });
      });
    });
    checkStatus();
  }

  @override
  void dispose() {
    googleAuthSub?.cancel();
    super.dispose();
  }

  Future<void> checkStatus() async {
    if (account != null) {
      usage = await getUsage();
      backups = await getBackups();
      if (backups.isEmpty) {
        await createBackup();
      }
    } else {
      if (sharedPreferences?.getBool(driveEnabledKey) ?? false) {
        account = await googleSignIn.signIn();
      }
    }
    _state = _DriveState.ready;
    setState(() {});
  }

  Future<void> handleDriveToggle(bool enable) async {
    sharedPreferences?.setBool(driveEnabledKey, enable);
    if (enable) {
      await googleSignIn.signIn();
    } else {
      await googleSignIn.signOut();
      account = null;
    }
    await checkStatus();
    setState(() {});
  }

  Future<void> restore(int idx) async {
    final backup = backups[idx];
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text("Restore from Drive?"),
              content: Text(
                  "This replaces voice outliner's database currently on your phone. You will lose any notes made after ${DateFormat.yMd().add_jm().format(backup.item1.toLocal())}"),
              actions: [
                TextButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                    },
                    child: const Text("cancel")),
                TextButton(
                    onPressed: () async {
                      Navigator.of(ctx).pop();
                      setState(() {
                        _state = _DriveState.restoring;
                      });
                      await context.read<DBRepository>().closeDB();
                      await restoreById(backup.item2, () async {
                        await context.read<DBRepository>().load();
                        await context.read<OutlinesModel>().loadOutlines();
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(
                                "Restored notes from ${DateFormat.yMd().add_jm().format(backup.item1.toLocal())}")));
                        checkStatus();
                      });
                    },
                    child: const Text("restore"))
              ],
            ));
  }

  Future<void> createBackup() async {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text("Back up everything now?"),
              content: const Text("Please wait for it to finish."),
              actions: [
                TextButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                    },
                    child: const Text("cancel")),
                TextButton(
                    onPressed: () async {
                      Navigator.of(ctx).pop();
                      setState(() {
                        _state = _DriveState.backingUp;
                      });
                      await makeBackup();
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Backed up notes")));
                      checkStatus();
                    },
                    child: const Text("back up"))
              ],
            ));
  }

  Future<void> deleteIdx(int idx) async {
    final backup = backups[idx];
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text("Delete this backup?"),
              content: Text(
                  "It was made on ${DateFormat.yMd().add_jm().format(backup.item1.toLocal())}"),
              actions: [
                TextButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                    },
                    child: const Text("cancel")),
                TextButton(
                    onPressed: () async {
                      Navigator.of(ctx).pop();
                      await deleteById(backup.item2);
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Deleted backup")));
                      checkStatus();
                    },
                    child: const Text("delete"))
              ],
            ));
  }

  @override
  Widget build(BuildContext context) {
    final driveEnabled = sharedPreferences?.getBool(driveEnabledKey) ?? false;
    final signedIn = account != null;
    return Scaffold(
      appBar: AppBar(title: const Text("Drive Backup")),
      body: _state != _DriveState.initing
          ? Column(children: [
              SwitchListTile(
                  title: const Text("Back up to Google Drive"),
                  value: driveEnabled,
                  onChanged: handleDriveToggle),
              if (_state != _DriveState.ready)
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 10.0),
                  Text({
                    _DriveState.restoring:
                        "Restoring notes, please wait until complete",
                    _DriveState.backingUp:
                        "Backing up notes, please wait until complete",
                    _DriveState.inited: "Contacting Drive"
                  }[_state]!)
                ]),
              if (signedIn && _state == _DriveState.ready) ...[
                ListTile(
                  title: Text("Signed in as ${account?.email}"),
                  subtitle: Text(usage),
                ),
                ListTile(
                  leading: const Icon(Icons.backup),
                  title: const Text("Full backup"),
                  subtitle: const Text("backups occur daily when app is open"),
                  onTap: createBackup,
                ),
                ListView.builder(
                  reverse: true,
                  itemBuilder: (ctx, idx) {
                    final backup = backups[idx];
                    return Card(
                        key: Key("idx-$idx"),
                        child: ListTile(
                          leading: const Icon(Icons.restore),
                          onLongPress: () => deleteIdx(idx),
                          title: Text(DateFormat.yMd()
                              .add_jm()
                              .format(backup.item1.toLocal())),
                          subtitle: Timeago(
                            date: backup.item1,
                            builder: (_, s) => Text(s),
                          ),
                          onTap: () => restore(idx),
                        ));
                  },
                  shrinkWrap: true,
                  itemCount: backups.length,
                ),
              ]
            ])
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
