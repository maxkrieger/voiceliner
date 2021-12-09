import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timeago_flutter/timeago_flutter.dart';
import 'package:voice_outliner/repositories/db_repository.dart';
import 'package:voice_outliner/repositories/drive_backup.dart';
import 'package:voice_outliner/state/outline_state.dart';

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
  DateTime? lastBackedUp;
  _DriveState _state = _DriveState.initing;
  int progress = 0;
  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    sharedPreferences = await SharedPreferences.getInstance();
    setState(() {
      _state = _DriveState.inited;
      progress = 0;
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
      lastBackedUp = await lastModified();
      if (lastBackedUp == null) {
        await backupAll();
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

  Future<void> restore() async {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text("Restore from Drive?"),
              content: Text(
                  "This replaces voice outliner's database currently on your phone. You will lose any notes made after ${lastBackedUp != null ? DateFormat.yMd().add_jm().format(lastBackedUp!.toLocal()) : "never backed up. press cancel"}"),
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
                      final count = await downloadAll((int p) {
                        setState(() {
                          progress = p;
                        });
                      });
                      await context.read<DBRepository>().load();
                      await context.read<OutlinesModel>().loadOutlines();
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Restored $count notes")));
                      checkStatus();
                    },
                    child: const Text("restore"))
              ],
            ));
  }

  Future<void> backupAll() async {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text("Back up everything now?"),
              content: Text(lastBackedUp == null
                  ? "Please wait for it to finish."
                  : "You already have a backup from ${DateFormat.yMd().add_jm().format(lastBackedUp!.toLocal())}. If you proceed, it will be overwritten."),
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
                      await uploadAll((int p) {
                        setState(() {
                          progress = p;
                        });
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Backed up notes")));
                      checkStatus();
                    },
                    child: const Text("back up"))
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
                        "Restoring note # $progress, please wait until complete",
                    _DriveState.backingUp:
                        "Backing up $progress notes, please wait until complete",
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
                  subtitle: const Text(
                      "note that new notes are backed up automatically"),
                  onTap: backupAll,
                ),
                ListTile(
                  leading: const Icon(Icons.settings_backup_restore),
                  title: const Text("Restore"),
                  subtitle: lastBackedUp != null
                      ? Timeago(
                          date: lastBackedUp!,
                          builder: (_, t) => Text("last backed up $t"),
                        )
                      : const Text("never backed up"),
                  onTap: restore,
                ),
              ]
            ])
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
