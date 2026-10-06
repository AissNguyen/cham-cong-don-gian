/// Biểu đồ cột giờ công theo từng ngày trong kỳ: cột cao theo số giờ công thực nhận (normal +
/// tăng ca). Nếu giờ vào thực tế khác giờ vào chuẩn (đi giờ khác, không phải "đi muộn" bị trừ
/// lương — không liên quan công tắc "Đi muộn"), phía trên cột có thêm một khúc chỉ có viền (cùng
/// màu cột, bên trong để trống), cao bằng khoảng cách từ giờ vào chuẩn tới giờ chấm vào thực tế —
/// chỉ để biết, không trừ/cộng gì thêm; phần tô đặc bên dưới vẫn là số giờ công thật đã tính ở
/// computeDay.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../data/store.dart';
import '../../domain/calc.dart';
import '../../domain/models.dart';
import '../../domain/pay_period.dart';
import '../../theme/app_theme.dart';
import '../format.dart';

class _DayBar {
  _DayBar({required this.date, required this.paidHours, required this.lateHours, required this.hasData});

  final DateTime date;
  final double paidHours;
  final double lateHours;

  /// false nếu ngày nghỉ / chưa chấm / ca chưa chấm ra — cột để trống, không vẽ.
  final bool hasData;

  double get total => paidHours + lateHours;
}

String _fmtH(double h) {
  final rounded = (h * 10).round() / 10;
  return rounded == rounded.roundToDouble() ? rounded.toInt().toString() : rounded.toString();
}

class PeriodDayChart extends StatelessWidget {
  const PeriodDayChart({super.key, required this.period, required this.recordOf, required this.settings});

  final PayPeriod period;
  final DayRecord Function(DateTime date) recordOf;
  final AppSettings settings;

