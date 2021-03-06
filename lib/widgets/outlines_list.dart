import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago_flutter/timeago_flutter.dart';
import 'package:voice_outliner/data/outline.dart';
import 'package:voice_outliner/state/outline_state.dart';

import '../consts.dart';

class OutlinesList extends StatelessWidget {
  final Function(String) onTap;
  final bool showArchived;
  final String? excludeItem;
  const OutlinesList(
      {Key? key,
      required this.onTap,
      this.showArchived = false,
      this.excludeItem})
      : super(key: key);

  Widget _buildOutline(BuildContext ctx, int num) {
    return Builder(builder: (ct) {
      final outline = ct.select<OutlinesModel, Outline>((value) =>
          value.outlines.length > num ? value.outlines[num] : defaultOutline);
      if (outline.id == excludeItem || (!showArchived && outline.archived)) {
        return const SizedBox(height: 0);
      }
      return ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 17),
        key: Key("outline-$num"),
        leading: outline.archived
            ? const Icon(Icons.archive)
            : CircleAvatar(
                child: Text(
                  outline.emoji,
                  textScaleFactor: 1.5,
                ),
                backgroundColor: classicPurple.withOpacity(0.2),
              ),
        tileColor:
            outline.archived ? const Color.fromRGBO(175, 175, 175, 0.1) : null,
        trailing: const Icon(Icons.chevron_right),
        title: Text(outline.name),
        subtitle:
            Timeago(builder: (_, t) => Text(t), date: outline.dateUpdated),
        onTap: () {
          onTap(outline.id);
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final numOutlines =
        context.select<OutlinesModel, int>((value) => value.outlines.length);
    return Scrollbar(
        child: ListView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            itemCount: numOutlines,
            itemBuilder: _buildOutline));
  }
}
