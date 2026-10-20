/// Chi tiết "Giờ tăng ca bị trừ" của một kỳ (cách tính bù tăng ca): trừ để bù cho ngày nào, bao
/// nhiêu giờ.
library;

import 'package:flutter/material.dart';

import '../../domain/payslip.dart';
import '../../theme/app_theme.dart';
import '../format.dart';

Future<void> showOvertimeOffsetSheet(BuildContext context, Payslip slip) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (context) => _OvertimeOffsetSheet(slip: slip),
);

class _OvertimeOffsetSheet extends StatelessWidget {
  const _OvertimeOffsetSheet({required this.slip});

  final Payslip slip;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final days = slip.offsetDays;
    final uncovered = slip.offsetUncoveredSeconds;
    final small = TextStyle(fontSize: 12.5, color: colors.ink2);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            Text(
              'Giờ tăng ca bị trừ · kỳ ${fmtDM(slip.period.start)}–${fmtDM(slip.period.end)}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Đã trừ ${fmtHours(slip.offsetTakenSeconds ~/ 60)} tăng ca để bù giờ thiếu. '
              'Tăng ca còn lại: ${fmtHours(slip.overtimeMinutes)}.',
              style: small,
            ),
            if (uncovered > 0) ...[
              const SizedBox(height: 4),
              Text(
                'Tăng ca trong kỳ không đủ bù, còn thiếu ${fmtHours(uncovered ~/ 60)}.',
                style: small.copyWith(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 12),
            if (!slip.overtimeOffset)
              Text(
                'Chưa bật lấy tăng ca bù. Bật ở Cài đặt › Cài đặt tính công, mục "Lấy tăng ca bù vào ngày nghỉ, '
                'ngày đi muộn".',
                style: small,
              )
            else if (days.isEmpty)
              Text('Kỳ này chưa có ngày nào thiếu giờ.', style: small)
            else
              for (final d in days)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.line))),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(fmtDayLong(d.date), style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text(
                              '${d.dayOff ? (d.companyOff ? 'Công ty cho nghỉ' : 'Tự nghỉ (hết phép)') : (d.late ? 'Tự đi muộn' : 'Làm thiếu giờ')}'
                              ', thiếu ${fmtHours(d.shortSeconds ~/ 60)}',
                              style: small,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '−${fmtHours(d.coveredSeconds ~/ 60)}',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()]),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