  List<_DayBar> _buildDays() {
    final days = <_DayBar>[];
    for (var d = period.start; !d.isAfter(period.end); d = d.add(const Duration(days: 1))) {
      final record = recordOf(d);
      if (record.isDayOff || record.checkIn == null || record.checkOut == null) {
        days.add(_DayBar(date: d, paidHours: 0, lateHours: 0, hasData: false));
        continue;
      }
      final result = computeDay(record, settings);
      // Khoảng đi muộn chỉ để biết trực quan, tính thẳng từ chênh lệch giờ vào thực tế so với giờ
      // vào chuẩn — không phụ thuộc công tắc "Đi muộn" (công tắc đó chỉ dùng cho việc trừ lương).
      var lateHours = 0.0;
      final workStartDt = DateTime(d.year, d.month, d.day, settings.workStart.hour, settings.workStart.minute);
      final gapMinutes = record.checkIn!.difference(workStartDt).inMinutes;
      if (gapMinutes > 0) lateHours = gapMinutes / 60;
      days.add(
        _DayBar(date: d, paidHours: result.normalHours + result.overtimeHours, lateHours: lateHours, hasData: true),
      );
    }
    return days;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final days = _buildDays();

    final maxTotal = days.fold<double>(0, (m, d) => d.total > m ? d.total : m);
    var maxY = (((maxTotal <= 0 ? 8 : maxTotal) / 2).ceil() * 2).toDouble();
    if (maxY < 8) maxY = 8;
    maxY += 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _legendDot(colors.gradientStart),
            const SizedBox(width: 4),
            Text('Giờ công', style: TextStyle(fontSize: 11.5, color: colors.ink2)),
            const SizedBox(width: 14),
            _legendDot(colors.gradientStart, hollow: true),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                'Đi giờ khác (không tính thêm)',
                style: TextStyle(fontSize: 11.5, color: colors.ink2),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 170,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final slot = (constraints.maxWidth - 30) / days.length;
              final barWidth = (slot * 0.6).clamp(2.0, 12.0);
              return BarChart(
                BarChartData(
                  maxY: maxY,
                  minY: 0,
                  groupsSpace: 0,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => const Color(0xFF1F2937),
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final day = days[group.x.toInt() - 1];
                        if (!day.hasData) {
                          return BarTooltipItem(
                            'Ngày ${day.date.day}: chưa chấm',
                            const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600),
                          );
                        }
                        final children = <TextSpan>[
                          if (day.lateHours > 0)
                            TextSpan(
                              text: '\nĐi giờ khác ${_fmtH(day.lateHours)}h',
                              style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
                            ),
                        ];
                        return BarTooltipItem(
                          'Ngày ${day.date.day}: ${_fmtH(day.paidHours)}h công',
                          const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600),
                          children: children,
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 18,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt() - 1;
                          if (i < 0 || i >= days.length) return const SizedBox.shrink();
                          final day = days[i].date.day;
                          final isLast = i == days.length - 1;
                          if (day != 1 && day % 5 != 0 && !isLast) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('$day', style: TextStyle(fontSize: 9, color: colors.ink2)),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 26,
                        interval: 2,
                        getTitlesWidget: (value, meta) =>
                            Text(value.toInt().toString(), style: TextStyle(fontSize: 9, color: colors.ink2)),
                      ),
                    ),
                  ),
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    horizontalInterval: 2,
                    getDrawingHorizontalLine: (value) => FlLine(color: colors.line, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      HorizontalLine(
                        y: 8,
                        color: colors.ink3,
                        strokeWidth: 1,
                        dashArray: const [5, 4],
                        label: HorizontalLineLabel(
                          show: true,
                          alignment: Alignment.topRight,
                          style: TextStyle(fontSize: 9, color: colors.ink3),
                          labelResolver: (_) => '8h · ngày thường',
                        ),
                      ),
                    ],
                  ),
                  barGroups: [
                    for (var i = 0; i < days.length; i++)
                      BarChartGroupData(
                        x: i + 1,
                        barRods: [
                          BarChartRodData(
                            toY: days[i].total,
                            width: barWidth,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                            // Có khúc "đi giờ khác" thì để nền cột trong suốt (thư viện vẽ nền cả
                            // cột trước rồi mới vẽ từng khúc), khúc trên chỉ có viền.
                            color: !days[i].hasData
                                ? colors.line
                                : (days[i].lateHours > 0 ? Colors.transparent : colors.gradientStart),
                            rodStackItems: days[i].hasData && days[i].lateHours > 0
                                ? [
                                    BarChartRodStackItem(0, days[i].paidHours, colors.gradientStart),
                                    BarChartRodStackItem(
                                      days[i].paidHours,
                                      days[i].total,
                                      Colors.transparent,
                                      borderSide: BorderSide(color: colors.gradientStart, width: 1.2),
                                    ),
                                  ]
                                : const [],
                          ),
                        ],
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _legendDot(Color color, {bool hollow = false}) => Container(
    width: 10,
    height: 10,
    decoration: BoxDecoration(
      color: hollow ? null : color,
      border: hollow ? Border.all(color: color, width: 1.2) : null,
      borderRadius: BorderRadius.circular(3),
    ),
  );
}

/// Khối hiện ngoài màn chính (không cần bấm mở), có nút lùi/tiến để xem biểu đồ của các kỳ trước.
class PeriodDayChartSection extends StatefulWidget {
  const PeriodDayChartSection({super.key, required this.store});

  final AppStore store;

  @override
  State<PeriodDayChartSection> createState() => _PeriodDayChartSectionState();
}

class _PeriodDayChartSectionState extends State<PeriodDayChartSection> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final today = dateOnly(DateTime.now());
    final periods = recentPeriods(today, widget.store.settings.payPeriod, count: 12);
    final index = _index.clamp(0, periods.length - 1);
    final period = periods[index];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: colors.line.withValues(alpha: 0.6), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Giờ làm theo ngày', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Kỳ trước',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                onPressed: index < periods.length - 1 ? () => setState(() => _index = index + 1) : null,
              ),
              SizedBox(
                width: 84,
                child: Text(
                  '${fmtDM(period.start)}–${fmtDM(period.end)}',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11.5, color: colors.ink2),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Kỳ sau',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                onPressed: index > 0 ? () => setState(() => _index = index - 1) : null,
              ),
            ],
          ),
          const SizedBox(height: 10),
          PeriodDayChart(period: period, recordOf: widget.store.recordFor, settings: widget.store.settings),
        ],
      ),
    );
  }
}
