import 'package:cham_cong_don_gian/domain/models.dart';

/// Máy mới cài để mọi số tiền bằng 0 (từ 2026-10-18). Các test tính tiền dùng bộ số mẫu cũ này:
/// công nhân lương cơ bản 4.000.000, thưởng thành tích 2.000.000, trợ cấp 800.000, cơm trưa 10.000,
/// công đoàn 50.000, tăng ca 45.000 (lễ 63.000); công nhật lương ngày 350.000.
AppSettings sampleDefaults(WorkerKind kind, {AppSettings? keep}) {
  final s = AppSettings.defaultsFor(kind, keep: keep);
  final worker = kind == WorkerKind.worker;
  final amounts = {
    payItemPerformance: 2000000.0,
    payItemAllowance: 800000.0,
    payItemLunch: 10000.0,
    payItemUnion: 50000.0,
  };
  return s.copyWith(
    baseSalary: worker ? 4000000 : 0,
    dailyWage: worker ? 0 : 350000,
    wageTable: worker
        ? WageTable(
            rates: {
              DayType.weekday: const WageRate(overtimePerHour: 45000),
              DayType.saturday: const WageRate(overtimePerHour: 45000),
              DayType.sunday: const WageRate(normalPerHour: 45000, overtimePerHour: 45000),
              DayType.holiday: const WageRate(normalPerHour: 63000, overtimePerHour: 63000),
            },
          )
        : s.wageTable,
    incomeItems: [for (final i in s.incomeItems) amounts.containsKey(i.id) ? i.copyWith(amount: amounts[i.id]) : i],
  );
}
