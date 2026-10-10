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

/// Khung cố định cộng/trừ phút theo giờ vào-ra của các bản cũ. Mục này đã bỏ khỏi Cài đặt và
/// không còn dùng để tính (giờ nghỉ trưa cố định 11:30–12:30 thay thế); chỉ giữ lại để đọc/ghi
/// dữ liệu và file sao lưu cũ không bị lỗi.
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

/// Một đoạn trong "khung nhiều mục" (dự phòng) của các bản cũ: từ giờ nào tới giờ nào thì nghỉ
/// bao nhiêu phút. Mục này đã bỏ khỏi Cài đặt và không còn dùng để tính; chỉ giữ lại để đọc/ghi
/// dữ liệu và file sao lưu cũ không bị lỗi.
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

/// Khung giờ GPS lặp lại mỗi giờ: trong khoảng [from]–[to], mỗi giờ bật GPS ở các mốc phút trong
/// [marks]. Ví dụ từ 06:50 tới 12:40 với mốc 50→05 và 25→35 thành 06:50–07:05, 07:25–07:35,
/// 07:50–08:05... Chỉ lấy những khung nằm trọn trong khoảng [from]–[to].
class GpsRepeatRule {
  const GpsRepeatRule({required this.from, required this.to, required this.marks});

  final Clock from;
  final Clock to;

  /// Mỗi mốc là `[phút bắt đầu, phút kết thúc]`; kết thúc nhỏ hơn bắt đầu nghĩa là sang giờ sau.
  final List<List<int>> marks;

  List<TimeWindow> get windows {
    final result = <TimeWindow>[];
    for (var h = from.hour; h <= to.hour; h++) {
      for (final m in marks) {
        final start = h * 60 + m[0];
        final length = (m[1] - m[0] + 60) % 60;
        final end = start + length;
        if (length == 0 || start < from.totalMinutes || end > to.totalMinutes || end >= 24 * 60) continue;
        result.add(TimeWindow(from: Clock.fromMinutes(start), to: Clock.fromMinutes(end)));
      }
    }
    result.sort((a, b) => a.from.compareTo(b.from));
    return result;
  }

  Map<String, dynamic> toJson() => {'from': from.toJson(), 'to': to.toJson(), 'marks': marks};

  factory GpsRepeatRule.fromJson(Map<String, dynamic> json) => GpsRepeatRule(
    from: Clock.fromJson(json['from'] as Map<String, dynamic>),
    to: Clock.fromJson(json['to'] as Map<String, dynamic>),
    marks: [
      for (final m in json['marks'] as List) [(m as List)[0] as int, m[1] as int],
    ],
  );
}

/// Khung giờ GPS cài sẵn: buổi sáng canh quanh mỗi mốc giờ tròn và mốc rưỡi, chiều tối canh 10 phút
/// đầu mỗi nửa giờ, thêm một khung lúc hết giờ nghỉ trưa.
const defaultGpsRules = [
  GpsRepeatRule(
    from: Clock(6, 50),
    to: Clock(12, 40),
    marks: [
      [50, 5],
      [25, 35],
    ],
  ),
  GpsRepeatRule(
    from: Clock(13, 30),
    to: Clock(23, 0),
    marks: [
      [0, 10],
      [30, 40],
    ],
  ),
];
const defaultGpsWindows = [TimeWindow(from: Clock(12, 50), to: Clock(13, 10))];

