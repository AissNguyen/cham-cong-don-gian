/// Model dữ liệu thuần Dart (không phụ thuộc Flutter) cho app Chấm Công Đơn Giản.
library;

/// Giờ:phút trong ngày, không gắn ngày cụ thể.
class Clock implements Comparable<Clock> {
  const Clock(this.hour, this.minute);

  factory Clock.fromMinutes(int totalMinutes) {
    final m = totalMinutes % (24 * 60);
    return Clock(m ~/ 60, m % 60);
  }

  factory Clock.parse(String text) {
    final parts = text.split(':');
    return Clock(int.parse(parts[0]), int.parse(parts[1]));
  }

  final int hour;
  final int minute;

  int get totalMinutes => hour * 60 + minute;

  String get formatted => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  @override
  int compareTo(Clock other) => totalMinutes.compareTo(other.totalMinutes);

  bool operator <(Clock other) => totalMinutes < other.totalMinutes;
  bool operator <=(Clock other) => totalMinutes <= other.totalMinutes;
  bool operator >(Clock other) => totalMinutes > other.totalMinutes;
  bool operator >=(Clock other) => totalMinutes >= other.totalMinutes;

  @override
  bool operator ==(Object other) => other is Clock && other.totalMinutes == totalMinutes;

  @override
  int get hashCode => totalMinutes;

  Map<String, dynamic> toJson() => {'h': hour, 'm': minute};

  factory Clock.fromJson(Map<String, dynamic> json) => Clock(json['h'] as int, json['m'] as int);

  @override
  String toString() => formatted;
}

enum DayType { weekday, saturday, sunday, holiday }

extension DayTypeLabel on DayType {
  String get label => switch (this) {
    DayType.weekday => 'T2–T6',
    DayType.saturday => 'T7',
    DayType.sunday => 'CN',
    DayType.holiday => 'Ngày lễ',
  };
}

/// Lương một giờ (đ/giờ), nhập trực tiếp không qua hệ số nhân.
class WageRate {
  const WageRate({this.normalPerHour = 0, this.overtimePerHour = 0});

  final double normalPerHour;
  final double overtimePerHour;

  WageRate copyWith({double? normalPerHour, double? overtimePerHour}) => WageRate(
    normalPerHour: normalPerHour ?? this.normalPerHour,
    overtimePerHour: overtimePerHour ?? this.overtimePerHour,
  );

  Map<String, dynamic> toJson() => {'normal': normalPerHour, 'overtime': overtimePerHour};

  factory WageRate.fromJson(Map<String, dynamic> json) => WageRate(
    normalPerHour: (json['normal'] as num?)?.toDouble() ?? 0,
    overtimePerHour: (json['overtime'] as num?)?.toDouble() ?? 0,
  );
}

/// Bảng lương/giờ: 4 loại ngày x (giờ thường, giờ tăng ca) = 8 ô.
class WageTable {
  WageTable({Map<DayType, WageRate>? rates})
    : rates = rates ?? {for (final t in DayType.values) t: const WageRate()};

  final Map<DayType, WageRate> rates;

  WageRate of(DayType type) => rates[type] ?? const WageRate();

  Map<String, dynamic> toJson() => rates.map((k, v) => MapEntry(k.name, v.toJson()));

  factory WageTable.fromJson(Map<String, dynamic> json) => WageTable(
    rates: {
      for (final t in DayType.values)
        t: json[t.name] != null ? WageRate.fromJson(json[t.name] as Map<String, dynamic>) : const WageRate(),
    },
  );
}

/// Cộng/trừ phút theo khung giờ vào (ví dụ vào 07:00-08:59 trừ 15 phút giải lao).
class BreakRule {
  const BreakRule({required this.from, required this.to, required this.deltaMinutes});

  final Clock from;
  final Clock to;

  /// Âm là trừ, dương là cộng.
  final int deltaMinutes;

  bool matches(Clock checkIn) => checkIn >= from && checkIn <= to;

  Map<String, dynamic> toJson() => {'from': from.toJson(), 'to': to.toJson(), 'delta': deltaMinutes};

  factory BreakRule.fromJson(Map<String, dynamic> json) => BreakRule(
    from: Clock.fromJson(json['from'] as Map<String, dynamic>),
    to: Clock.fromJson(json['to'] as Map<String, dynamic>),
    deltaMinutes: json['delta'] as int,
  );
}

enum LateUnit { minutes, money }

/// Đi muộn: vào sau giờ này thì bị trừ (đơn vị phút hoặc tiền).
class LateRule {
  const LateRule({required this.after, this.unit = LateUnit.minutes, this.amount = 30});

  final Clock after;
  final LateUnit unit;
  final double amount;

