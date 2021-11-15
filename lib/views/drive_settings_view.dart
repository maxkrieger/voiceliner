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
      lastBackedUp = await lastModified();
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
                  "This replaces voice outliner's database currently on your phone. You will lose any notes made after ${lastBackedUp != null ? DateFormat.yMd().add_jm().format(lastBackedUp!.toLocal()) : "never backed up"}"),
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
                      final count = await downloadAll();
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
    setState(() {
      _state = _DriveState.backingUp;
    });
    final count = await uploadAll();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text("Backed up $count notes")));
    checkStatus();
  }

  @override
  Widget build(BuildContext context) {
    final driveEnabled = sharedPreferences?.getBool(driveEnabledKey) ?? false;
    final signedIn = account != null;
    return Scaffold(
        appBar: AppBar(title: const Text("Drive Backup")),
        body: _state == _DriveState.ready
            ? Column(children: [
                SwitchListTile(
                    title: const Text("Back up to Google Drive"),
                    value: driveEnabled,
                    onChanged: handleDriveToggle),
                if (signedIn) ...[
                  ListTile(
                    title: Text("Signed in as ${account?.email}"),
                    subtitle: Text(usage),
                  ),
                  ListTile(
                    leading: const Icon(Icons.backup),
                    title: const Text("Back up"),
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
                  )
                ]
              ])
            : const Center(child: CircularProgressIndicator()));
  }
}