/// Phiên bản của bộ khung giờ GPS trong dữ liệu. Dữ liệu cũ hơn (chưa có khung lặp, hoặc của bản
/// thử đầu tiên) được đặt lại về các khung cài sẵn một lần.
const gpsWindowsVersion = 2;

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
  /// Không truyền [activeWindows] thì dùng các khung cài sẵn ([defaultGpsWindows] và
  /// [defaultGpsRules]); đã truyền khung riêng thì mặc định không có khung lặp nào.
  GpsConfig({
    this.enabled = false,
    this.latitude,
    this.longitude,
    this.radiusMeters = 30,
    this.departRadiusMeters = 200,
    List<TimeWindow>? activeWindows,
    List<GpsRepeatRule>? repeatRules,
    this.frequencyMinutes = 2,
    this.soundEnabled = true,
    this.extraPlaces = const [],
  }) : repeatRules = repeatRules ?? (activeWindows == null ? defaultGpsRules : const []),
       activeWindows = activeWindows ?? [...defaultGpsWindows];

  final bool enabled;
  final double? latitude;
  final double? longitude;

  /// Trong khoảng này (mét) coi là đang ở đúng chỗ chấm công.
  final double radiusMeters;

  /// Xa hơn khoảng này (mét) mới coi là chắc chắn đã rời đi hẳn — dùng để xác nhận giờ chấm ra.
  final double departRadiusMeters;

  /// Các khung giờ lẻ do người dùng tự đặt (và khung 12:50–13:10 cài sẵn).
  final List<TimeWindow> activeWindows;

  /// Các khung lặp lại mỗi giờ (cài sẵn hai cái, người dùng xóa được).
  final List<GpsRepeatRule> repeatRules;

  /// Toàn bộ khung giờ bật GPS trong ngày: khung lẻ cộng các khung sinh ra từ [repeatRules].
  List<TimeWindow> get allWindows => [
    ...activeWindows,
    for (final r in repeatRules) ...r.windows,
  ];

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
    List<GpsRepeatRule>? repeatRules,
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
    repeatRules: repeatRules ?? this.repeatRules,
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
    'rules': repeatRules.map((r) => r.toJson()).toList(),
    'v': gpsWindowsVersion,
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
    var rules = (json['rules'] as List?)?.map((r) => GpsRepeatRule.fromJson(r as Map<String, dynamic>)).toList();
    // Dữ liệu của bản cũ: bỏ hết các khung giờ đã đặt trước đây, chuyển sang các khung cài sẵn
    // (hai khung lặp và khung 12:50–13:10). Từ đó về sau người dùng sửa gì thì giữ nguyên.
    if ((json['v'] as int? ?? 1) < gpsWindowsVersion) {
      windows = null;
      rules = null;
    }
    return GpsConfig(
      enabled: json['enabled'] as bool? ?? false,
      latitude: (json['lat'] as num?)?.toDouble(),
      longitude: (json['lng'] as num?)?.toDouble(),
      radiusMeters: (json['radius'] as num?)?.toDouble() ?? 30,
      departRadiusMeters: (json['departRadius'] as num?)?.toDouble() ?? 200,
      activeWindows: windows,
      repeatRules: rules,
      soundEnabled: json['sound'] as bool? ?? true,
      frequencyMinutes: json['freq'] as int? ?? 2,
      extraPlaces: [
        ...?(json['extraPlaces'] as List?)?.map((p) => GpsPlace.fromJson(p as Map<String, dynamic>)),
      ],
    );
  }
}

enum PayPeriodType { monthly, semiMonthly }

/// Kỳ lương: theo tháng (chọn ngày bắt đầu) hoặc 2 kỳ mỗi tháng. Với 2 kỳ: kỳ 1 chạy từ ngày
/// [semiFirstStart] tới ngày [semiFirstEnd]; kỳ 2 chạy từ ngày kế tiếp tới trước ngày đầu kỳ 1
/// của tháng sau (mặc định 1–15 và 16–cuối tháng).
class PayPeriodConfig {
  const PayPeriodConfig({
    this.type = PayPeriodType.monthly,
    this.monthlyStartDay = 1,
    this.semiFirstStart = 1,
    this.semiFirstEnd = 15,
  });

  final PayPeriodType type;
  final int monthlyStartDay;
  final int semiFirstStart;
  final int semiFirstEnd;

  PayPeriodConfig copyWith({PayPeriodType? type, int? monthlyStartDay, int? semiFirstStart, int? semiFirstEnd}) =>
      PayPeriodConfig(
        type: type ?? this.type,
        monthlyStartDay: monthlyStartDay ?? this.monthlyStartDay,
        semiFirstStart: semiFirstStart ?? this.semiFirstStart,
        semiFirstEnd: semiFirstEnd ?? this.semiFirstEnd,
      );

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'startDay': monthlyStartDay,
    'semiStart': semiFirstStart,
    'semiEnd': semiFirstEnd,
  };

  factory PayPeriodConfig.fromJson(Map<String, dynamic> json) => PayPeriodConfig(
    type: PayPeriodType.values.byName(json['type'] as String? ?? 'monthly'),
    monthlyStartDay: json['startDay'] as int? ?? 1,
    semiFirstStart: json['semiStart'] as int? ?? 1,
    semiFirstEnd: json['semiEnd'] as int? ?? 15,
  );
}