  LateRule copyWith({Clock? after, LateUnit? unit, double? amount}) =>
      LateRule(after: after ?? this.after, unit: unit ?? this.unit, amount: amount ?? this.amount);

  Map<String, dynamic> toJson() => {'after': after.toJson(), 'unit': unit.name, 'amount': amount};

  factory LateRule.fromJson(Map<String, dynamic> json) => LateRule(
    after: Clock.fromJson(json['after'] as Map<String, dynamic>),
    unit: LateUnit.values.byName(json['unit'] as String),
    amount: (json['amount'] as num).toDouble(),
  );
}

/// Khung giờ tăng ca: phần giờ nằm trong khung, trừ số phút nghỉ của khung.
class OvertimeBracket {
  const OvertimeBracket({required this.from, required this.to, this.breakMinutes = 0});

  final Clock from;
  final Clock to;
  final int breakMinutes;

  Map<String, dynamic> toJson() => {'from': from.toJson(), 'to': to.toJson(), 'break': breakMinutes};

  factory OvertimeBracket.fromJson(Map<String, dynamic> json) => OvertimeBracket(
    from: Clock.fromJson(json['from'] as Map<String, dynamic>),
    to: Clock.fromJson(json['to'] as Map<String, dynamic>),
    breakMinutes: json['break'] as int,
  );
}

/// Một ngày lễ, có tên để dễ nhận biết (ví dụ "Quốc khánh").
class Holiday {
  const Holiday({required this.date, required this.name});

  final DateTime date;
  final String name;

  Map<String, dynamic> toJson() => {'date': date.toIso8601String(), 'name': name};

  factory Holiday.fromJson(Map<String, dynamic> json) =>
      Holiday(date: DateTime.parse(json['date'] as String), name: json['name'] as String? ?? '');
}

/// Một khung giờ kiểm tra GPS (ví dụ khung đúng giờ 6:50-7:00, khung dự phòng cho người đi muộn 8:00-8:10).
class TimeWindow {
  const TimeWindow({required this.from, required this.to});

  final Clock from;
  final Clock to;

  Map<String, dynamic> toJson() => {'from': from.toJson(), 'to': to.toJson()};

  factory TimeWindow.fromJson(Map<String, dynamic> json) => TimeWindow(
    from: Clock.fromJson(json['from'] as Map<String, dynamic>),
    to: Clock.fromJson(json['to'] as Map<String, dynamic>),
  );
}

/// Cài đặt chấm công tự động bằng GPS. Khung giờ chấm vào và chấm ra tách riêng: trong khung
/// chấm vào mà hôm đó chưa có giờ vào thì mới tự chấm vào; khung chấm ra chỉ tự chấm khi hôm đó
/// đã có chấm vào rồi (chưa vào thì chấm ra không tính, tránh chấm nhầm ngày không đi làm).
class GpsConfig {
  GpsConfig({
    this.enabled = false,
    this.latitude,
    this.longitude,
    this.radiusMeters = 30,
    List<TimeWindow>? checkInWindows,
    List<TimeWindow>? checkOutWindows,
    this.frequencyMinutes = 2,
    this.soundEnabled = true,
  }) : checkInWindows = checkInWindows ?? [const TimeWindow(from: Clock(6, 50), to: Clock(7, 0))],
       checkOutWindows = checkOutWindows ?? [const TimeWindow(from: Clock(16, 0), to: Clock(16, 15))];

  final bool enabled;
  final double? latitude;
  final double? longitude;
  final double radiusMeters;
  final List<TimeWindow> checkInWindows;
  final List<TimeWindow> checkOutWindows;
  final int frequencyMinutes;

  /// Có kêu chuông/rung khi máy tự chấm công hay không (chỉ áp dụng cho GPS tự động).
  final bool soundEnabled;

  GpsConfig copyWith({
    bool? enabled,
    double? latitude,
    double? longitude,
    double? radiusMeters,
    List<TimeWindow>? checkInWindows,
    List<TimeWindow>? checkOutWindows,
    int? frequencyMinutes,
    bool? soundEnabled,
  }) => GpsConfig(
    enabled: enabled ?? this.enabled,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    radiusMeters: radiusMeters ?? this.radiusMeters,
    checkInWindows: checkInWindows ?? this.checkInWindows,
    checkOutWindows: checkOutWindows ?? this.checkOutWindows,
    frequencyMinutes: frequencyMinutes ?? this.frequencyMinutes,
    soundEnabled: soundEnabled ?? this.soundEnabled,
  );

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'lat': latitude,
    'lng': longitude,
    'radius': radiusMeters,
    'checkInWindows': checkInWindows.map((w) => w.toJson()).toList(),
    'checkOutWindows': checkOutWindows.map((w) => w.toJson()).toList(),
    'freq': frequencyMinutes,
    'sound': soundEnabled,
  };

  factory GpsConfig.fromJson(Map<String, dynamic> json) => GpsConfig(
    enabled: json['enabled'] as bool? ?? false,
    latitude: (json['lat'] as num?)?.toDouble(),
    longitude: (json['lng'] as num?)?.toDouble(),
    radiusMeters: (json['radius'] as num?)?.toDouble() ?? 30,
    checkInWindows: json['checkInWindows'] != null
        ? (json['checkInWindows'] as List).map((w) => TimeWindow.fromJson(w as Map<String, dynamic>)).toList()
        : [const TimeWindow(from: Clock(6, 50), to: Clock(7, 0))],
    soundEnabled: json['sound'] as bool? ?? true,
    checkOutWindows: json['checkOutWindows'] != null
        ? (json['checkOutWindows'] as List).map((w) => TimeWindow.fromJson(w as Map<String, dynamic>)).toList()
        : [const TimeWindow(from: Clock(16, 0), to: Clock(16, 15))],
    frequencyMinutes: json['freq'] as int? ?? 2,
  );
}

