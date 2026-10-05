/// File Excel (.xlsx) sao lưu dữ liệu chấm công: vừa để người dùng mở ra đọc (kể cả khi không
/// còn dùng app), vừa để khôi phục lại vào app.
///
/// Các trang trong file:
/// - "Chấm công": mỗi ngày có dữ liệu một dòng (giờ vào/ra, giờ công, tăng ca, tiền tạm tính...).
/// - "Theo kỳ": tổng giờ và tiền của từng kỳ lương.
/// - "Thông tin": ngày xuất, cách khôi phục.
/// - "DuLieuApp" (ẩn): toàn bộ dữ liệu gốc dạng JSON, chia thành nhiều ô (mỗi ô Excel chứa tối đa
///   32.767 ký tự). Khôi phục chỉ đọc trang này, nên người dùng sửa số ở các trang khác cũng không
///   làm hỏng việc khôi phục.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:xml/xml.dart';

import '../domain/backup.dart';
import '../domain/calc.dart';
import '../domain/models.dart';
import '../domain/pay_period.dart';

const backupDataSheet = 'DuLieuApp';
const _daysSheet = 'Chấm công';
const _periodsSheet = 'Theo kỳ';
const _infoSheet = 'Thông tin';
const _chunkSize = 30000;

const xlsxMimeType = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

String backupFileName(DateTime exportedAt) => 'ChamCong_${dateKey(exportedAt)}.xlsx';

String _two(int n) => n.toString().padLeft(2, '0');
String _date(DateTime d) => '${_two(d.day)}/${_two(d.month)}/${d.year}';

String _time(DateTime t, DateTime day) {
  final text = '${_two(t.hour)}:${_two(t.minute)}';
  return dateOnly(t) == dateOnly(day) ? text : '$text (${_date(t)})';
}

const _weekdays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

String _dayTypeName(DayType type) => switch (type) {
  DayType.weekday => 'Ngày thường',
  DayType.saturday => 'Thứ 7',
  DayType.sunday => 'Chủ nhật',
  DayType.holiday => 'Ngày lễ',
};

double _hours(int minutes) => (minutes / 60 * 100).round() / 100;

final _header = CellStyle(bold: true, backgroundColorHex: ExcelColor.fromHexString('#DCEEE9'));
final _bold = CellStyle(bold: true);
final _money = CellStyle(numberFormat: const CustomNumericNumFormat(formatCode: '#,##0'));
final _moneyBold = CellStyle(bold: true, numberFormat: const CustomNumericNumFormat(formatCode: '#,##0'));

TextCellValue _t(String s) => TextCellValue(s);
DoubleCellValue _n(double v) => DoubleCellValue(v);

void _row(Sheet sheet, int row, List<CellValue?> values, {CellStyle? style, Set<int> moneyCols = const {}}) {
  for (var c = 0; c < values.length; c++) {
    final value = values[c];
    if (value == null) continue;
    final cellStyle = moneyCols.contains(c) ? (style == null ? _money : _moneyBold) : style;
    sheet.updateCell(
      CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row),
      value,
      cellStyle: cellStyle,
    );
  }
}

