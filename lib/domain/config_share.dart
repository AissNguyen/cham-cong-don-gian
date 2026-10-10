/// Sao chép / dán cấu hình giữa các máy (thuần Dart).
///
/// Chuỗi kiểu mới viết gọn một dòng, chỉ gồm các con số của phần lương và cài đặt tính công: loại
/// người dùng, lương cơ bản / lương ngày, kỳ lương, giờ làm, bảng lương/giờ, đi muộn, khung tăng ca và
/// các khoản của phiếu lương. Không kèm ngày lễ, GPS và các danh sách cũ; máy nhận giữ nguyên những
/// thứ đó của mình. Vẫn đọc được chuỗi kiểu cũ (toàn bộ cài đặt dạng JSON).
library;

import 'dart:convert';

import 'models.dart';

/// Chữ mở đầu của chuỗi kiểu mới, để nhận ra đúng là cấu hình của app.
const configSharePrefix = 'CCDG1 ';

const _types = [DayType.weekday, DayType.saturday, DayType.sunday, DayType.holiday];

const _calcCodes = {
  IncomeCalcMethod.fixed: 'f',
  IncomeCalcMethod.perWorkDay: 'd',
  IncomeCalcMethod.percentOfBaseSalary: 'p',
  IncomeCalcMethod.salary: 's',
  IncomeCalcMethod.overtime: 'o',
};

/// Bỏ ".0" cho số tròn để chuỗi ngắn hơn.
num _n(double v) => v == v.roundToDouble() ? v.toInt() : v;

String encodeSettings(AppSettings s) {
  final data = <String, dynamic>{
    'k': s.workerKind == WorkerKind.worker ? 'w' : 'd',
    'b': _n(s.baseSalary),
    'dw': _n(s.dailyWage),
    'p': [s.payPeriod.type == PayPeriodType.monthly ? 'm' : 's', s.payPeriod.monthlyStartDay, s.payPeriod.semiFirstStart, s.payPeriod.semiFirstEnd],
    'h': [s.workStart.formatted, s.workEnd.formatted],
    'r': [
      for (final t in _types) [_n(s.wageTable.of(t).normalPerHour), _n(s.wageTable.of(t).overtimePerHour)],
    ],
    'l': [s.lateRule.unit == LateUnit.minutes ? 'm' : 'đ', _n(s.lateRule.amount), s.lateRule.after.formatted],
    'o': [
      for (final b in s.overtimeBrackets) [b.from.formatted, b.to.formatted, b.breakMinutes],
    ],
    'i': [
      for (final i in s.incomeItems)
        [
          i.id,
          i.name,
          i.type == IncomeItemType.income ? 1 : 0,
          _calcCodes[i.calcMethod],
          _n(i.amount),
          i.activeAfter?.formatted ?? '',
          if (i.inBasis) 1,
        ],
    ],
  };
  return '$configSharePrefix${jsonEncode(data)}';
}

/// Áp cấu hình trong [text] lên cài đặt hiện tại [current]: lấy phần lương, cài đặt tính công và
/// khung tăng ca theo chuỗi, giữ nguyên ngày lễ, GPS, công tắc ẩn/hiện và công chuẩn sửa tay của
/// máy này. Chuỗi gọn của bản chưa kèm khung tăng ca thì giữ khung tăng ca của máy này. Trả về null
/// nếu chuỗi dán vào không hợp lệ.
AppSettings? decodeSettings(String text, {required AppSettings current}) {
  try {
    final trimmed = text.trim();
    final AppSettings incoming;
    var hasBrackets = true;
    if (trimmed.startsWith(configSharePrefix.trim())) {
      final body = jsonDecode(trimmed.substring(configSharePrefix.trim().length).trim()) as Map<String, dynamic>;
      incoming = _decodeCompact(body);
      hasBrackets = body['o'] != null;
    } else {
      incoming = AppSettings.fromJson(jsonDecode(trimmed) as Map<String, dynamic>);
    }
    return current.copyWith(
      overtimeBrackets: hasBrackets ? incoming.overtimeBrackets : null,
      // Phần lương dán vào thay cho mọi kỳ; số riêng theo từng kỳ của máy này không còn dùng.
      payVersions: const [],
      workerKind: incoming.workerKind,
      baseSalary: incoming.baseSalary,
      dailyWage: incoming.dailyWage,
      payPeriod: incoming.payPeriod,
      workStart: incoming.workStart,
      workEnd: incoming.workEnd,
      wageTable: incoming.wageTable,
      lateRule: incoming.lateRule,
      incomeItems: incoming.incomeItems,
    );
  } catch (_) {
    return null;
  }
}

AppSettings _decodeCompact(Map<String, dynamic> d) {
  double n(Object? v) => (v as num).toDouble();
  final p = d['p'] as List;
  final h = d['h'] as List;
  final r = d['r'] as List;
  final l = d['l'] as List;
  final codes = {for (final e in _calcCodes.entries) e.value: e.key};
  return AppSettings(
    workerKind: d['k'] == 'd' ? WorkerKind.daily : WorkerKind.worker,
    baseSalary: n(d['b']),
    dailyWage: n(d['dw']),
    payPeriod: PayPeriodConfig(
      type: p[0] == 's' ? PayPeriodType.semiMonthly : PayPeriodType.monthly,
      monthlyStartDay: p[1] as int,
      semiFirstStart: p[2] as int,
      semiFirstEnd: p[3] as int,
    ),
    workStart: Clock.parse(h[0] as String),
    workEnd: Clock.parse(h[1] as String),
    wageTable: WageTable(
      rates: {
        for (var i = 0; i < _types.length; i++)
          _types[i]: WageRate(normalPerHour: n((r[i] as List)[0]), overtimePerHour: n((r[i] as List)[1])),
      },
    ),
    lateRule: LateRule(
      unit: l[0] == 'm' ? LateUnit.minutes : LateUnit.money,
      amount: n(l[1]),
      after: Clock.parse(l[2] as String),
    ),
    overtimeBrackets: [
      for (final raw in (d['o'] as List?) ?? const [])
        OvertimeBracket(
          from: Clock.parse((raw as List)[0] as String),
          to: Clock.parse(raw[1] as String),
          breakMinutes: raw[2] as int,
        ),
    ],
    incomeItems: [
      for (final raw in d['i'] as List)
        () {
          final e = raw as List;
          final after = e[5] as String;
          return IncomeItem(
            id: e[0] as String,
            name: e[1] as String,
            type: e[2] == 1 ? IncomeItemType.income : IncomeItemType.deduction,
            calcMethod: codes[e[3]]!,
            amount: n(e[4]),
            activeAfter: after.isEmpty ? null : Clock.parse(after),
            inBasis: e.length > 6 && e[6] == 1,
          );
        }(),
    ],
  );
}
