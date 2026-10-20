import 'package:cham_cong_don_gian/ui/home/edit_dialogs.dart';
import 'package:cham_cong_don_gian/ui/settings/settings_blocks.dart' show parseLatLng;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('giờ gõ bằng số: 9 là 9h, 0730 là 7h30, 1630 là 16h30', () {
    expect(parseHourDigits('9'), (9, 0));
    expect(parseHourDigits('16'), (16, 0));
    expect(parseHourDigits('0730'), (7, 30));
    expect(parseHourDigits('730'), (7, 30));
    expect(parseHourDigits('1630'), (16, 30));
    expect(parseHourDigits(''), isNull);
    expect(parseHourDigits('2500'), isNull);
    expect(parseHourDigits('0775'), isNull);
    expect(parseHourDigits('7h30'), isNull);
    // Số giờ làm (giờ công, tăng ca) được tới 24.
    expect(parseHourDigits('24', maxHour: 24), (24, 0));
    expect(parseHourDigits('24', maxHour: 23), isNull);
  });

  test('tọa độ nhập tay: "vĩ độ, kinh độ" như dán từ Google Maps', () {
    // Google Maps tiếng Việt: dấu phẩy là dấu thập phân.
    expect(parseLatLng('11,7598094, 108,4397679'), (11.7598094, 108.4397679));
    expect(parseLatLng('11,7598094,108,4397679'), (11.7598094, 108.4397679));
    expect(parseLatLng('11,7598094; 108,4397679'), (11.7598094, 108.4397679));
    // Kiểu tiếng Anh.
    expect(parseLatLng('11.759805, 108.439777'), (11.759805, 108.439777));
    expect(parseLatLng('11.759805,108.439777'), (11.759805, 108.439777));
    expect(parseLatLng(' 11.759805 108.439777 '), (11.759805, 108.439777));
    expect(parseLatLng('11.759805'), isNull);
    expect(parseLatLng('abc, 108'), isNull);
    expect(parseLatLng('95, 108'), isNull);
  });
}