/// Loại người dùng, quyết định cách tính phiếu lương.
enum WorkerKind {
  /// Công nhân: lương tháng ÷ công chuẩn × ngày công, có thưởng, bảo hiểm, công đoàn...
  worker,

  /// Công nhật: lương ngày ÷ 8 × số giờ làm.
  daily,
}

/// Mã của các khoản cài sẵn trong phiếu lương.
const payItemSalary = 'salary';
const payItemOvertime = 'overtime';
const payItemPerformance = 'performance';
const payItemAllowance = 'allowance';
const payItemInsurance = 'insurance';
const payItemLunch = 'lunch';
const payItemUnion = 'union';

enum IncomeItemType { income, deduction }

/// [percentOfBaseSalary]: số tiền = [AppSettings.baseSalary] * amount/100 (amount là % nhập vào,
/// ví dụ amount=10 nghĩa là 10%).
///
/// [salary]: dòng "Tiền lương", tính từ lương cơ bản (công nhân) hoặc lương ngày (công nhật).
/// [overtime]: dòng tiền tăng ca / làm chủ nhật, ngày lễ ("Thưởng vượt khoán"), tính theo bảng
/// lương/giờ. Hai cách này không dùng [IncomeItem.amount].
enum IncomeCalcMethod { fixed, perWorkDay, percentOfBaseSalary, salary, overtime }

/// Khoản thu nhập/khấu trừ tự tạo (phụ cấp, thưởng, bảo hiểm...).
class IncomeItem {
  const IncomeItem({
    required this.id,
    required this.name,
    this.type = IncomeItemType.income,
    this.calcMethod = IncomeCalcMethod.fixed,
    this.amount = 0,
    this.activeAfter,
    this.inBasis = false,
  });

  final String id;
  final String name;
  final IncomeItemType type;
  final IncomeCalcMethod calcMethod;
  final double amount;

  /// Mốc giờ trong ngày. Với khoản "× số ngày công" (ví dụ cơm trưa sau 12:30): chỉ đếm những
  /// ngày làm qua mốc giờ này.
  final Clock? activeAfter;

  /// true: là một mức theo tháng hiện ở mục "Căn cứ tính" của phiếu lương (ví dụ thưởng thành
  /// tích); dòng thu nhập tương ứng tự tính = mức này ÷ công chuẩn × ngày công.
  final bool inBasis;

  IncomeItem copyWith({
    String? name,
    IncomeItemType? type,
    IncomeCalcMethod? calcMethod,
    double? amount,
    Clock? activeAfter,
    bool clearActiveAfter = false,
    bool? inBasis,
  }) => IncomeItem(
    id: id,
    name: name ?? this.name,
    type: type ?? this.type,
    calcMethod: calcMethod ?? this.calcMethod,
    amount: amount ?? this.amount,
    activeAfter: clearActiveAfter ? null : (activeAfter ?? this.activeAfter),
    inBasis: inBasis ?? this.inBasis,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.name,
    'calc': calcMethod.name,
    'amount': amount,
    'activeAfter': activeAfter?.toJson(),
    'inBasis': inBasis,
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
    inBasis: json['inBasis'] as bool? ?? false,
  );
}

/// Các khoản cài sẵn trong phiếu lương của từng loại người dùng.
List<IncomeItem> defaultPayItems(WorkerKind kind) => [
  const IncomeItem(id: payItemSalary, name: 'Tiền lương', calcMethod: IncomeCalcMethod.salary),
  if (kind == WorkerKind.worker) ...[
    const IncomeItem(id: payItemPerformance, name: 'Thưởng thành tích', amount: 2000000, inBasis: true),
    const IncomeItem(id: payItemOvertime, name: 'Thưởng vượt khoán', calcMethod: IncomeCalcMethod.overtime),
    const IncomeItem(id: payItemAllowance, name: 'Các khoản trợ cấp'),
    const IncomeItem(
      id: payItemInsurance,
      name: 'Bảo hiểm',
      type: IncomeItemType.deduction,
      calcMethod: IncomeCalcMethod.percentOfBaseSalary,
      amount: 10.5,
    ),
  ],
  const IncomeItem(
    id: payItemLunch,
    name: 'Cơm trưa',
    type: IncomeItemType.deduction,
    calcMethod: IncomeCalcMethod.perWorkDay,
    amount: 10000,
    activeAfter: Clock(12, 30),
  ),
  if (kind == WorkerKind.worker)
    const IncomeItem(id: payItemUnion, name: 'Công đoàn phí', type: IncomeItemType.deduction, amount: 50000),
];