enum PayPeriodType { monthly, semiMonthly }

/// Kỳ lương: theo tháng (chọn ngày bắt đầu) hoặc 2 kỳ mỗi tháng (1-15, 16-cuối tháng).
class PayPeriodConfig {
  const PayPeriodConfig({this.type = PayPeriodType.monthly, this.monthlyStartDay = 1});

  final PayPeriodType type;
  final int monthlyStartDay;

  PayPeriodConfig copyWith({PayPeriodType? type, int? monthlyStartDay}) =>
      PayPeriodConfig(type: type ?? this.type, monthlyStartDay: monthlyStartDay ?? this.monthlyStartDay);

  Map<String, dynamic> toJson() => {'type': type.name, 'startDay': monthlyStartDay};

  factory PayPeriodConfig.fromJson(Map<String, dynamic> json) => PayPeriodConfig(
    type: PayPeriodType.values.byName(json['type'] as String? ?? 'monthly'),
    monthlyStartDay: json['startDay'] as int? ?? 1,
  );
}

enum IncomeItemType { income, deduction }

enum IncomeCalcMethod { fixed, perWorkDay, manual }

/// Khoản thu nhập/khấu trừ tự tạo (phụ cấp, thưởng, tạm ứng...).
class IncomeItem {
  const IncomeItem({
    required this.id,
    required this.name,
    this.type = IncomeItemType.income,
    this.calcMethod = IncomeCalcMethod.fixed,
    this.amount = 0,
  });

  final String id;
  final String name;
  final IncomeItemType type;
  final IncomeCalcMethod calcMethod;
  final double amount;

  IncomeItem copyWith({
    String? name,
    IncomeItemType? type,
    IncomeCalcMethod? calcMethod,
    double? amount,
  }) => IncomeItem(
    id: id,
    name: name ?? this.name,
    type: type ?? this.type,
    calcMethod: calcMethod ?? this.calcMethod,
    amount: amount ?? this.amount,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.name,
    'calc': calcMethod.name,
    'amount': amount,
  };

  factory IncomeItem.fromJson(Map<String, dynamic> json) => IncomeItem(
    id: json['id'] as String,
    name: json['name'] as String,
    type: IncomeItemType.values.byName(json['type'] as String),
    calcMethod: IncomeCalcMethod.values.byName(json['calc'] as String),
    amount: (json['amount'] as num).toDouble(),
  );
}

/// Toàn bộ cài đặt của app.
class AppSettings {
  AppSettings({
    this.workStart = const Clock(7, 0),
    this.workEnd = const Clock(16, 0),
    WageTable? wageTable,
    List<BreakRule>? breakRules,
    LateRule? lateRule,
    List<OvertimeBracket>? overtimeBrackets,
    GpsConfig? gps,
    this.payPeriod = const PayPeriodConfig(),
    List<IncomeItem>? incomeItems,
    List<Holiday>? holidays,
  }) : wageTable = wageTable ?? WageTable(),
       breakRules = breakRules ?? [],
       lateRule = lateRule ?? const LateRule(after: Clock(7, 0)),
       overtimeBrackets = overtimeBrackets ?? [],
       gps = gps ?? GpsConfig(),
       incomeItems = incomeItems ?? [],
       holidays = holidays ?? [];

  final Clock workStart;
  final Clock workEnd;
  final WageTable wageTable;
  final List<BreakRule> breakRules;
  final LateRule lateRule;
  final List<OvertimeBracket> overtimeBrackets;
  final GpsConfig gps;
  final PayPeriodConfig payPeriod;
  final List<IncomeItem> incomeItems;
  final List<Holiday> holidays;

