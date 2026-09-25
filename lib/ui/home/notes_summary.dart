import 'package:flutter/material.dart';

import '../../data/store.dart';
import '../format.dart';
import '../../theme/app_theme.dart';
import 'edit_dialogs.dart';

/// Tổng hợp lại toàn bộ ghi chú đã ghi trên các ngày, mới nhất trước.
class NotesSummary extends StatelessWidget {
  const NotesSummary({super.key, required this.store, required this.onSelectDate});

  final AppStore store;
  final ValueChanged<DateTime> onSelectDate;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final entries =
        store.records.values.where((r) => (r.note != null && r.note!.isNotEmpty) || r.tags.isNotEmpty).toList()
          ..sort((a, b) => b.date.compareTo(a.date));

    if (entries.isEmpty) {
      return Text('Chưa có ghi chú nào.', style: TextStyle(color: colors.ink2));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final r in entries)
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => onSelectDate(r.date),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 52,
                    child: Text(fmtDM(r.date), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (r.tags.isNotEmpty)
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              for (final tag in r.tags)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(color: colors.accentSoft, borderRadius: BorderRadius.circular(20)),
                                  child: Text(tag, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.primary)),
                                ),
                            ],
                          ),
                        if (r.note != null && r.note!.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(top: r.tags.isNotEmpty ? 4 : 0),
                            child: Text(r.note!, style: TextStyle(fontSize: 13, color: colors.ink2)),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Sửa ghi chú',
                    onPressed: () => showNoteSheet(context, store: store, date: r.date),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
