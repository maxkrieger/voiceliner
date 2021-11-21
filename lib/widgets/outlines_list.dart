import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago_flutter/timeago_flutter.dart';
import 'package:voice_outliner/data/outline.dart';
import 'package:voice_outliner/state/outline_state.dart';

class OutlinesList extends StatelessWidget {
  final Function(String) onTap;
  const OutlinesList({Key? key, required this.onTap}) : super(key: key);

  Widget _buildOutline(BuildContext ctx, int num) {
    return Builder(builder: (ct) {
      final outline = ct.select<OutlinesModel, Outline>((value) =>
          value.outlines.length > num ? value.outlines[num] : defaultOutline);
      return Card(
          key: Key("outline-$num"),
          child: ListTile(
            title: Text(outline.name),
            subtitle:
                Timeago(builder: (_, t) => Text(t), date: outline.dateUpdated),
            onLongPress: () {
              print("long press");
            },
            onTap: () {
              onTap(outline.id);
            },
          ));
    });
  }

  @override
  Widget build(BuildContext context) {
    final numOutlines =
        context.select<OutlinesModel, int>((value) => value.outlines.length);
    return Scrollbar(
        child: ListView.builder(
            shrinkWrap: true,
            itemCount: numOutlines,
            itemBuilder: _buildOutline));
  }
}
