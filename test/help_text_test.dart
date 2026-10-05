import 'package:flutter_test/flutter_test.dart';

import 'package:cham_cong_don_gian/notice/help_text.dart';

void main() {
  group('Hướng dẫn soạn trên Firebase (help_text)', () {
    test('để trống thì dùng hướng dẫn có sẵn', () {
      expect(parseHelpText(''), isNull);
      expect(parseHelpText(r'  \n  '), isNull);
    });

    test(r'mỗi mục "Tiêu đề | Nội dung", cách nhau bằng xuống dòng hoặc \n', () {
      final items = parseHelpText(r'Lịch | Chạm một ngày để chọn.\nChấm vào | Chạm để lấy giờ hiện tại.')!;
      expect([for (final i in items) i.title], ['Lịch', 'Chấm vào']);
      expect(items[1].body, 'Chạm để lấy giờ hiện tại.');
    });

    test('dòng không có | được nối vào nội dung mục ngay trên', () {
      final items = parseHelpText('Lịch | Đoạn 1\nĐoạn 2\n\nGPS | Bật trong Cài đặt')!;
      expect(items.length, 2);
      expect(items[0].body, 'Đoạn 1\nĐoạn 2');
    });

    test('dòng đầu không có | thì là tiêu đề', () {
      final items = parseHelpText('Lưu ý\nDữ liệu nằm trong máy.')!;
      expect(items.single.title, 'Lưu ý');
      expect(items.single.body, 'Dữ liệu nằm trong máy.');
    });
  });
}
