import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cham_cong_don_gian/data/backup_excel.dart';
import 'package:cham_cong_don_gian/domain/models.dart';

/// Số trong ô (Excel không phân biệt số nguyên và số thập phân, đọc lại 2.0 thành 2).
num _num(Data? cell) => switch (cell!.value) {
  DoubleCellValue(:final value) => value,
  IntCellValue(:final value) => value,
  final other => throw StateError('Không phải số: $other'),
};

void main() {
  // Công nhật chỉ có dòng Tiền lương: tiền mỗi ngày = giờ thường × 30.000 + giờ tăng ca × 45.000.
  final settings = AppSettings.defaultsFor(WorkerKind.daily).copyWith(
    wageTable: WageTable(
      rates: {for (final t in DayType.values) t: const WageRate(normalPerHour: 30000, overtimePerHour: 45000)},
    ),
    incomeItems: [defaultPayItems(WorkerKind.daily).first],
    overtimeBrackets: const [],
  );
  // Gần 2 năm dữ liệu, có ghi chú tiếng Việt và ký tự đặc biệt, để file đủ lớn phải chia nhiều ô.
  final records = <String, DayRecord>{};
  for (var i = 0; i < 700; i++) {
    final d = DateTime(2025, 1, 1).add(Duration(days: i));
    final r = d.weekday == DateTime.sunday
        ? DayRecord(date: d, isDayOff: true)
        : DayRecord(
            date: d,
            checkIn: DateTime(d.year, d.month, d.day, 8),
            checkOut: DateTime(d.year, d.month, d.day, 19),
            isLate: i % 10 == 0,
            note: i % 7 == 0 ? 'Tăng ca "gấp" <kho> & đóng hàng' : null,
          );
    records[dateKey(d)] = r;
  }
  final exportedAt = DateTime(2026, 10, 5, 10, 15);

  Uint8List build() => buildBackupExcel(
    settings: settings,
    records: records,
    periodOverrides: {'2025-01-01_2025-01-31': 9000000},
    exportedAt: exportedAt,
    appVersion: '1.0.1',
  );

  test('xuất rồi đọc lại được đúng toàn bộ dữ liệu', () {
    final payload = readBackupExcel(build());
    expect(payload.exportedAt, exportedAt);
    expect(payload.appVersion, '1.0.1');
    expect(payload.records.length, 700);
    final back = DayRecord.fromJson(payload.records['2025-01-01'] as Map<String, dynamic>);
    expect(back.note, 'Tăng ca "gấp" <kho> & đóng hàng');
    expect(back.isLate, isTrue);
    expect((payload.data['periodOverrides'] as Map)['2025-01-01_2025-01-31'], 9000000);
    expect(
      AppSettings.fromJson(
        payload.data['settings'] as Map<String, dynamic>,
      ).wageTable.of(DayType.weekday).normalPerHour,
      30000,
    );
  });

  test('trang dữ liệu bị ẩn, trang "Chấm công" mở đầu tiên và có tiền của ngày theo phiếu lương', () {
    final bytes = build();
    final workbook = utf8.decode(
      ZipDecoder().decodeBytes(bytes).files.firstWhere((f) => f.name == 'xl/workbook.xml').content as List<int>,
    );
    final sheetTags = RegExp('<sheet [^>]*>').allMatches(workbook).map((m) => m[0]!).toList();
    final dataTag = sheetTags.singleWhere((t) => t.contains('name="$backupDataSheet"'));
    // Đúng một thuộc tính state (trùng thuộc tính thì Excel báo file hỏng), và là hidden.
    expect(RegExp('state=').allMatches(dataTag).length, 1);
    expect(dataTag, contains('state="hidden"'));
    for (final tag in sheetTags.where((t) => t != dataTag)) {
      expect(tag, isNot(contains('hidden')));
    }

    final excel = Excel.decodeBytes(bytes);
    expect(excel.tables.keys.first, 'Chấm công');
    final rows = excel.tables['Chấm công']!.rows;
    expect(rows.first.map((c) => c?.value.toString()), contains('Tiền của ngày'));
    // 1/1/2025 (thứ Tư), giờ làm mặc định 7h-16h: vào 8h, ra 19h → 8 giờ, trừ nghỉ trưa 1 giờ và đi
    // muộn 30 phút còn 6,5; 16h-19h = 3 giờ tăng ca.
    final first = rows[1];
    expect(first[0]!.value.toString(), '01/01/2025');
    expect(_num(first[5]), 6.5);
    expect(_num(first[6]), 3);
    expect(_num(first[9]), 6.5 * 30000 + 3 * 45000);
    expect(excel.tables.keys, containsAll(['Theo kỳ', 'Thông tin']));
    // Trang "Theo kỳ": cột Thực nhận lấy từ phiếu lương, bằng tổng tiền các ngày của kỳ.
    final periods = excel.tables['Theo kỳ']!.rows;
    expect(periods.first.map((c) => c?.value.toString()), contains('Thực nhận'));
    final jan = periods[1];
    expect(jan[0]!.value.toString(), '01/01/2025 - 15/01/2025');
    final janDays = rows.skip(1).where((r) {
      final t = r[0]?.value.toString() ?? '';
      final day = int.tryParse(t.split('/').first) ?? 99;
      return t.endsWith('/01/2025') && day <= 15;
    });
    expect(_num(jan[8]), janDays.fold<num>(0, (s, r) => s + _num(r[9])));
  });

  test('vẫn khôi phục được khi file đã được lưu lại bằng chương trình khác (chữ ghi thẳng trong ô)', () {
    // Giống file sau khi mở và lưu lại bằng một số chương trình: không có sharedStrings.xml, chữ
    // ghi thẳng trong ô (inlineStr), dữ liệu bị chia ở giữa một ký tự tiếng Việt cũng không sao.
    final payload = readBackupExcel(build()).encode();
    final half = payload.length ~/ 2;
    String cell(int row, String text) =>
        '<c r="A$row" t="inlineStr"><is><t>${text.replaceAll('&', '&amp;').replaceAll('<', '&lt;')}</t></is></c>';
    final files = {
      'xl/workbook.xml':
          '<workbook xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>'
          '<sheet name="Chấm công" sheetId="1" r:id="rId1"/><sheet name="$backupDataSheet" sheetId="2" state="hidden" r:id="rId2"/>'
          '</sheets></workbook>',
      'xl/_rels/workbook.xml.rels':
          '<Relationships><Relationship Id="rId1" Target="worksheets/sheet1.xml"/>'
          '<Relationship Id="rId2" Target="/xl/worksheets/sheet2.xml"/></Relationships>',
      'xl/worksheets/sheet2.xml':
          '<worksheet><sheetData><row r="1">${cell(1, 'Đừng sửa')}</row>'
          '<row r="2">${cell(2, payload.substring(0, half))}</row><row r="3">${cell(3, payload.substring(half))}</row>'
          '</sheetData></worksheet>',
    };
    final archive = Archive();
    files.forEach((name, xml) {
      final bytes = utf8.encode(xml);
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    });
    final back = readBackupExcel(Uint8List.fromList(ZipEncoder().encode(archive)!));
    expect(back.records.length, 700);
    expect(
      DayRecord.fromJson(back.records['2025-01-01'] as Map<String, dynamic>).note,
      'Tăng ca "gấp" <kho> & đóng hàng',
    );
  });

  test('file không phải bản sao lưu của app thì báo lỗi dễ hiểu', () {
    final other = Excel.createExcel();
    other['Sheet1'].updateCell(CellIndex.indexByString('A1'), TextCellValue('abc'));
    expect(() => readBackupExcel(Uint8List.fromList(other.encode()!)), throwsFormatException);
    expect(() => readBackupExcel(Uint8List.fromList([1, 2, 3])), throwsFormatException);
  });
}
