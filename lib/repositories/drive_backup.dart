import 'dart:io' as IO;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:filesize/filesize.dart';
import 'package:flutter_archive/flutter_archive.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tuple/tuple.dart';

import '../consts.dart';

GoogleSignIn googleSignIn = GoogleSignIn(scopes: [DriveApi.driveAppdataScope]);

Future<DriveApi?> getDrive() async {
  try {
    if (googleSignIn.currentUser == null) {
      await googleSignIn.signInSilently(reAuthenticate: true);
    }

    final httpClient = (await googleSignIn.authenticatedClient());
    if (httpClient == null) {
      return null;
    }
    return DriveApi(httpClient);
  } catch (e, tr) {
    print(e);
    print(tr);
    Sentry.captureException(e, stackTrace: tr);
    return null;
  }
}

bool backingUp = false;

/// Back up if you can
Future<void> ifShouldBackup() async {
  final sp = await SharedPreferences.getInstance();
  final lastBackup = sp.getInt(lastBackupKey);
  final shouldBackup = sp.getBool(driveEnabledKey) ?? false;
  if (shouldBackup) {
    ConnectivityResult connectivityResult =
        await (Connectivity().checkConnectivity());

    /// If connected to wifi
    if (connectivityResult != ConnectivityResult.none &&
        connectivityResult != ConnectivityResult.mobile &&
        !backingUp) {
      // hacky lock on double backups
      backingUp = true;

      /// If last backup is old enough
      if ((lastBackup == null ||
          DateTime.now()
                  .subtract(const Duration(days: 1))
                  .compareTo(DateTime.fromMillisecondsSinceEpoch(lastBackup)) >
              0)) {
        Sentry.addBreadcrumb(Breadcrumb(
            message: "Initiating auto back up", timestamp: DateTime.now()));
        await makeBackup();
      }

      /// If should auto remove old backups
      if (sp.getBool(autoDeleteOldBackupsKey) ?? false) {
        await removeOldBackups();
      }
      backingUp = false;
    }
  }
}

Future<String> getUsage() async {
  final driveApi = await getDrive();
  if (driveApi == null) {
    return "could not authenticate";
  }
  final about = await driveApi.about.get($fields: "storageQuota");
  final storageQuota = about.storageQuota;
  if (storageQuota == null ||
      storageQuota.usage == null ||
      storageQuota.limit == null) {
    return "could not get usage";
  }
  final remaining = ((int.tryParse(storageQuota.limit!) ?? 0) -
      (int.tryParse(storageQuota.usage!) ?? 0));
  return "your account has ${filesize(remaining)} left";
}

///
/// Requires check of sharedPreference autoDeleteOldBackupsKey
///
Future<void> removeOldBackups() async {
  final driveApi = await getDrive();
  if (driveApi == null) {
    return;
  }
  final existing = await driveApi.files.list(
      spaces: "appDataFolder",
      pageSize: 1000,
      q: "name = 'voice_outliner.zip'",
      $fields: "files(modifiedTime, id)",
      orderBy: "modifiedTime desc");
  if (existing.files != null && existing.files!.isNotEmpty) {
    for (var file in existing.files!) {
      if (DateTime.now()
              .difference(file.modifiedTime!)
              .compareTo(const Duration(days: 31)) >
          0) {
        print("Deleting old file ${file.modifiedTime!}");
        Sentry.addBreadcrumb(Breadcrumb(
            message: "Deleting old file ${file.modifiedTime!}",
            timestamp: DateTime.now()));
        await driveApi.files.delete(file.id!);
      }
    }
  } else {
    return;
  }
}

Future<List<Tuple2<DateTime, String>>> getBackups() async {
  final driveApi = await getDrive();
  if (driveApi == null) {
    return [];
  }
  final existing = await driveApi.files.list(
      spaces: "appDataFolder",
      pageSize: 1000,
      q: "name = 'voice_outliner.zip'",
      $fields: "files(modifiedTime, id)",
      orderBy: "modifiedTime");
  if (existing.files != null && existing.files!.isNotEmpty) {
    return existing.files!.map((e) => Tuple2(e.modifiedTime!, e.id!)).toList();
  } else {
    return [];
  }
}

Future<void> makeBackup() async {
  final driveApi = await getDrive();
  if (driveApi == null) {
    return;
  }
  final docsDir = await getApplicationDocumentsDirectory();
  final tmpDir = await getTemporaryDirectory();
  final tmpZip = IO.File(
      "${tmpDir.path}/voice_outliner-${DateTime.now().millisecondsSinceEpoch}.zip");
  try {
    await ZipFile.createFromDirectory(
      sourceDir: docsDir,
      zipFile: tmpZip,
      recurseSubDirs: true,
    );
    final driveFile = File();
    driveFile.modifiedTime = DateTime.now();
    final read = tmpZip.openRead();
    final length = await tmpZip.length();
    final media = Media(read, length);
    driveFile.parents = ["appDataFolder"];
    driveFile.name = "voice_outliner.zip";
    await driveApi.files.create(driveFile, uploadMedia: media);
    final sp = await SharedPreferences.getInstance();
    sp.setInt(lastBackupKey, DateTime.now().millisecondsSinceEpoch);
    Sentry.addBreadcrumb(
        Breadcrumb(message: "Done backing up", timestamp: DateTime.now()));
  } catch (e, tr) {
    print(e);
    Sentry.captureException(e, stackTrace: tr);
  }
}

Future<void> restoreById(String id, Function onDone) async {
  final driveApi = await getDrive();
  if (driveApi == null) {
    return;
  }
  final docsDir = await getApplicationDocumentsDirectory();
  await docsDir.list().forEach((element) async {
    await element.delete(recursive: true);
  });
  final tmpDir = await getTemporaryDirectory();
  try {
    final contents = (await driveApi.files
        .get(id, downloadOptions: DownloadOptions.fullMedia)) as Media;
    final diskFile =
        await IO.File("${tmpDir.path}/voice_outliner.zip").create();
    final fileSink = diskFile.openWrite();
    contents.stream.listen((chunk) {
      fileSink.add(chunk);
    }, onDone: () async {
      await fileSink.close();
      await ZipFile.extractToDirectory(
          zipFile: diskFile, destinationDir: docsDir);
      Sentry.addBreadcrumb(
          Breadcrumb(message: "Restored backup", timestamp: DateTime.now()));
      onDone();
    });
  } catch (e, tr) {
    print(e);
    print(tr);
    Sentry.captureException(e, stackTrace: tr);
  }
}

Future<void> deleteById(String id) async {
  final driveApi = await getDrive();
  if (driveApi == null) {
    return;
  }
  Sentry.addBreadcrumb(
      Breadcrumb(message: "Deleting backup", timestamp: DateTime.now()));
  await driveApi.files.delete(id);
}
