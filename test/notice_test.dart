import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cham_cong_don_gian/notice/notice.dart';

void main() {
  group('Thông báo từ Remote Config', () {
    test('nội dung trống thì không có thông báo', () {
      expect(AppNotice.fromValues(text: ''), isNull);
      expect(AppNotice.fromValues(text: '   ', title: 'Tiêu đề'), isNull);
    });

    test(r'gõ \n trong Firebase thành xuống dòng', () {
      expect(AppNotice.fromValues(text: r'Dòng 1\nDòng 2')!.text, 'Dòng 1\nDòng 2');
    });

    test('link không hợp lệ thì bỏ nút, link đúng thì giữ; không đặt chữ nút thì ghi "Xem"', () {
      expect(AppNotice.fromValues(text: 'a', url: 'facebook')!.hasLink, isFalse);
      expect(AppNotice.fromValues(text: 'a', url: 'javascript:alert(1)')!.hasLink, isFalse);
      final ok = AppNotice.fromValues(text: 'a', url: ' https://facebook.com/groups/abc ')!;
      expect(ok.url, 'https://facebook.com/groups/abc');
      expect(ok.buttonLabel, 'Xem');
      expect(AppNotice.fromValues(text: 'a', url: 'https://x.vn', button: 'Vào nhóm')!.buttonLabel, 'Vào nhóm');
    });

    test('đổi nội dung, tiêu đề hoặc link là thành thông báo khác (hiện lại sau khi đã tắt)', () {
      final a = AppNotice.fromValues(text: 'Mẹo 1', title: 'Cách dùng')!;
      expect(a.key, AppNotice.fromValues(text: 'Mẹo 1', title: 'Cách dùng')!.key);
      expect(a.key, isNot(AppNotice.fromValues(text: 'Mẹo 2', title: 'Cách dùng')!.key));
      expect(a.key, isNot(AppNotice.fromValues(text: 'Mẹo 1', title: 'Cách dùng', url: 'https://x.vn')!.key));
    });
  });

  testWidgets('Băng thông báo hiện tiêu đề, nội dung, nút; không có thông báo thì không hiện gì', (tester) async {
    addTearDown(() => currentNotice.value = null);
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: NoticeBanner())));
    expect(find.byIcon(Icons.campaign_outlined), findsNothing);

    currentNotice.value = AppNotice.fromValues(
      text: 'Bấm giữ vào ngày trên lịch để sửa giờ.',
      title: 'Mẹo dùng app',
      url: 'https://facebook.com/groups/abc',
      button: 'Vào nhóm',
    );
    await tester.pump();
    expect(find.text('Mẹo dùng app'), findsOneWidget);
    expect(find.text('Bấm giữ vào ngày trên lịch để sửa giờ.'), findsOneWidget);
    expect(find.text('Vào nhóm'), findsOneWidget);
  });
}