  AppSettings copyWith({
    Clock? workStart,
    Clock? workEnd,
    WageTable? wageTable,
    List<BreakRule>? breakRules,
    LateRule? lateRule,
    List<OvertimeBracket>? overtimeBrackets,
    GpsConfig? gps,
    PayPeriodConfig? payPeriod,
    List<IncomeItem>? incomeItems,
    List<Holiday>? holidays,
  }) => AppSettings(
    workStart: workStart ?? this.workStart,
    workEnd: workEnd ?? this.workEnd,
    wageTable: wageTable ?? this.wageTable,
    breakRules: breakRules ?? this.breakRules,
    lateRule: lateRule ?? this.lateRule,
    overtimeBrackets: overtimeBrackets ?? this.overtimeBrackets,
    gps: gps ?? this.gps,
    payPeriod: payPeriod ?? this.payPeriod,
    incomeItems: incomeItems ?? this.incomeItems,
    holidays: holidays ?? this.holidays,
  );

  Map<String, dynamic> toJson() => {
    'workStart': workStart.toJson(),
    'workEnd': workEnd.toJson(),
    'wageTable': wageTable.toJson(),
    'breakRules': breakRules.map((e) => e.toJson()).toList(),
    'lateRule': lateRule.toJson(),
    'overtimeBrackets': overtimeBrackets.map((e) => e.toJson()).toList(),
    'gps': gps.toJson(),
    'payPeriod': payPeriod.toJson(),
    'incomeItems': incomeItems.map((e) => e.toJson()).toList(),
    'holidays': holidays.map((h) => h.toJson()).toList(),
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    workStart: Clock.fromJson(json['workStart'] as Map<String, dynamic>),
    workEnd: Clock.fromJson(json['workEnd'] as Map<String, dynamic>),
    wageTable: WageTable.fromJson(json['wageTable'] as Map<String, dynamic>),
    breakRules: (json['breakRules'] as List).map((e) => BreakRule.fromJson(e as Map<String, dynamic>)).toList(),
    lateRule: LateRule.fromJson(json['lateRule'] as Map<String, dynamic>),
    overtimeBrackets: (json['overtimeBrackets'] as List)
        .map((e) => OvertimeBracket.fromJson(e as Map<String, dynamic>))
        .toList(),
    gps: GpsConfig.fromJson(json['gps'] as Map<String, dynamic>),
    payPeriod: PayPeriodConfig.fromJson(json['payPeriod'] as Map<String, dynamic>),
    incomeItems: (json['incomeItems'] as List).map((e) => IncomeItem.fromJson(e as Map<String, dynamic>)).toList(),
    // Tương thích dữ liệu cũ: hồi trước "holidays" chỉ là danh sách chuỗi ngày, chưa có tên.
    holidays: (json['holidays'] as List)
        .map((e) => e is String ? Holiday(date: DateTime.parse(e), name: '') : Holiday.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

/// Dữ liệu chấm công của một ngày.
class DayRecord {
  const DayRecord({
    required this.date,
    this.checkIn,
    this.checkOut,
    this.isDayOff = false,
    this.isLate = false,
    this.note,
    this.tags = const [],
  });

  /// Ngày (đã bỏ giờ phút), dùng làm khóa.
  final DateTime date;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final bool isDayOff;
  final bool isLate;
  final String? note;
  final List<String> tags;

  bool get hasAttendance => checkIn != null;
  bool get isOpenShift => checkIn != null && checkOut == null;

  DayRecord copyWith({
    DateTime? checkIn,
    bool clearCheckIn = false,
    DateTime? checkOut,
    bool clearCheckOut = false,
    bool? isDayOff,
    bool? isLate,
    String? note,
    List<String>? tags,
  }) => DayRecord(
    date: date,
    checkIn: clearCheckIn ? null : (checkIn ?? this.checkIn),
    checkOut: clearCheckOut ? null : (checkOut ?? this.checkOut),
    isDayOff: isDayOff ?? this.isDayOff,
    isLate: isLate ?? this.isLate,
    note: note ?? this.note,
    tags: tags ?? this.tags,
  );

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'checkIn': checkIn?.toIso8601String(),
    'checkOut': checkOut?.toIso8601String(),
    'dayOff': isDayOff,
    'late': isLate,
    'note': note,
    'tags': tags,
  };

  factory DayRecord.fromJson(Map<String, dynamic> json) => DayRecord(
    date: DateTime.parse(json['date'] as String),
    checkIn: json['checkIn'] != null ? DateTime.parse(json['checkIn'] as String) : null,
    checkOut: json['checkOut'] != null ? DateTime.parse(json['checkOut'] as String) : null,
    isDayOff: json['dayOff'] as bool? ?? false,
    isLate: json['late'] as bool? ?? false,
    note: json['note'] as String?,
    tags: (json['tags'] as List?)?.map((e) => e as String).toList() ?? const [],
  );
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
