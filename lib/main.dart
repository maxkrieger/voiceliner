import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart' as sentry;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voice_outliner/repositories/db_repository.dart';
import 'package:voice_outliner/state/outline_state.dart';
import 'package:voice_outliner/state/player_state.dart';
import 'package:voice_outliner/views/notes_view.dart';
import 'package:voice_outliner/views/outlines_view.dart';

final routes = {"/": const OutlinesView(), "/notes": const NotesView()};

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final SharedPreferences sharedPrefs = await SharedPreferences.getInstance();
  if (sharedPrefs.getBool("should_transcribe") == null) {
    sharedPrefs.setBool("should_transcribe", true);
  }
  await sentry.SentryFlutter.init((config) {
    config.dsn = const String.fromEnvironment("SENTRY_DSN");
  },
      appRunner: () => runApp(MultiProvider(
              providers: [
                ChangeNotifierProvider<PlayerModel>(
                    create: (_) => PlayerModel()..load()),
                ChangeNotifierProvider<DBRepository>(
                  create: (_) => DBRepository()..load(),
                ),
                ChangeNotifierProxyProvider2<DBRepository, PlayerModel,
                        OutlinesModel>(
                    create: (_) => OutlinesModel(),
                    update: (_, d, p, o) => (o ?? OutlinesModel())..load(p, d))
              ],
              child: VoiceOutlinerApp(
                sharedPreferences: sharedPrefs,
              ))));
}

class VoiceOutlinerApp extends StatefulWidget {
  final SharedPreferences sharedPreferences;
  const VoiceOutlinerApp({Key? key, required this.sharedPreferences})
      : super(key: key);

  @override
  _VoiceOutlinerAppState createState() => _VoiceOutlinerAppState();
}

class _VoiceOutlinerAppState extends State<VoiceOutlinerApp> {
  String? lastRoute;
  String? lastOutline;

  @override
  void initState() {
    super.initState();
    setState(() {
      lastRoute = widget.sharedPreferences.getString("last_route");
      lastOutline = widget.sharedPreferences.getString("last_outline");
    });
  }

  Future<void> saveRoute(RouteSettings route) async {
    await widget.sharedPreferences.setString("last_route", route.name!);
    if (route.arguments != null) {
      await widget.sharedPreferences.setString(
          "last_outline", (route.arguments as NotesViewArgs).outlineId);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool loading = context.select<OutlinesModel, bool>((m) => m.isReady);
    if (!loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return MaterialApp(
      title: 'Voice Outliner',
      onGenerateRoute: (RouteSettings route) {
        saveRoute(route);
        final rte = routes[route.name];
        if (rte == null) {
          throw ("Route null");
        }
        return PageRouteBuilder(
            pageBuilder: (c, a, aa) => rte,
            transitionsBuilder: (c, an, an2, child) =>
                Align(child: FadeTransition(opacity: an, child: child)),
            transitionDuration: const Duration(milliseconds: 300),
            settings: RouteSettings(
                name: route.name,
                arguments: route.arguments ??
                    (lastOutline != null
                        ? NotesViewArgs(lastOutline!)
                        : null)));
      },
      initialRoute: lastRoute ?? "/",
      theme: ThemeData(
          primarySwatch: Colors.deepPurple,
          primaryColor: const Color.fromRGBO(169, 129, 234, 1)),
      color: const Color.fromRGBO(169, 129, 234, 1),
    );
  }
}
