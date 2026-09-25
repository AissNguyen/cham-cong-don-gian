import 'dart:math' as math;

// Âm lịch Việt Nam (múi giờ +7), thuật toán Hồ Ngọc Đức, tính ngay trong máy, không cần mạng.
// Chuyển từ mockup cham-cong.html; đã đối chiếu Tết 2024, 2025, 2026 và Trung thu 2026.

/// Ngày âm lịch. [leap] là tháng nhuận.
class LunarDate {
  const LunarDate(this.day, this.month, this.year, {this.leap = false});
  final int day;
  final int month;
  final int year;
  final bool leap;

  /// "20/8" hoặc "1/6n" (n là nhuận).
  String get short => '$day/$month${leap ? 'n' : ''}';

  @override
  bool operator ==(Object other) =>
      other is LunarDate && other.day == day && other.month == month && other.year == year && other.leap == leap;

  @override
  int get hashCode => Object.hash(day, month, year, leap);

  @override
  String toString() => 'LunarDate($short/$year)';
}

const _tz = 7;
const _synodic = 29.530588853;
const _epoch = 2415021.076998695;

int _floor(num v) => v.floor();

/// Số ngày Julian của ngày dương lịch.
int jdFromDate(int d, int m, int y) {
  final a = _floor((14 - m) / 12);
  final yy = y + 4800 - a;
  final mo = m + 12 * a - 3;
  var jd = d + _floor((153 * mo + 2) / 5) + 365 * yy + _floor(yy / 4) - _floor(yy / 100) + _floor(yy / 400) - 32045;
  if (jd < 2299161) jd = d + _floor((153 * mo + 2) / 5) + 365 * yy + _floor(yy / 4) - 32083;
  return jd;
}

({int day, int month, int year}) jdToDate(int jd) {
  int b, c;
  if (jd > 2299160) {
    final a = jd + 32044;
    b = _floor((4 * a + 3) / 146097);
    c = a - _floor((b * 146097) / 4);
  } else {
    b = 0;
    c = jd + 32082;
  }
  final d = _floor((4 * c + 3) / 1461);
  final e = c - _floor((1461 * d) / 4);
  final m = _floor((5 * e + 2) / 153);
  return (
    day: e - _floor((153 * m + 2) / 5) + 1,
    month: m + 3 - 12 * _floor(m / 10),
    year: b * 100 + d - 4800 + _floor(m / 10),
  );
}

double _newMoon(int k) {
  final t = k / 1236.85, t2 = t * t, t3 = t2 * t;
  const dr = math.pi / 180;
  var jd1 = 2415020.75933 + 29.53058868 * k + 0.0001178 * t2 - 0.000000155 * t3;
  jd1 += 0.00033 * math.sin((166.56 + 132.87 * t - 0.009173 * t2) * dr);
  final m = 359.2242 + 29.10535608 * k - 0.0000333 * t2 - 0.00000347 * t3;
  final mpr = 306.0253 + 385.81691806 * k + 0.0107306 * t2 + 0.00001236 * t3;
  final f = 21.2964 + 390.67050646 * k - 0.0016528 * t2 - 0.00000239 * t3;
  var c1 = (0.1734 - 0.000393 * t) * math.sin(m * dr) + 0.0021 * math.sin(2 * dr * m);
  c1 -= 0.4068 * math.sin(mpr * dr);
  c1 += 0.0161 * math.sin(dr * 2 * mpr);
  c1 -= 0.0004 * math.sin(dr * 3 * mpr);
  c1 += 0.0104 * math.sin(dr * 2 * f);
  c1 -= 0.0051 * math.sin(dr * (m + mpr));
  c1 -= 0.0074 * math.sin(dr * (m - mpr));
  c1 += 0.0004 * math.sin(dr * (2 * f + m));
  c1 -= 0.0004 * math.sin(dr * (2 * f - m));
  c1 -= 0.0006 * math.sin(dr * (2 * f + mpr));
  c1 += 0.0010 * math.sin(dr * (2 * f - mpr));
  c1 += 0.0005 * math.sin(dr * (2 * mpr + m));
  final dt = t < -11
      ? 0.001 + 0.000839 * t + 0.0002261 * t2 - 0.00000845 * t3 - 0.000000081 * t * t3
      : -0.000278 + 0.000265 * t + 0.000262 * t2;
  return jd1 + c1 - dt;
}

