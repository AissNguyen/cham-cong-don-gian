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

/// Cộng/trừ phút theo khung giờ vào-ra cố định: khớp khi giờ vào nằm trong [checkInFrom,
/// checkInTo] VÀ giờ ra nằm trong [checkOutFrom, checkOutTo] (mỗi khoảng có thể chỉ là 1 điểm,
/// nhập từ = đến). Ví dụ vào trong khoảng 7:00-8:00, ra trong khoảng 11:00-12:00, trừ 15 phút.
class FixedBreakRule {
  const FixedBreakRule({
    required this.checkInFrom,
    required this.checkInTo,
    required this.checkOutFrom,
    required this.checkOutTo,
    required this.deltaMinutes,
  });

  final Clock checkInFrom;
  final Clock checkInTo;
  final Clock checkOutFrom;
  final Clock checkOutTo;

  /// Âm là trừ, dương là cộng.
  final int deltaMinutes;

  /// Khớp khi giờ vào/ra nằm trong khoảng đã cài. Nếu [checkOutTo] trùng đúng giờ ra chuẩn
  /// ([normalEnd], ví dụ 16:00) thì giờ ra muộn hơn (do tăng ca) vẫn coi là khớp, không bị đẩy
  /// xuống khung dự phòng — [checkOutTo] khi đó có nghĩa là "từ giờ này trở lên".
  bool matches(Clock checkIn, Clock checkOut, {Clock? normalEnd}) {
    final inCheckIn = checkIn >= checkInFrom && checkIn <= checkInTo;
    var inCheckOut = checkOut >= checkOutFrom && checkOut <= checkOutTo;
    if (!inCheckOut && normalEnd != null && checkOutTo == normalEnd && checkOut > checkOutTo) {
      inCheckOut = true;
    }
    return inCheckIn && inCheckOut;
  }

  Map<String, dynamic> toJson() => {
    'checkInFrom': checkInFrom.toJson(),
    'checkInTo': checkInTo.toJson(),
    'checkOutFrom': checkOutFrom.toJson(),
    'checkOutTo': checkOutTo.toJson(),
    'delta': deltaMinutes,
  };

  factory FixedBreakRule.fromJson(Map<String, dynamic> json) => FixedBreakRule(
    checkInFrom: Clock.fromJson(json['checkInFrom'] as Map<String, dynamic>),
    checkInTo: Clock.fromJson(json['checkInTo'] as Map<String, dynamic>),
    checkOutFrom: Clock.fromJson(json['checkOutFrom'] as Map<String, dynamic>),
    checkOutTo: Clock.fromJson(json['checkOutTo'] as Map<String, dynamic>),
    deltaMinutes: json['delta'] as int,
  );
}

/// Một đoạn trong "khung nhiều mục": từ giờ nào tới giờ nào thì nghỉ bao nhiêu phút. Nhiều đoạn
/// nối tiếp nhau phủ kín cả ngày làm, dùng làm dự phòng khi không khung cố định nào khớp.
class BreakSegment {
  const BreakSegment({required this.from, required this.to, required this.breakMinutes});

  final Clock from;
  final Clock to;
  final int breakMinutes;

  Map<String, dynamic> toJson() => {'from': from.toJson(), 'to': to.toJson(), 'break': breakMinutes};