/// Tạo file Excel từ dữ liệu app. [records] là các ngày đã lưu (khóa `yyyy-MM-dd`).
Uint8List buildBackupExcel({
  required AppSettings settings,
  required Map<String, DayRecord> records,
  required Map<String, double> periodOverrides,
  required DateTime exportedAt,
  required String appVersion,
}) {
  final excel = Excel.createExcel();
  final defaultSheet = excel.getDefaultSheet()!;
  excel.rename(defaultSheet, _daysSheet);

  final days = records.values.where(recordHasData).toList()..sort((a, b) => a.date.compareTo(b.date));

  // --- Trang "Chấm công" ---
  final daySheet = excel[_daysSheet];
  const dayMoneyCol = 9;
  _row(daySheet, 0, [
    for (final h in [
      'Ngày',
      'Thứ',
      'Loại ngày',
      'Giờ vào',
      'Giờ ra',
      'Giờ thường',
      'Tăng ca (giờ)',
      'Nghỉ',
      'Đi muộn',
      'Tiền tạm tính',
      'Ghi chú',
    ])
      _t(h),
  ], style: _header);
  var totalNormal = 0;
  var totalOvertime = 0;
  var totalPay = 0.0;
  for (var i = 0; i < days.length; i++) {
    final r = days[i];
    final calc = computeDay(r, settings);
    totalNormal += calc.normalMinutes;
    totalOvertime += calc.overtimeMinutes;
    totalPay += calc.pay;
    final note = [if (r.note?.isNotEmpty ?? false) r.note!, ...r.tags].join(' · ');
    _row(
      daySheet,
      i + 1,
      [
        _t(_date(r.date)),
        _t(_weekdays[r.date.weekday - 1]),
        _t(_dayTypeName(calc.dayType)),
        r.checkIn == null ? null : _t(_time(r.checkIn!, r.date)),
        r.checkOut == null ? null : _t(_time(r.checkOut!, r.date)),
        _n(_hours(calc.normalMinutes)),
        _n(_hours(calc.overtimeMinutes)),
        r.isDayOff ? _t('Nghỉ') : null,
        r.isLate ? _t('Muộn') : null,
        _n(calc.pay.roundToDouble()),
        note.isEmpty ? null : _t(note),
      ],
      moneyCols: {dayMoneyCol},
    );
  }
  _row(
    daySheet,
    days.length + 1,
    [
      _t('Tổng'),
      null,
      null,
      null,
      null,
      _n(_hours(totalNormal)),
      _n(_hours(totalOvertime)),
      _t('${days.where((d) => d.isDayOff).length} ngày'),
      _t('${days.where((d) => d.isLate).length} ngày'),
      _n(totalPay.roundToDouble()),
    ],
    style: _bold,
    moneyCols: {dayMoneyCol},
  );
  const dayWidths = [12.0, 6.0, 12.0, 18.0, 18.0, 11.0, 13.0, 8.0, 9.0, 14.0, 40.0];
  for (var c = 0; c < dayWidths.length; c++) {
    daySheet.setColumnWidth(c, dayWidths[c]);
  }

  // --- Trang "Theo kỳ" ---
  final periodSheet = excel[_periodsSheet];
  _row(periodSheet, 0, [
    for (final h in [
      'Kỳ lương',
      'Giờ thường',
      'Tăng ca (giờ)',
      'Ngày công',
      'Ngày nghỉ',
      'Ngày đi muộn',
      'Tiền chấm công',
      'Khoản khác',
      'Tổng tạm tính',
      'Số tiền tự nhập',
    ])
      _t(h),
  ], style: _header);
  if (days.isNotEmpty) {
    var period = periodContaining(days.first.date, settings.payPeriod);
    final last = days.last.date;
    var row = 1;
    while (!period.start.isAfter(last)) {
      final p = period;
      final inPeriod = days.where((d) => p.contains(d.date));
      if (inPeriod.isNotEmpty || periodOverrides.containsKey(p.key)) {
        final stats = computePeriodStats(p, inPeriod, settings);
        final override = periodOverrides[p.key];
        _row(
          periodSheet,
          row++,
          [
            _t('${_date(p.start)} - ${_date(p.end)}'),
            _n(_hours(stats.normalMinutes)),
            _n(_hours(stats.overtimeMinutes)),
            _n(stats.workDayCount.toDouble()),
            _n(stats.daysOff.toDouble()),
            _n(stats.daysLate.toDouble()),
            _n(stats.attendanceIncome.roundToDouble()),
            _n(stats.itemsIncome.roundToDouble()),
            _n(stats.totalIncome.roundToDouble()),
            override == null ? null : _n(override.roundToDouble()),
          ],
          moneyCols: {6, 7, 8, 9},
        );
      }
      period = periodContaining(p.end.add(const Duration(days: 1)), settings.payPeriod);
    }
  }
  const periodWidths = [25.0, 11.0, 13.0, 11.0, 11.0, 13.0, 16.0, 13.0, 16.0, 16.0];
  for (var c = 0; c < periodWidths.length; c++) {
    periodSheet.setColumnWidth(c, periodWidths[c]);
  }

  // --- Trang "Thông tin" ---
  final infoSheet = excel[_infoSheet];
  final info = <(String, String)>[
    ('App', 'Chấm Công Đơn Giản'),
    ('Ngày xuất file', '${_date(exportedAt)} ${_two(exportedAt.hour)}:${_two(exportedAt.minute)}'),
    ('Phiên bản app', appVersion),
    ('Số ngày có dữ liệu', '${days.length}'),
    ('Về số tiền', 'Là số tạm tính theo bảng lương cài trong app lúc xuất file, không phải lương thực nhận.'),
    ('Khôi phục vào app', 'Mở app › Cài đặt › Sao lưu dữ liệu › Khôi phục từ file, rồi chọn file này.'),
    ('Lưu ý', 'File có một trang ẩn "$backupDataSheet" chứa dữ liệu gốc để khôi phục. Đừng xóa trang đó.'),
  ];
  for (var i = 0; i < info.length; i++) {
    _row(infoSheet, i, [_t(info[i].$1), _t(info[i].$2)]);
    infoSheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: i), _t(info[i].$1), cellStyle: _bold);
  }
  infoSheet.setColumnWidth(0, 20);
  infoSheet.setColumnWidth(1, 90);

  // --- Trang ẩn chứa dữ liệu gốc ---
  final payload = BackupPayload(
    exportedAt: exportedAt,
    appVersion: appVersion,
    data: {
      'settings': settings.toJson(),
      'records': {for (final d in days) dateKey(dateOnly(d.date)): d.toJson()},
      'periodOverrides': periodOverrides,
    },
  ).encode();
  final dataSheet = excel[backupDataSheet];
  _row(dataSheet, 0, [_t('Dữ liệu để khôi phục vào app Chấm Công Đơn Giản. Đừng sửa hay xóa trang này.')]);
  for (var i = 0, row = 1; i < payload.length; i += _chunkSize, row++) {
    final end = i + _chunkSize < payload.length ? i + _chunkSize : payload.length;
    _row(dataSheet, row, [_t(payload.substring(i, end))]);
  }

  excel.setDefaultSheet(_daysSheet);
  return _hideSheet(Uint8List.fromList(excel.encode()!), backupDataSheet);
}

