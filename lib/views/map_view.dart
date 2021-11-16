import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:voice_outliner/repositories/db_repository.dart';

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
  @override
  void initState() {
    super.initState();
    loadPins();
  }

  void pushOutline(BuildContext ctx, String outlineId) {
    Navigator.pushNamedAndRemoveUntil(ctx, "/notes", (_) => false,
        arguments: NotesViewArgs(outlineId));
  }

  Future<void> loadPins() async {
    List<Map<String, dynamic>> results = [];
    if (widget.outlineId != null) {
      results.addAll(await context
          .read<DBRepository>()
          .getNotesForOutlineId(widget.outlineId!));
    } else {
      //  TODO: getAllNotes
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
        .toList();
    if (filtered.isNotEmpty) {
      setState(() {
        notes = filtered;
        bounds = LatLngBounds.fromPoints(filtered.map((e) => e.point).toList());
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No notes have locations")));
    }
    setState(() {
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Map"),
      ),
      body: !loading
          ? (notes.isNotEmpty
              ? FlutterMap(
                  options: MapOptions(
                      bounds: bounds,
                      boundsOptions:
                          const FitBoundsOptions(padding: EdgeInsets.all(8.0))),
                  layers: [
                    TileLayerOptions(
                        urlTemplate:
                            "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                        subdomains: ['a', 'b', 'c']),
                    MarkerLayerOptions(
                        markers: notes
                            .map((Pin note) => Marker(
                                point: note.point,
                                width: 130,
                                builder: (ctx) => ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                        primary: Colors.deepPurpleAccent
                                            .withOpacity(0.5)),
                                    onPressed: () =>
                                        pushOutline(ctx, note.outlineId),
                                    child: Text(
                                      note.label,
                                      overflow: TextOverflow.fade,
                                    )),
                                key: Key(note.id)))
                            .toList())
                  ],
                )
              : const Center(child: Text("No notes have locations")))
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