  factory BreakSegment.fromJson(Map<String, dynamic> json) => BreakSegment(
    from: Clock.fromJson(json['from'] as Map<String, dynamic>),
    to: Clock.fromJson(json['to'] as Map<String, dynamic>),
    breakMinutes: json['break'] as int,
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

/// Ngày lễ tự thêm có lặp lại hằng năm hay không, và lặp theo lịch nào.
enum HolidayRecurrence {
  /// Chỉ đúng ngày đã chọn, không tự sinh thêm năm sau.
  once,

  /// Lặp mỗi năm, giữ nguyên ngày/tháng dương lịch (ví dụ 15/6 dương lịch mọi năm).
  solarYearly,

  /// Lặp mỗi năm theo ngày/tháng âm lịch — mỗi năm tính lại ra ngày dương khác nhau.
  lunarYearly,
}

/// Một ngày lễ, có tên để dễ nhận biết (ví dụ "Quốc khánh").
class Holiday {
  const Holiday({required this.date, required this.name, this.recurrence = HolidayRecurrence.once});

  final DateTime date;
  final String name;

  /// Chỉ có ý nghĩa với ngày lễ tự thêm (các ngày lễ gợi ý sẵn luôn là [HolidayRecurrence.once]
  /// vì đã tự sinh đúng ngày của từng năm rồi) — dùng để [backfillMissingYears] tự sinh thêm ngày
  /// cho các năm sau.
  final HolidayRecurrence recurrence;

  Map<String, dynamic> toJson() => {'date': date.toIso8601String(), 'name': name, 'recurrence': recurrence.name};

  factory Holiday.fromJson(Map<String, dynamic> json) => Holiday(
    date: DateTime.parse(json['date'] as String),
    name: json['name'] as String? ?? '',
    recurrence: json['recurrence'] != null ? HolidayRecurrence.values.byName(json['recurrence'] as String) : HolidayRecurrence.once,
  );
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

/// Một địa điểm khác ngoài điểm chấm công chính, chỉ dùng khi đã chấm vào và đang chờ chấm ra.
/// Ví dụ nhà trọ sát công ty ([checkOut] = true: về tới đây là chấm ra ngay, dù còn trong vòng
/// "rời đi hẳn") hoặc xưởng ở xa máy chấm công ([checkOut] = false: ở đây thì không chấm ra, dù
/// đã xa điểm chính hơn vòng "rời đi hẳn").
class GpsPlace {
  const GpsPlace({
    this.name = '',
    required this.latitude,
    required this.longitude,
    this.radiusMeters = 50,
    this.checkOut = true,
  });

  final String name;
  final double latitude;
  final double longitude;
  final double radiusMeters;

  /// true: ở đây là chấm về. false: ở đây thì không chấm về.
  final bool checkOut;

  GpsPlace copyWith({String? name, double? latitude, double? longitude, double? radiusMeters, bool? checkOut}) => GpsPlace(
    name: name ?? this.name,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    radiusMeters: radiusMeters ?? this.radiusMeters,
    checkOut: checkOut ?? this.checkOut,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'lat': latitude,
    'lng': longitude,
    'radius': radiusMeters,
    'checkOut': checkOut,
  };

  factory GpsPlace.fromJson(Map<String, dynamic> json) => GpsPlace(
    name: json['name'] as String? ?? '',
    latitude: (json['lat'] as num).toDouble(),
    longitude: (json['lng'] as num).toDouble(),
    radiusMeters: (json['radius'] as num?)?.toDouble() ?? 50,
    checkOut: json['checkOut'] as bool? ?? true,
  );
}

/// Cài đặt chấm công tự động bằng GPS. Một danh sách khung giờ bật GPS duy nhất (không tách
/// riêng vào/ra): lần chấm được xác nhận đầu tiên trong ngày là chấm vào, lần tiếp theo là chấm
/// ra — máy tự phân biệt, không cần khai báo khung nào dùng để làm gì.
class GpsConfig {
  GpsConfig({
    this.enabled = false,
    this.latitude,
    this.longitude,
    this.radiusMeters = 30,
    this.departRadiusMeters = 200,
    List<TimeWindow>? activeWindows,
    this.frequencyMinutes = 2,
    this.soundEnabled = true,
    this.extraPlaces = const [],
  }) : activeWindows =
           activeWindows ?? [const TimeWindow(from: Clock(6, 50), to: Clock(7, 0)), const TimeWindow(from: Clock(16, 0), to: Clock(16, 15))];

  final bool enabled;
  final double? latitude;
  final double? longitude;

  /// Trong khoảng này (mét) coi là đang ở đúng chỗ chấm công.
  final double radiusMeters;

  /// Xa hơn khoảng này (mét) mới coi là chắc chắn đã rời đi hẳn — dùng để xác nhận giờ chấm ra.
  final double departRadiusMeters;

  final List<TimeWindow> activeWindows;
  final int frequencyMinutes;

  /// Có kêu chuông/rung khi máy tự chấm công hay không (chỉ áp dụng cho GPS tự động).
  final bool soundEnabled;

  /// Các địa điểm khác (nhà trọ, xưởng xa...), chỉ ảnh hưởng tới việc chấm ra.
  final List<GpsPlace> extraPlaces;

  GpsConfig copyWith({
    bool? enabled,
    double? latitude,
    double? longitude,
    double? radiusMeters,
    double? departRadiusMeters,
    List<TimeWindow>? activeWindows,
    int? frequencyMinutes,
    bool? soundEnabled,
    List<GpsPlace>? extraPlaces,
  }) => GpsConfig(
    enabled: enabled ?? this.enabled,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    radiusMeters: radiusMeters ?? this.radiusMeters,
    departRadiusMeters: departRadiusMeters ?? this.departRadiusMeters,
    activeWindows: activeWindows ?? this.activeWindows,
    frequencyMinutes: frequencyMinutes ?? this.frequencyMinutes,
    soundEnabled: soundEnabled ?? this.soundEnabled,
    extraPlaces: extraPlaces ?? this.extraPlaces,
  );

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'lat': latitude,
    'lng': longitude,
    'radius': radiusMeters,
    'departRadius': departRadiusMeters,
    'activeWindows': activeWindows.map((w) => w.toJson()).toList(),
    'freq': frequencyMinutes,
    'sound': soundEnabled,
    'extraPlaces': extraPlaces.map((p) => p.toJson()).toList(),
  };

  factory GpsConfig.fromJson(Map<String, dynamic> json) {
    List<TimeWindow>? windows;
    if (json['activeWindows'] != null) {
      windows = (json['activeWindows'] as List).map((w) => TimeWindow.fromJson(w as Map<String, dynamic>)).toList();
    } else if (json['checkInWindows'] != null || json['checkOutWindows'] != null) {
      // Tương thích dữ liệu cũ: gộp 2 danh sách khung vào/ra cũ thành 1 danh sách chung.
      windows = [
        ...?(json['checkInWindows'] as List?)?.map((w) => TimeWindow.fromJson(w as Map<String, dynamic>)),
        ...?(json['checkOutWindows'] as List?)?.map((w) => TimeWindow.fromJson(w as Map<String, dynamic>)),
      ];
    }
    return GpsConfig(
      enabled: json['enabled'] as bool? ?? false,
      latitude: (json['lat'] as num?)?.toDouble(),
      longitude: (json['lng'] as num?)?.toDouble(),
      radiusMeters: (json['radius'] as num?)?.toDouble() ?? 30,
      departRadiusMeters: (json['departRadius'] as num?)?.toDouble() ?? 200,
      activeWindows: windows,
      soundEnabled: json['sound'] as bool? ?? true,
      frequencyMinutes: json['freq'] as int? ?? 2,
      extraPlaces: [
        ...?(json['extraPlaces'] as List?)?.map((p) => GpsPlace.fromJson(p as Map<String, dynamic>)),
      ],
    );
  }
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

/// [percentOfBaseSalary]: số tiền = [AppSettings.baseSalary] * amount/100 (amount là % nhập vào,
/// ví dụ amount=10 nghĩa là 10%).
enum IncomeCalcMethod { fixed, perWorkDay, percentOfBaseSalary }

/// Khoản thu nhập/khấu trừ tự tạo (phụ cấp, thưởng, bảo hiểm...).
class IncomeItem {
  const IncomeItem({
    required this.id,
    required this.name,
    this.type = IncomeItemType.income,
    this.calcMethod = IncomeCalcMethod.fixed,
    this.amount = 0,
    this.activeAfter,
  });

  final String id;
  final String name;
  final IncomeItemType type;
  final IncomeCalcMethod calcMethod;
  final double amount;

  /// Nếu đặt, khoản này chỉ bắt đầu tính (trong số tiền chạy sống của hôm nay) từ giờ này trở đi
  /// trong ngày — ví dụ tiền cơm trưa chỉ tính sau 13:00. Không ảnh hưởng tới tổng tiền chính thức
  /// của cả kỳ, chỉ ảnh hưởng cách số nhảy trong ngày.
  final Clock? activeAfter;

  IncomeItem copyWith({
    String? name,
    IncomeItemType? type,
    IncomeCalcMethod? calcMethod,
    double? amount,
    Clock? activeAfter,
    bool clearActiveAfter = false,
  }) => IncomeItem(
    id: id,
    name: name ?? this.name,
    type: type ?? this.type,
    calcMethod: calcMethod ?? this.calcMethod,
    amount: amount ?? this.amount,
    activeAfter: clearActiveAfter ? null : (activeAfter ?? this.activeAfter),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.name,
    'calc': calcMethod.name,
    'amount': amount,
    'activeAfter': activeAfter?.toJson(),
  };

  factory IncomeItem.fromJson(Map<String, dynamic> json) => IncomeItem(
    id: json['id'] as String,
    name: json['name'] as String,
    type: IncomeItemType.values.byName(json['type'] as String),
    // Tương thích dữ liệu cũ: "manual" (nhập tay mỗi kỳ) đã bỏ, các khoản cũ kiểu này coi như "Cố
    // định" với số 0 — không còn chỗ nhập số cho khoản manual cũ nữa.
    calcMethod: json['calc'] == 'manual'
        ? IncomeCalcMethod.fixed
        : IncomeCalcMethod.values.byName(json['calc'] as String),
    amount: (json['amount'] as num).toDouble(),
    activeAfter: json['activeAfter'] != null ? Clock.fromJson(json['activeAfter'] as Map<String, dynamic>) : null,
  );
}

/// Toàn bộ cài đặt của app.
class AppSettings {
  AppSettings({
    this.workStart = const Clock(7, 0),
    this.workEnd = const Clock(16, 0),
    WageTable? wageTable,
    List<FixedBreakRule>? fixedBreakRules,
    List<BreakSegment>? breakSegments,
    LateRule? lateRule,
    List<OvertimeBracket>? overtimeBrackets,
    GpsConfig? gps,
    this.payPeriod = const PayPeriodConfig(),
    List<IncomeItem>? incomeItems,
    List<Holiday>? holidays,
    this.baseSalary = 0,
    this.includeItemsInEstimate = false,
  }) : wageTable = wageTable ?? WageTable(),
       fixedBreakRules = fixedBreakRules ?? [],
       breakSegments = breakSegments ?? [],
       lateRule = lateRule ?? const LateRule(after: Clock(7, 0)),
       overtimeBrackets = overtimeBrackets ?? [],
       gps = gps ?? GpsConfig(),
       incomeItems = incomeItems ?? [],
       holidays = holidays ?? [];

  final Clock workStart;
  final Clock workEnd;
  final WageTable wageTable;
  final List<FixedBreakRule> fixedBreakRules;
  final List<BreakSegment> breakSegments;
  final LateRule lateRule;
  final List<OvertimeBracket> overtimeBrackets;
  final GpsConfig gps;
  final PayPeriodConfig payPeriod;
  final List<IncomeItem> incomeItems;
  final List<Holiday> holidays;

  /// Lương cơ bản, dùng làm mốc cho khoản thu nhập/khấu trừ tính theo % (ví dụ bảo hiểm 10%).
  final double baseSalary;

  /// true thì các khoản thu nhập/khấu trừ tự tạo được cộng vào số tiền ước tính (tổng kỳ, hôm
  /// nay, số chạy sống) — false thì chỉ tính theo bảng lương/giờ như trước, khoản tự tạo chỉ để
  /// tham khảo, không cộng vào số ước tính.
  final bool includeItemsInEstimate;

  AppSettings copyWith({
    Clock? workStart,
    Clock? workEnd,
    WageTable? wageTable,
    List<FixedBreakRule>? fixedBreakRules,
    List<BreakSegment>? breakSegments,
    LateRule? lateRule,
    List<OvertimeBracket>? overtimeBrackets,
    GpsConfig? gps,
    PayPeriodConfig? payPeriod,
    List<IncomeItem>? incomeItems,
    List<Holiday>? holidays,
    double? baseSalary,
    bool? includeItemsInEstimate,
  }) => AppSettings(
    workStart: workStart ?? this.workStart,
    workEnd: workEnd ?? this.workEnd,
    wageTable: wageTable ?? this.wageTable,
    fixedBreakRules: fixedBreakRules ?? this.fixedBreakRules,
    breakSegments: breakSegments ?? this.breakSegments,
    lateRule: lateRule ?? this.lateRule,
    overtimeBrackets: overtimeBrackets ?? this.overtimeBrackets,
    gps: gps ?? this.gps,
    payPeriod: payPeriod ?? this.payPeriod,
    incomeItems: incomeItems ?? this.incomeItems,
    holidays: holidays ?? this.holidays,
    baseSalary: baseSalary ?? this.baseSalary,
    includeItemsInEstimate: includeItemsInEstimate ?? this.includeItemsInEstimate,
  );

  Map<String, dynamic> toJson() => {
    'workStart': workStart.toJson(),
    'workEnd': workEnd.toJson(),
    'wageTable': wageTable.toJson(),
    'fixedBreakRules': fixedBreakRules.map((e) => e.toJson()).toList(),
    'breakSegments': breakSegments.map((e) => e.toJson()).toList(),
    'lateRule': lateRule.toJson(),
    'overtimeBrackets': overtimeBrackets.map((e) => e.toJson()).toList(),
    'gps': gps.toJson(),
    'payPeriod': payPeriod.toJson(),
    'incomeItems': incomeItems.map((e) => e.toJson()).toList(),
    'holidays': holidays.map((h) => h.toJson()).toList(),
    'baseSalary': baseSalary,
    'includeItemsInEstimate': includeItemsInEstimate,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    workStart: Clock.fromJson(json['workStart'] as Map<String, dynamic>),
    workEnd: Clock.fromJson(json['workEnd'] as Map<String, dynamic>),
    wageTable: WageTable.fromJson(json['wageTable'] as Map<String, dynamic>),
    // Tương thích dữ liệu cũ: chưa có "fixedBreakRules"/"breakSegments" thì coi như rỗng.
    fixedBreakRules: (json['fixedBreakRules'] as List?)
            ?.map((e) => FixedBreakRule.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
    breakSegments: (json['breakSegments'] as List?)
            ?.map((e) => BreakSegment.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
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
    baseSalary: (json['baseSalary'] as num?)?.toDouble() ?? 0,
    includeItemsInEstimate: json['includeItemsInEstimate'] as bool? ?? false,
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
    this.gpsLastSeenNearby,
  });

  /// Ngày (đã bỏ giờ phút), dùng làm khóa.
  final DateTime date;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final bool isDayOff;
  final bool isLate;
  final String? note;
  final List<String> tags;

  /// Sau khi đã chấm vào, mốc giờ lần quét GPS gần nhất còn thấy trong khoảng chưa rời hẳn
  /// (≤ departRadiusMeters) — dùng làm giờ chấm ra khi cuối cùng phát hiện đã rời xa hẳn.
  final DateTime? gpsLastSeenNearby;

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
    DateTime? gpsLastSeenNearby,
    bool clearGpsLastSeenNearby = false,
  }) => DayRecord(
    date: date,
    checkIn: clearCheckIn ? null : (checkIn ?? this.checkIn),
    checkOut: clearCheckOut ? null : (checkOut ?? this.checkOut),
    isDayOff: isDayOff ?? this.isDayOff,
    isLate: isLate ?? this.isLate,
    note: note ?? this.note,
    tags: tags ?? this.tags,
    gpsLastSeenNearby: clearGpsLastSeenNearby ? null : (gpsLastSeenNearby ?? this.gpsLastSeenNearby),
  );

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'checkIn': checkIn?.toIso8601String(),
    'checkOut': checkOut?.toIso8601String(),
    'dayOff': isDayOff,
    'late': isLate,
    'note': note,
    'tags': tags,
    'gpsLastSeenNearby': gpsLastSeenNearby?.toIso8601String(),
  };

  factory DayRecord.fromJson(Map<String, dynamic> json) => DayRecord(
    date: DateTime.parse(json['date'] as String),
    checkIn: json['checkIn'] != null ? DateTime.parse(json['checkIn'] as String) : null,
    checkOut: json['checkOut'] != null ? DateTime.parse(json['checkOut'] as String) : null,
    isDayOff: json['dayOff'] as bool? ?? false,
    isLate: json['late'] as bool? ?? false,
    note: json['note'] as String?,
    tags: (json['tags'] as List?)?.map((e) => e as String).toList() ?? const [],
    gpsLastSeenNearby: json['gpsLastSeenNearby'] != null ? DateTime.parse(json['gpsLastSeenNearby'] as String) : null,
  );
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