double _sunLongitude(double jdn) {
  final t = (jdn - 2451545.0) / 36525, t2 = t * t;
  const dr = math.pi / 180;
  final m = 357.52910 + 35999.05030 * t - 0.0001559 * t2 - 0.00000048 * t * t2;
  final l0 = 280.46645 + 36000.76983 * t + 0.0003032 * t2;
  var dl = (1.914600 - 0.004817 * t - 0.000014 * t2) * math.sin(dr * m);
  dl += (0.019993 - 0.000101 * t) * math.sin(dr * 2 * m) + 0.000290 * math.sin(dr * 3 * m);
  var l = (l0 + dl) * dr;
  l -= math.pi * 2 * _floor(l / (math.pi * 2));
  return l;
}

int _sunLong(int dayNumber) => _floor(_sunLongitude(dayNumber - 0.5 - _tz / 24) / math.pi * 6);

int _newMoonDay(int k) => _floor(_newMoon(k) + 0.5 + _tz / 24);

int _lunarMonth11(int y) {
  final off = jdFromDate(31, 12, y) - 2415021;
  final k = _floor(off / _synodic);
  var nm = _newMoonDay(k);
  if (_sunLong(nm) >= 9) nm = _newMoonDay(k - 1);
  return nm;
}

int _leapMonthOffset(int a11) {
  final k = _floor((a11 - _epoch) / _synodic + 0.5);
  var i = 1;
  var arc = _sunLong(_newMoonDay(k + i));
  int last;
  do {
    last = arc;
    i++;
    arc = _sunLong(_newMoonDay(k + i));
  } while (arc != last && i < 14);
  return i - 1;
}

/// Đổi ngày dương lịch sang âm lịch.
LunarDate solarToLunar(int d, int m, int y) {
  final dayNumber = jdFromDate(d, m, y);
  final k = _floor((dayNumber - _epoch) / _synodic);
  var monthStart = _newMoonDay(k + 1);
  if (monthStart > dayNumber) monthStart = _newMoonDay(k);
  var a11 = _lunarMonth11(y), b11 = a11;
  int ly;
  if (a11 >= monthStart) {
    ly = y;
    a11 = _lunarMonth11(y - 1);
  } else {
    ly = y + 1;
    b11 = _lunarMonth11(y + 1);
  }
  final ld = dayNumber - monthStart + 1;
  final diff = _floor((monthStart - a11) / 29);
  var leap = false;
  var lm = diff + 11;
  if (b11 - a11 > 365) {
    final lo = _leapMonthOffset(a11);
    if (diff >= lo) {
      lm = diff + 10;
      if (diff == lo) leap = true;
    }
  }
  if (lm > 12) lm -= 12;
  if (lm >= 11 && diff < 4) ly -= 1;
  return LunarDate(ld, lm, ly, leap: leap);
}

/// Đổi ngày âm lịch sang dương lịch (dạng [DateTime.utc]); null nếu ngày âm không tồn tại.
DateTime? lunarToSolar(int ld, int lm, int ly, {bool leap = false}) {
  int a11, b11;
  if (lm < 11) {
    a11 = _lunarMonth11(ly - 1);
    b11 = _lunarMonth11(ly);
  } else {
    a11 = _lunarMonth11(ly);
    b11 = _lunarMonth11(ly + 1);
  }
  final k = _floor(0.5 + (a11 - _epoch) / _synodic);
  var off = lm - 11;
  if (off < 0) off += 12;
  if (b11 - a11 > 365) {
    final lo = _leapMonthOffset(a11);
    var leapM = lo - 2;
    if (leapM < 0) leapM += 12;
    if (leap && lm != leapM) return null;
    if (leap || off >= lo) off += 1;
  } else if (leap) {
    return null; // năm không nhuận thì không có tháng nhuận
  }
  final s = jdToDate(_newMoonDay(k + off) + ld - 1);
  return DateTime.utc(s.year, s.month, s.day);
}

const _can = ['Canh', 'Tân', 'Nhâm', 'Quý', 'Giáp', 'Ất', 'Bính', 'Đinh', 'Mậu', 'Kỷ'];
const _chi = ['Thân', 'Dậu', 'Tuất', 'Hợi', 'Tý', 'Sửu', 'Dần', 'Mão', 'Thìn', 'Tỵ', 'Ngọ', 'Mùi'];

/// Tên năm âm lịch, ví dụ 2026 -> "Bính Ngọ".
String lunarYearName(int year) => '${_can[year % 10]} ${_chi[year % 12]}';
