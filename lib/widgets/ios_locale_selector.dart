import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voice_outliner/consts.dart';
import 'package:voice_outliner/repositories/ios_speech_recognizer.dart';

class IOSLocaleSelector extends StatefulWidget {
  const IOSLocaleSelector({Key? key}) : super(key: key);

  @override
  _IOSLocaleSelectorState createState() => _IOSLocaleSelectorState();
}

class _IOSLocaleSelectorState extends State<IOSLocaleSelector> {
  late SharedPreferences sharedPreferences;
  bool isInited = false;
  Map<String, String> locales = {};
  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    sharedPreferences = await SharedPreferences.getInstance();
    locales = await getLocaleOptions();
    setState(() {
      // Initiate side effect so if the user doesn't touch the dropdown, it's saved as en-US
      if (sharedPreferences.getString(localeKey) == null) {
        sharedPreferences.setString(localeKey, "en-US");
      }
      isInited = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!isInited) {
      return const Text("loading locales...");
    }
    final items = locales.entries
        .map((entry) =>
            DropdownMenuItem(value: entry.key, child: Text(entry.value)))
        .toList(growable: false);
    items.sort((a, b) => a.value!.compareTo(b.value!));
    return DropdownButton<String>(
        icon: const Icon(Icons.language),
        menuMaxHeight: 300,
        isExpanded: true,
        items: items,
        value: sharedPreferences.getString(localeKey) ?? "en-US",
        onChanged: (v) {
          setState(() {
            sharedPreferences.setString(localeKey, v!);
          });
        });
  }
}