/// Thư viện excel chưa hỗ trợ ẩn trang, nên sửa thẳng `xl/workbook.xml` trong file (file .xlsx
/// thực chất là một file nén chứa các file XML): thêm `state="hidden"` cho trang cần ẩn.
Uint8List _hideSheet(Uint8List xlsx, String sheetName) {
  final archive = ZipDecoder().decodeBytes(xlsx);
  final out = Archive();
  for (final file in archive.files) {
    if (file.name == 'xl/workbook.xml') {
      final xml = utf8.decode(file.content as List<int>);
      // Bỏ thuộc tính `state` sẵn có (thư viện ghi `state="visible"`) rồi mới thêm `state="hidden"`:
      // một thẻ có hai thuộc tính trùng tên thì Excel coi cả file là hỏng.
      final hidden = xml.replaceFirstMapped(
        RegExp('<sheet ([^>]*name="${RegExp.escape(sheetName)}"[^>]*?)(/?)>'),
        (m) => '<sheet ${m[1]!.replaceAll(RegExp(r'\s*state="[^"]*"'), '').trim()} state="hidden"${m[2]}>',
      );
      final bytes = utf8.encode(hidden);
      out.addFile(ArchiveFile(file.name, bytes.length, bytes));
    } else {
      out.addFile(file);
    }
  }
  return Uint8List.fromList(ZipEncoder().encode(out)!);
}

/// Đọc dữ liệu gốc từ trang ẩn của file sao lưu. Ném [FormatException] (kèm lời giải thích dễ hiểu)
/// nếu không phải file sao lưu của app.
///
/// Tự đọc XML thay vì dùng thư viện excel, vì sau khi người dùng mở và lưu lại file bằng Excel,
/// Google Sheets, WPS..., chữ trong ô có thể được lưu theo nhiều kiểu khác nhau (bảng chữ dùng chung
/// `sharedStrings.xml`, hoặc ghi thẳng trong ô) mà thư viện không đọc được hết.
BackupPayload readBackupExcel(Uint8List bytes) {
  const notExcel = FormatException('Không mở được file. Hãy chọn đúng file Excel (.xlsx) đã xuất từ app.');
  const noData = FormatException(
    'File này không có dữ liệu để khôi phục (không phải file xuất từ app, hoặc trang "$backupDataSheet" đã bị xóa).',
  );
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes);
  } catch (_) {
    throw notExcel;
  }
  XmlDocument? read(String path) {
    final file = archive.findFile(path);
    if (file == null) return null;
    try {
      return XmlDocument.parse(utf8.decode(file.content as List<int>));
    } catch (_) {
      return null;
    }
  }

  final workbook = read('xl/workbook.xml');
  if (workbook == null) throw notExcel;
  final sheet = workbook.findAllElements('sheet').where((e) => e.getAttribute('name') == backupDataSheet).firstOrNull;
  final relId = sheet?.attributes.where((a) => a.name.local == 'id').firstOrNull?.value;
  if (relId == null) throw noData;
  final rel = read(
    'xl/_rels/workbook.xml.rels',
  )?.findAllElements('Relationship').where((e) => e.getAttribute('Id') == relId).firstOrNull;
  final target = rel?.getAttribute('Target');
  if (target == null) throw noData;
  final sheetPath = target.startsWith('/') ? target.substring(1) : 'xl/$target';
  final sheetXml = read(sheetPath);
  if (sheetXml == null) throw noData;

  // Chữ của một ô/mục: nối mọi thẻ <t> (chữ có định dạng được chia thành nhiều đoạn).
  String textOf(XmlElement e) => e.findAllElements('t').map((t) => t.innerText).join();
  final shared = read('xl/sharedStrings.xml')?.findAllElements('si').map(textOf).toList() ?? const <String>[];

  final text = StringBuffer();
  for (final row in sheetXml.findAllElements('row')) {
    final rowNumber = int.tryParse(row.getAttribute('r') ?? '');
    if (rowNumber == 1) continue; // dòng 1 là lời nhắc, không phải dữ liệu
    final cell = row
        .findElements('c')
        .where((c) => (c.getAttribute('r') ?? 'A').startsWith(RegExp(r'A\d')))
        .firstOrNull;
    if (cell == null) continue;
    final value = switch (cell.getAttribute('t')) {
      's' => shared.elementAtOrNull(int.tryParse(cell.getElement('v')?.innerText ?? '') ?? -1) ?? '',
      'inlineStr' => textOf(cell),
      _ => cell.getElement('v')?.innerText ?? '',
    };
    text.write(value);
  }
  if (text.isEmpty) throw noData;
  return BackupPayload.decode(text.toString());
}
