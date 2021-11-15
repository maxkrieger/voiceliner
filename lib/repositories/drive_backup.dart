import 'dart:io' as IO;

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:filesize/filesize.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:voice_outliner/state/player_state.dart';

const driveEnabledKey = "drive_enabled";

GoogleSignIn googleSignIn = GoogleSignIn(
    clientId:
        "658946540988-ak572264ge5odag4o8euqe5ev6bf354l.apps.googleusercontent.com",
    scopes: [DriveApi.driveAppdataScope]);

Future<DriveApi> getDrive() async {
  assert(googleSignIn.currentUser != null);
  final httpClient = (await googleSignIn.authenticatedClient())!;
  return DriveApi(httpClient);
}

Future<String> getUsage() async {
  final driveApi = await getDrive();
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

Future<void> uploadFile(DriveApi driveApi, IO.File file,
    {String? folderId}) async {
  if (folderId == null) {
    final existingRecordings = await driveApi.files.list(
        spaces: "appDataFolder",
        q: "name = 'recordings'",
        orderBy: "modifiedTime");
    if (existingRecordings.files != null &&
        existingRecordings.files!.isNotEmpty) {
      folderId = existingRecordings.files!.first.id!;
    } else {
      Sentry.captureMessage(
          "Could not back up because recordings folder doesn't exist",
          level: SentryLevel.error);
      return;
    }
  }
  final driveFile = File();
  driveFile.parents = [folderId];
  driveFile.name = file.uri.pathSegments.last;
  final length = await file.length();
  final media = Media(file.openRead(), length);
  await driveApi.files.create(driveFile, uploadMedia: media);
}

Future<DateTime?> lastModified() async {
  final driveApi = await getDrive();
  final existing = await driveApi.files.list(
      spaces: "appDataFolder",
      pageSize: 1,
      q: "name = 'voice_outliner.db'",
      $fields: "files(modifiedTime)",
      orderBy: "modifiedTime");
  if (existing.files != null && existing.files!.isNotEmpty) {
    return existing.files!.first.modifiedTime;
  } else {
    return null;
  }
}

Future<void> uploadDb(
  DriveApi driveApi,
) async {
  final docsDir = await getApplicationDocumentsDirectory();
  final dbFile = IO.File(docsDir.path + "/voice_outliner.db");
  final driveFile = File();
  driveFile.modifiedTime = DateTime.now();
  final length = await dbFile.length();
  final media = Media(dbFile.openRead(), length);
  final existing = await driveApi.files.list(
    spaces: "appDataFolder",
    q: "name = 'voice_outliner.db'",
    orderBy: "modifiedTime",
  );
  if (existing.files != null && existing.files!.isNotEmpty) {
    final id = existing.files!.first.id!;
    await driveApi.files.update(driveFile, id, uploadMedia: media);
  } else {
    driveFile.name = dbFile.uri.pathSegments.last;
    driveFile.parents = ["appDataFolder"];
    driveApi.files.create(driveFile, uploadMedia: media);
  }
}

Future<void> deleteAll(DriveApi driveApi) async {
  final existing = await driveApi.files.list(spaces: "appDataFolder");
  if (existing.files != null) {
    for (var file in existing.files!) {
      await driveApi.files.delete(file.id!);
    }
  }
}

Future<int> uploadAll() async {
  int count = 0;
  Sentry.addBreadcrumb(Breadcrumb(message: "Backing up all"));
  final driveApi = await getDrive();
  await deleteAll(driveApi);
  await uploadDb(driveApi);
  final recordingsDir = await getRecordingsDir();
  final _driveFolder = File();
  _driveFolder.parents = const ["appDataFolder"];
  _driveFolder.name = "recordings";
  _driveFolder.mimeType = "application/vnd.google-apps.folder";
  final driveFolder = await driveApi.files.create(_driveFolder);
  final recordingsId = driveFolder.id;
  if (recordingsId != null) {
    await recordingsDir.list().forEach((element) async {
      if (element is IO.File) {
        count++;
        await uploadFile(driveApi, element, folderId: recordingsId);
      }
    });
  }
  Sentry.addBreadcrumb(Breadcrumb(message: "Done backing up"));
  return count;
}

Future<void> downloadFile(
    DriveApi driveApi, File file, IO.Directory directory) async {
  final contents = (await driveApi.files
      .get(file.id!, downloadOptions: DownloadOptions.fullMedia)) as Media;
  final diskFile =
      await IO.File("${directory.path}/${file.name!}").create(recursive: true);
  final fileSink = diskFile.openWrite();
  contents.stream.listen((chunk) {
    fileSink.add(chunk);
  }, onDone: () {
    fileSink.close();
  });
}

// Make sure to reload the db after
Future<int> downloadAll() async {
  Sentry.addBreadcrumb(Breadcrumb(message: "Restoring from backup"));
  int count = 0;
  final driveApi = await getDrive();
  final docsDir = await getApplicationDocumentsDirectory();
  final recordingsDir = await getRecordingsDir();

  final existingDb = await driveApi.files.list(
      spaces: "appDataFolder",
      q: "name = 'voice_outliner.db'",
      orderBy: "modifiedTime");
  if (existingDb.files != null && existingDb.files!.isNotEmpty) {
    downloadFile(driveApi, existingDb.files!.first, docsDir);
  }
  final existingRecordings = await driveApi.files
      .list(spaces: "appDataFolder", q: "name = 'recordings'");
  if (existingRecordings.files != null &&
      existingRecordings.files!.isNotEmpty) {
    String? pageToken;
    while (true) {
      final files = await driveApi.files.list(
          spaces: "appDataFolder",
          pageSize: 1000,
          pageToken: pageToken,
          $fields: "nextPageToken, files(id, name)",
          orderBy: "modifiedTime",
          q: "'${existingRecordings.files!.first.id}' in parents");
      pageToken = files.nextPageToken;
      if (files.files != null) {
        count += files.files!.length;
        for (var file in files.files!) {
          await downloadFile(driveApi, file, recordingsDir);
        }
      }
      if (pageToken == null || files.files == null || files.files!.isEmpty) {
        break;
      }
    }
  }
  Sentry.addBreadcrumb(Breadcrumb(message: "Done restoring"));
  return count;
}
