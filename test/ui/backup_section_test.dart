import 'package:flutter_test/flutter_test.dart';

import 'package:cham_cong_don_gian/ui/settings/backup_section.dart';

void main() {
  test('Đường dẫn file sau khi lưu được viết cho dễ tìm', () {
    const name = 'ChamCong_2026-10-05.xlsx';
    expect(
      savedLocationText(
        Uri.parse('content://com.android.externalstorage.documents/document/primary%3ADownload%2FChamCong_2026-10-05.xlsx'),
        name,
      ),
      'Bộ nhớ máy › Download › ChamCong_2026-10-05.xlsx',
    );
    expect(
      savedLocationText(
        Uri.parse(
          'content://com.android.providers.downloads.documents/document/raw%3A%2Fstorage%2Femulated%2F0%2FDownload%2FChamCong_2026-10-05.xlsx',
        ),
        name,
      ),
      'Bộ nhớ máy › Download/ChamCong_2026-10-05.xlsx',
    );
    expect(
      savedLocationText(Uri.parse('content://com.android.providers.downloads.documents/document/msf%3A1000'), name),
      'Download (Tải xuống) › $name',
    );
    expect(savedLocationText(Uri.parse('content://x.y/document/42'), name), '$name (trong thư mục bạn vừa chọn)');
  });
}
