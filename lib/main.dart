import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart' as sentry;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voice_outliner/repositories/db_repository.dart';
import 'package:voice_outliner/repositories/drive_backup.dart';
import 'package:voice_outliner/repositories/vosk_speech_recognizer.dart';
import 'package:voice_outliner/state/outline_state.dart';
import 'package:voice_outliner/state/player_state.dart';
import 'package:voice_outliner/views/ios_transcription_setup_view.dart';
import 'package:voice_outliner/views/notes_view.dart';
import 'package:voice_outliner/views/onboarding_view.dart';
import 'package:voice_outliner/views/outlines_view.dart';
import 'package:voice_outliner/views/vosk_transcription_setup_view.dart';

import 'consts.dart';
import 'globals.dart';

final routes = {
  "/": const OutlinesView(),
  "/notes": const NotesView(),
  "/onboarding": const OnboardingView(),
  "/transcription_setup_vosk": const VoskTranscriptionSetupView(),
  "/transcription_setup_ios": const IOSTranscriptionSetupView()
};

const generalAppBar =
    AppBarTheme(elevation: 0.4, centerTitle: false, titleSpacing: 20);

final theme = ThemeData(
  fontFamily: "Work Sans",
  appBarTheme: generalAppBar.copyWith(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      titleTextStyle: const TextStyle(
          fontFamily: "Work Sans",
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: Colors.black)),
  focusColor: classicPurple,
  primarySwatch: Colors.deepPurple,
  primaryColor: classicPurple,
);

Future<void> main() async {
  await dotenv.load(fileName: ".env");

  final SharedPreferences sharedPrefs = await SharedPreferences.getInstance();
  if (sharedPrefs.getBool(shouldTranscribeKey) == null) {
    sharedPrefs.setBool(shouldTranscribeKey, true);
  }
  if (sharedPrefs.getBool(driveEnabledKey) ?? false) {
    await googleSignIn.signInSilently();
  }
  if (Platform.isAndroid) {
    final modelDir = sharedPrefs.getString(modelDirKey);
    if (modelDir != null) {
      await voskInitModel(modelDir);
    }
  }
  void appRunner() => runApp(MultiProvider(
          providers: [
            ChangeNotifierProvider<PlayerModel>(
                lazy: false, create: (_) => PlayerModel()..load()),
            ChangeNotifierProvider<DBRepository>(
              lazy: false,
              create: (_) => DBRepository()..load(),
            ),
            ChangeNotifierProxyProvider2<DBRepository, PlayerModel,
                    OutlinesModel>(
                create: (_) => OutlinesModel(),
                update: (_, d, p, o) => (o ?? OutlinesModel())..load(p, d))
          ],
          child: VoiceOutlinerApp(
            sharedPreferences: sharedPrefs,
          )));
  if (kReleaseMode) {
    await sentry.SentryFlutter.init((config) {
      config.dsn = dotenv.env["SENTRY_DSN"];
      config.diagnosticLevel = sentry.SentryLevel.error;
    }, appRunner: appRunner);
  } else {
    print("debug mode!");
    appRunner();
  }
}

class VoiceOutlinerApp extends StatefulWidget {
  final SharedPreferences sharedPreferences;
  const VoiceOutlinerApp({Key? key, required this.sharedPreferences})
      : super(key: key);

  @override
  _VoiceOutlinerAppState createState() => _VoiceOutlinerAppState();
}

class _VoiceOutlinerAppState extends State<VoiceOutlinerApp> {
  String? lastOutline;

  @override
  void initState() {
    super.initState();
    setState(() {
      lastOutline = widget.sharedPreferences.getString(lastOutlineKey);
    });
  }

  Future<void> saveRoute(RouteSettings route) async {
    await widget.sharedPreferences.setString("last_route", route.name!);
    if (route.arguments != null) {
      await widget.sharedPreferences.setString(
          "last_outline", (route.arguments as NotesViewArgs).outlineId);
    }
  }

  String _initialRoute() {
    final lastRoute = widget.sharedPreferences.getString(lastRouteKey);
    // If you've onboarded but don't have language set up on android
    if (Platform.isAndroid &&
        widget.sharedPreferences.getString(modelDirKey) == null &&
        (widget.sharedPreferences.getBool(shouldTranscribeKey) ?? true) &&
        lastRoute != null) {
      return "/transcription_setup_vosk";
    }
    // If you've onboarded but don't have language set up on iOS
    if (Platform.isIOS &&
        widget.sharedPreferences.getString(localeKey) == null &&
        (widget.sharedPreferences.getBool(shouldTranscribeKey) ?? true) &&
        lastRoute != null) {
      return "/transcription_setup_ios";
    }
    if (lastRoute != null) {
      return lastRoute;
    }
    return "/onboarding";
  }

  @override
  Widget build(BuildContext context) {
    bool loading = context.select<OutlinesModel, bool>((m) => m.isReady);
    if (!loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return MaterialApp(
      title: 'Voiceliner',
      scaffoldMessengerKey: snackbarKey,
      debugShowCheckedModeBanner: false,
      onGenerateRoute: (RouteSettings route) {
        saveRoute(route);
        final rte = routes[route.name];
        if (rte == null) {
          throw ("Route null");
        }
        return PageRouteBuilder(
            pageBuilder: (c, a, aa) => rte,
            transitionsBuilder: (c, an, an2, child) => Align(
                child: SlideTransition(
                    position: Tween<Offset>(
                      begin: Offset(route.name == "/" ? -1 : 1, 0),
                      end: Offset.zero,
                    ).animate(an),
                    child: child)),
            transitionDuration: const Duration(milliseconds: 200),
            settings: RouteSettings(
                name: route.name,
                arguments: route.arguments ??
                    (lastOutline != null
                        ? NotesViewArgs(lastOutline!)
                        : null)));
      },
      initialRoute: _initialRoute(),
      themeMode: ThemeMode.system,
      theme: theme,
      darkTheme: ThemeData(
          fontFamily: "Work Sans",
          appBarTheme: generalAppBar.copyWith(
              titleTextStyle: const TextStyle(
                  fontFamily: "Work Sans",
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
          brightness: Brightness.dark,
          primaryColor: classicPurple,
          primarySwatch: Colors.deepPurple),
      color: classicPurple,
    );
  }
}