/// Phần lương của phiếu lương (lương cơ bản, lương ngày, các khoản) áp dụng từ kỳ bắt đầu ngày
/// [from] trở đi, cho tới kỳ có bản ghi kế tiếp. Nhờ đó sửa phiếu lương của kỳ nào thì chỉ kỳ đó
/// (và các kỳ sau, nếu là kỳ hiện tại) đổi; các kỳ trước giữ nguyên số của chúng.
class PayVersion {
  const PayVersion({required this.from, required this.baseSalary, required this.dailyWage, required this.items});

  /// Ngày đầu kỳ (00:00) mà bản ghi này bắt đầu có hiệu lực.
  final DateTime from;
  final double baseSalary;
  final double dailyWage;
  final List<IncomeItem> items;

  Map<String, dynamic> toJson() => {
    'from': dateKey(from),
    'baseSalary': baseSalary,
    'dailyWage': dailyWage,
    'items': items.map((e) => e.toJson()).toList(),
  };

  factory PayVersion.fromJson(Map<String, dynamic> json) => PayVersion(
    from: DateTime.parse(json['from'] as String),
    baseSalary: (json['baseSalary'] as num).toDouble(),
    dailyWage: (json['dailyWage'] as num).toDouble(),
    items: (json['items'] as List).map((e) => IncomeItem.fromJson(e as Map<String, dynamic>)).toList(),
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
    this.workerKind = WorkerKind.worker,
    this.dailyWage = 0,
    Map<String, double>? standardDays,
    this.showNotice = true,
    this.showGps = true,
    List<PayVersion>? payVersions,
  }) : payVersions = payVersions ?? [],
       wageTable = wageTable ?? WageTable(),
       fixedBreakRules = fixedBreakRules ?? [],
       breakSegments = breakSegments ?? [],
       lateRule = lateRule ?? const LateRule(after: Clock(7, 0)),
       overtimeBrackets = overtimeBrackets ?? [],
       gps = gps ?? GpsConfig(),
       incomeItems = incomeItems ?? [],
       holidays = holidays ?? [],
       standardDays = standardDays ?? {};

  /// Cài đặt mặc định của một loại người dùng (máy mới cài, hoặc khi đổi Công nhân ↔ Công nhật).
  /// [keep]: giữ lại các phần không thuộc cách tính lương (GPS, ngày lễ, khung tăng ca, ẩn/hiện).
  factory AppSettings.defaultsFor(WorkerKind kind, {AppSettings? keep}) {
    final worker = kind == WorkerKind.worker;
    return AppSettings(
      // Công nhân: giờ thường T2–T7 tự tính từ lương cơ bản nên để 0. Công nhật: ô nào để 0 thì
      // tự lấy lương ngày ÷ 8.
      wageTable: worker
          ? WageTable(
              rates: {
                DayType.weekday: const WageRate(overtimePerHour: 45000),
                DayType.saturday: const WageRate(overtimePerHour: 45000),
                DayType.sunday: const WageRate(normalPerHour: 45000, overtimePerHour: 45000),
                DayType.holiday: const WageRate(normalPerHour: 63000, overtimePerHour: 63000),
              },
            )
          : WageTable(),
      payPeriod: worker
          ? const PayPeriodConfig(monthlyStartDay: 21)
          : const PayPeriodConfig(type: PayPeriodType.semiMonthly),
      incomeItems: defaultPayItems(kind),
      baseSalary: worker ? 4000000 : 0,
      dailyWage: worker ? 0 : 350000,
      includeItemsInEstimate: true,
      workerKind: kind,
      fixedBreakRules: keep?.fixedBreakRules,
      breakSegments: keep?.breakSegments,
      overtimeBrackets: keep?.overtimeBrackets,
      gps: keep?.gps,
      holidays: keep?.holidays,
      showNotice: keep?.showNotice ?? true,
      showGps: keep?.showGps ?? true,
    );
  }

  final Clock workStart;
  final Clock workEnd;

  /// Công nhân: giờ thường của T2–T7 luôn tự tính từ lương cơ bản (bỏ qua số lưu ở đây). Công
  /// nhật: ô nào bằng 0 thì tự lấy lương ngày ÷ 8.
  final WageTable wageTable;
  final List<FixedBreakRule> fixedBreakRules;
  final List<BreakSegment> breakSegments;
  final LateRule lateRule;
  final List<OvertimeBracket> overtimeBrackets;
  final GpsConfig gps;
  final PayPeriodConfig payPeriod;

  /// Các khoản của phiếu lương (tiền lương, thưởng, trợ cấp, bảo hiểm, cơm trưa...), theo thứ tự hiện.
  final List<IncomeItem> incomeItems;
  final List<Holiday> holidays;

  /// Lương cơ bản một tháng của công nhân.
  final double baseSalary;

  /// Chỉ còn dùng cho cách tính cũ ([computePeriodStats]); phiếu lương luôn tính đủ các khoản.
  final bool includeItemsInEstimate;

  final WorkerKind workerKind;

  /// Lương một ngày (8 giờ) của công nhật.
  final double dailyWage;

  /// Công chuẩn người dùng tự sửa cho từng kỳ, khóa là [PayPeriod.key]. Kỳ không có ở đây thì app
  /// tự đếm (số ngày trong kỳ trừ chủ nhật).
  final Map<String, double> standardDays;

  /// Hiện thông báo của chủ app (băng ở màn chính và thẻ ở Cài đặt).
  final bool showNotice;

  /// Hiện mục Chấm công GPS ở Cài đặt. Tắt thì GPS cũng ngừng tự chấm.
  final bool showGps;

  /// Cấu hình GPS thật sự dùng để tự chấm: tắt công tắc "Dùng chấm công GPS" thì coi như tắt GPS,
  /// nhưng vẫn giữ nguyên tọa độ, khung giờ... để bật lại là chạy như cũ.
  GpsConfig get effectiveGps => showGps ? gps : gps.copyWith(enabled: false);

  /// Phần lương theo từng kỳ, xếp theo [PayVersion.from] tăng dần. Kỳ nào bắt đầu trước bản ghi đầu
  /// tiên thì dùng [baseSalary], [dailyWage], [incomeItems] ở trên.
  final List<PayVersion> payVersions;

  /// Cài đặt dùng để tính phiếu lương của kỳ bắt đầu ngày [periodStart]: phần lương lấy theo bản
  /// ghi gần nhất có hiệu lực từ trước hoặc đúng ngày đó.
  AppSettings payFor(DateTime periodStart) {
    final start = dateOnly(periodStart);
    PayVersion? found;
    for (final v in payVersions) {
      if (!v.from.isAfter(start)) found = v;
    }
    if (found == null) return this;
    return copyWith(baseSalary: found.baseSalary, dailyWage: found.dailyWage, incomeItems: found.items);
  }

  /// Sửa phần lương khi đang xem kỳ bắt đầu ngày [periodStart]. Thay đổi áp dụng cho kỳ đó; nếu đó
  /// là kỳ đã qua ([periodEnded]) thì các kỳ sau nó giữ nguyên như trước khi sửa, còn nếu là kỳ
  /// hiện tại thì các kỳ sau cũng theo số mới. Các kỳ trước không bao giờ bị đổi.
  AppSettings withPayEdit({
    required DateTime periodStart,
    required DateTime nextPeriodStart,
    required bool periodEnded,
    double? baseSalary,
    double? dailyWage,
    List<IncomeItem>? incomeItems,
  }) {
    final start = dateOnly(periodStart);
    final next = dateOnly(nextPeriodStart);
    final before = payFor(start);
    final edited = PayVersion(
      from: start,
      baseSalary: baseSalary ?? before.baseSalary,
      dailyWage: dailyWage ?? before.dailyWage,
      items: incomeItems ?? before.incomeItems,
    );
    final versions = [
      for (final v in payVersions)
        if (v.from != start) v,
      edited,
    ];
    // Sửa một kỳ đã qua: nếu chưa có bản ghi nào bắt đầu sau kỳ này cho tới đầu kỳ kế tiếp thì ghi
    // lại số cũ ở đầu kỳ kế tiếp, để các kỳ sau không bị đổi theo.
    final laterCovered = payVersions.any((v) => v.from.isAfter(start) && !v.from.isAfter(next));
    if (periodEnded && !laterCovered) {
      versions.add(
        PayVersion(from: next, baseSalary: before.baseSalary, dailyWage: before.dailyWage, items: before.incomeItems),
      );
    }
    versions.sort((a, b) => a.from.compareTo(b.from));
    return copyWith(payVersions: versions);
  }

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
    WorkerKind? workerKind,
    double? dailyWage,
    Map<String, double>? standardDays,
    bool? showNotice,
    bool? showGps,
    List<PayVersion>? payVersions,
  }) => AppSettings(
    payVersions: payVersions ?? this.payVersions,
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
    workerKind: workerKind ?? this.workerKind,
    dailyWage: dailyWage ?? this.dailyWage,
    standardDays: standardDays ?? this.standardDays,
    showNotice: showNotice ?? this.showNotice,
    showGps: showGps ?? this.showGps,
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
    'workerKind': workerKind.name,
    'dailyWage': dailyWage,
    'standardDays': standardDays,
    'showNotice': showNotice,
    'showGps': showGps,
    'payVersions': payVersions.map((v) => v.toJson()).toList(),
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final parsed = AppSettings(
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
      workerKind: json['workerKind'] != null ? WorkerKind.values.byName(json['workerKind'] as String) : WorkerKind.worker,
      dailyWage: (json['dailyWage'] as num?)?.toDouble() ?? 0,
      standardDays: (json['standardDays'] as Map?)?.map((k, v) => MapEntry('$k', (v as num).toDouble())),
      showNotice: json['showNotice'] as bool? ?? true,
      showGps: json['showGps'] as bool? ?? true,
      payVersions: (json['payVersions'] as List?)
          ?.map((e) => PayVersion.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
    return json['workerKind'] == null ? _migrateLegacy(parsed) : parsed;
  }

  /// Dữ liệu của bản trước khi có phiếu lương (tính tiền thẳng theo bảng lương/giờ): chuyển thành
  /// Công nhân sao cho số tiền gần như không đổi. Lương cơ bản chưa có thì suy ra từ lương giờ
  /// ngày thường (× 8 giờ × 26 ngày); thêm hai dòng "Tiền lương" và "Thưởng vượt khoán"; các khoản
  /// tự tạo cũ giữ nguyên.
  static AppSettings _migrateLegacy(AppSettings old) {
    final weekdayRate = old.wageTable.of(DayType.weekday).normalPerHour;
    final hasBuiltin = old.incomeItems.any((i) => i.id == payItemSalary);
    return old.copyWith(
      baseSalary: old.baseSalary > 0 ? old.baseSalary : weekdayRate * 8 * 26,
      incomeItems: hasBuiltin
          ? old.incomeItems
          : [
              const IncomeItem(id: payItemSalary, name: 'Tiền lương', calcMethod: IncomeCalcMethod.salary),
              const IncomeItem(id: payItemOvertime, name: 'Tăng ca', calcMethod: IncomeCalcMethod.overtime),
              ...old.incomeItems,
            ],
    );
  }
}

/// Dữ liệu chấm công của một ngày.
class DayRecord {
  const DayRecord({
    required this.date,
    this.checkIn,
    this.checkOut,
    this.isDayOff = false,
    this.paidLeave = false,
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

  /// Chỉ có nghĩa khi [isDayOff]: ngày nghỉ có lương (tính một ngày lương cơ bản) hay không lương.
  final bool paidLeave;
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
    bool? paidLeave,
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
    // Hết là ngày nghỉ thì cũng hết là nghỉ có lương.
    paidLeave: (isDayOff ?? this.isDayOff) && (paidLeave ?? this.paidLeave),
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
    'paidLeave': paidLeave,
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
    paidLeave: (json['dayOff'] as bool? ?? false) && (json['paidLeave'] as bool? ?? false),
    isLate: json['late'] as bool? ?? false,
    note: json['note'] as String?,
    tags: (json['tags'] as List?)?.map((e) => e as String).toList() ?? const [],
    gpsLastSeenNearby: json['gpsLastSeenNearby'] != null ? DateTime.parse(json['gpsLastSeenNearby'] as String) : null,
  );
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
