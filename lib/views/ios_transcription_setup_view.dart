import 'package:flutter/material.dart';
import 'package:voice_outliner/widgets/ios_locale_selector.dart';

class IOSTranscriptionSetupView extends StatelessWidget {
  const IOSTranscriptionSetupView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Setup"),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Center(
              child: Column(children: [
            const Text(
              "Select transcription language",
              style: TextStyle(fontSize: 18.0),
            ),
            const SizedBox(height: 20),
            const IOSLocaleSelector(),
            const SizedBox(height: 20),
            ElevatedButton(
                onPressed: () => Navigator.pushNamedAndRemoveUntil(
                    context, "/", (route) => false),
                child: const Text("continue"))
          ]))),
    );
  }
}
