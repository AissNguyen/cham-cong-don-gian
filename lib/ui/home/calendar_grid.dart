import 'package:flutter/material.dart';

import '../../data/store.dart';
import '../../domain/calc.dart';
import '../../domain/lunar.dart' as lunar;
import '../../domain/models.dart';
import '../format.dart';
import '../../theme/app_theme.dart';

class CalendarGrid extends StatelessWidget {
  const CalendarGrid({
    super.key,
    required this.month,
    required this.selectedDate,
    required this.store,
    required this.showLunar,
    required this.showMoneyPerDay,
    required this.showCheckTimes,
    required this.moneyOf,
    required this.onSelect,
  });

  final DateTime month;
  final DateTime selectedDate;
  final AppStore store;
  final bool showLunar;
  final bool showMoneyPerDay;
  final bool showCheckTimes;

  /// Tiền của một ngày, lấy từ phiếu lương của kỳ chứa ngày đó.
  final double Function(DateTime date) moneyOf;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final firstOfMonth = DateTime(month.year, month.month, 1);
    final leadingBlank = firstOfMonth.weekday - 1; // T2 = 1
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final totalCells = leadingBlank + daysInMonth;
    final rows = (totalCells / 7).ceil();
    final today = dateOnly(DateTime.now());

    // Cỡ chữ trong ô lịch cố định, không theo cỡ chữ hệ thống — ô quá nhỏ nếu phóng to sẽ đè lên nhau.
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: Column(
        children: [
          Row(
            children: weekdayShort
                .map(
                  (w) => Expanded(
                    child: Center(
                      child: Text(
                        w,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.appColors.ink3),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 10),
          for (var r = 0; r < rows; r++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  for (var c = 0; c < 7; c++)
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final cellIndex = r * 7 + c;
                          final dayNum = cellIndex - leadingBlank + 1;
                          if (dayNum < 1 || dayNum > daysInMonth) return SizedBox(height: showCheckTimes ? 70 : 58);
                          final date = DateTime(month.year, month.month, dayNum);
                          return _DayCell(
                            date: date,
                            isToday: date == today,
                            isSelected: date == selectedDate,
                            store: store,
                            showLunar: showLunar,
                            showMoneyPerDay: showMoneyPerDay,
                            showCheckTimes: showCheckTimes,
                            money: showMoneyPerDay ? moneyOf(date) : 0,
                            onTap: () => onSelect(date),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.isToday,
    required this.isSelected,
    required this.store,
    required this.showLunar,
    required this.showMoneyPerDay,
    required this.showCheckTimes,
    required this.money,
    required this.onTap,
  });

  final DateTime date;
  final bool isToday;
  final bool isSelected;
  final AppStore store;
  final bool showLunar;
  final bool showMoneyPerDay;
  final bool showCheckTimes;

  /// Tiền của ngày theo phiếu lương (chỉ dùng khi bật "Lương mỗi ngày").
  final double money;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final record = store.recordFor(date);
    final today = dateOnly(DateTime.now());
    final isFuture = date.isAfter(today);
    final result = isFuture ? DayCalcResult.zero : computeDay(record, store.settings);
    final hasNote = (record.note != null && record.note!.isNotEmpty) || record.tags.isNotEmpty;
    // Ngày lễ (mặc định hoặc tự thêm) -> viền riêng để biết ngay, trừ khi đã đánh dấu nghỉ (đã có
    // màu riêng rồi).
    final isHoliday = !record.isDayOff && dayTypeOf(date, store.settings.holidays) == DayType.holiday;

    Color fill = Colors.transparent;
    Color onFill = Theme.of(context).colorScheme.onSurface;
    Color borderColor = colors.line;
    String? bottomLabel;
    String? bottomLabel2;
    String? bottomLabel3;

    if (record.isDayOff) {
      fill = colors.dayOffMark;
      onFill = Colors.white;
      borderColor = colors.dayOffMark;
      bottomLabel = record.paidLeave ? 'Nghỉ ₫' : 'Nghỉ';
    } else if (isFuture) {
      bottomLabel = null;
    } else if (!record.hasAttendance) {
      borderColor = colors.warnSoft;
      onFill = colors.warn;
      bottomLabel = date.isBefore(today) ? 'Chưa' : null;
    } else if (record.isOpenShift) {
      fill = colors.openShiftMark;
      onFill = Colors.white;
      borderColor = colors.openShiftMark;
      if (showCheckTimes) {
        bottomLabel = Clock(record.checkIn!.hour, record.checkIn!.minute).formatted;
        bottomLabel2 = '…';
      } else {
        bottomLabel = 'Đang';
      }
    } else {
      fill = Theme.of(context).colorScheme.primary;
      onFill = Colors.white;
      borderColor = Theme.of(context).colorScheme.primary;
      if (showCheckTimes) {
        bottomLabel = Clock(record.checkIn!.hour, record.checkIn!.minute).formatted;
        bottomLabel2 = Clock(record.checkOut!.hour, record.checkOut!.minute).formatted;
        bottomLabel3 = fmtHours(result.normalMinutes + result.overtimeMinutes);
      } else {
        bottomLabel = showMoneyPerDay ? _shortMoney(money) : fmtHours(result.normalMinutes);
      }
    }

    final lunarDate = showLunar ? lunar.solarToLunar(date.day, date.month, date.year) : null;
    if (isFuture) onFill = colors.ink3;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: showCheckTimes ? 70 : 58,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? colors.selectMark
                : (isHoliday ? colors.holidayMark : borderColor),
            width: isSelected
                ? 2.5
                : (isHoliday ? 2 : 1),
          ),
          boxShadow: fill == Colors.transparent
              ? null
              : [BoxShadow(color: fill.withValues(alpha: 0.35), blurRadius: 6, offset: const Offset(0, 3))],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Số ngày lớn + trạng thái nhỏ, giữa ô.
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: bottomLabel3 != null
                          ? 15
                          : bottomLabel2 != null
                          ? 16
                          : 19,
                      height: 1,
                      color: onFill,
                    ),
                  ),
                  if (bottomLabel != null)
                    Text(
                      bottomLabel,
                      style: TextStyle(
                        fontSize: bottomLabel3 != null ? 9.5 : 9,
                        fontWeight: FontWeight.w600,
                        height: bottomLabel2 != null ? 1.1 : 1.3,
                        color: onFill == Colors.white ? Colors.white : colors.ink2,
                      ),
                    ),
                  if (bottomLabel2 != null)
                    Text(
                      bottomLabel2,
                      style: TextStyle(
                        fontSize: bottomLabel3 != null ? 9.5 : 9,
                        fontWeight: FontWeight.w600,
                        height: 1.1,
                        color: onFill == Colors.white ? Colors.white : colors.ink2,
                      ),
                    ),
                  if (bottomLabel3 != null)
                    Text(
                      bottomLabel3,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                        color: onFill == Colors.white ? Colors.white : colors.ink2,
                      ),
                    ),
                ],
              ),
            ),
            // Huy hiệu tăng ca, nổi ở góc phải trên (đè ra ngoài viền như thẻ thông báo).
            if (result.overtimeMinutes > 0)
              Positioned(
                top: -7,
                right: -5,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: colors.overtimeMark,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 1))],
                  ),
                  child: Text(
                    fmtHours(result.overtimeMinutes),
                    style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ),
              ),
            // Chấm tròn đi muộn, nổi ở góc trái trên.
            if (record.isLate)
              Positioned(
                top: -3,
                left: -3,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: colors.lateMark,
                    shape: BoxShape.circle,
                    border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 1.5),
                  ),
                ),
              ),
            // Ngày âm, góc trái dưới.
            if (lunarDate != null)
              Positioned(
                left: 4,
                bottom: 3,
                child: Text(lunarDate.short, style: TextStyle(fontSize: 8, color: onFill == Colors.white ? Colors.white70 : colors.ink3)),
              ),
            // Chấm ghi chú, góc phải dưới — ẩn khi xem giờ vào/ra vì chữ đã chiếm hết chỗ dưới.
            if (hasNote && !showCheckTimes)
              Positioned(
                right: 4,
                bottom: 3,
                child: Icon(Icons.circle, size: 6, color: onFill == Colors.white ? Colors.white : colors.noteMark),
              ),
            if (isToday && !showCheckTimes)
              Positioned(
                bottom: 3,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(color: onFill == Colors.white ? Colors.white : Theme.of(context).colorScheme.primary, shape: BoxShape.circle),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// "1,2tr", "350k": bỏ phần lẻ (không làm tròn lên); âm thì có dấu "−".
  String _shortMoney(double v) {
    final sign = v < 0 ? '−' : '';
    final a = v.abs();
    if (a >= 1e6) return '$sign${fmtN((a / 1e5).truncate() / 10)}tr';
    if (a >= 1e3) return '$sign${(a / 1e3).truncate()}k';
    return '$sign${a.truncate()}';
  }
}
