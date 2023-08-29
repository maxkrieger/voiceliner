import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voice_outliner/repositories/db_repository.dart';
import 'package:voice_outliner/views/settings_view.dart';

import '../consts.dart';
import 'notes_view.dart';

class MapView extends StatefulWidget {
  final String? outlineId;
  const MapView({Key? key, this.outlineId}) : super(key: key);

  @override
  _MapViewState createState() => _MapViewState();
}

class Pin {
  final String id;
  final String outlineId;
  final String label;
  final LatLng point;
  const Pin(
      {required this.outlineId,
      required this.label,
      required this.point,
      required this.id});
}

class _MapViewState extends State<MapView> {
  bool loading = true;
  List<Pin> notes = [];
  LatLngBounds bounds = LatLngBounds(LatLng(0, 0), LatLng(0, 0));
  LatLng? currentLoc;
  bool fitAll = true;
  final controller = MapController();
  SharedPreferences? sharedPreferences;
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () => loadPins());
  }

  void pushOutline(BuildContext ctx, String outlineId, String noteId) {
    Navigator.pushNamedAndRemoveUntil(ctx, "/notes", (_) => false,
        arguments: NotesViewArgs(outlineId, scrollToNoteId: noteId));
  }

  Future<void> loadPins() async {
    sharedPreferences = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> results = [];
    if (widget.outlineId != null) {
      results.addAll(await context
          .read<DBRepository>()
          .getNotesForOutlineId(widget.outlineId!, requireUncomplete: true));
    } else {
      results.addAll(await context
          .read<DBRepository>()
          .getAllNotes(requireUncomplete: true));
    }
    final filtered = results
        .where((element) => element["latitude"] != null)
        .map((e) => Pin(
            outlineId: e["outline_id"],
            id: e["id"],
            label: e["transcript"] ??
                DateFormat.yMd().format(DateTime.fromMillisecondsSinceEpoch(
                    e["date_created"],
                    isUtc: true)),
            point: LatLng(e["latitude"], e["longitude"])))
        .toList()
        .reversed
        .take(500)
        .toList()
        .reversed
        .toList();
    if (filtered.isNotEmpty) {
      setState(() {
        notes = filtered;
        bounds = LatLngBounds.fromPoints(filtered.map((e) => e.point).toList());
      });
    }

    if (sharedPreferences?.getBool(shouldLocateKey) ?? false) {
      final loc = await locationInstance.getLocation();
      final ll = LatLng(loc.latitude!, loc.longitude!);
      if (loc.latitude != null && loc.longitude != null) {
        setState(() {
          currentLoc = ll;
        });
      }
    }
    setState(() {
      loading = false;
    });
  }

  void toggleFit() {
    if (currentLoc == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Location unavailable, enable it in settings")));
    }
    if (fitAll && currentLoc != null) {
      controller.move(currentLoc!, 15.0);
    } else {
      final cz = controller.centerZoomFitBounds(bounds);
      controller.move(cz.center, cz.zoom);
    }
    setState(() {
      fitAll = !fitAll;
    });
  }

  void _openSettings() {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsView()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Map"),
        actions: [
          IconButton(
              tooltip: fitAll ? "go to current location" : "see all notes",
              onPressed: toggleFit,
              icon: fitAll
                  ? const Icon(Icons.gps_fixed)
                  : const Icon(Icons.map_outlined))
        ],
      ),
      body: !loading
          ? (notes.isNotEmpty
              ? FlutterMap(
                  mapController: controller,
                  options: MapOptions(
                    bounds: bounds,
                    boundsOptions:
                        const FitBoundsOptions(padding: EdgeInsets.all(8.0)),
                    interactiveFlags:
                        InteractiveFlag.all - InteractiveFlag.rotate,
                  ),
                  children: [
                    TileLayer(
                        urlTemplate:
                            "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                        subdomains: ['a', 'b', 'c']),
                    MarkerLayer(
                        markers: notes
                            .map((Pin note) => Marker(
                                point: note.point,
                                width: 130,
                                builder: (ctx) => ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.deepPurpleAccent
                                            .withOpacity(0.5)),
                                    onPressed: () => pushOutline(
                                        ctx, note.outlineId, note.id),
                                    child: Text(
                                      note.label,
                                      overflow: TextOverflow.fade,
                                    )),
                                key: Key(note.id)))
                            .toList())
                  ],
                )
              : (sharedPreferences?.getBool(shouldLocateKey) ?? false
                  ? const Center(child: Text("No notes have locations"))
                  : Center(
                      child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Location attachment is off"),
                        ElevatedButton(
                            onPressed: _openSettings,
                            child: const Text("open settings"))
                      ],
                    ))))
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
