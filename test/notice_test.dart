import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cham_cong_don_gian/notice/notice.dart';
import 'package:cham_cong_don_gian/theme/app_theme.dart';
import 'package:cham_cong_don_gian/ui/settings/notice_section.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      expect(ok.links.single.url, 'https://facebook.com/groups/abc');
      expect(ok.links.single.label, 'Xem');
      expect(AppNotice.fromValues(text: 'a', url: 'https://x.vn', button: 'Vào nhóm')!.links.single.label, 'Vào nhóm');
    });

    test(r'notice_links: mỗi dòng (hoặc \n) một link "Chữ | link"; link sai bị bỏ; thiếu chữ thì "Mở link"', () {
      final links = parseNoticeLinks(
        r'Nhóm Facebook | https://facebook.com/groups/abc\nNhóm Zalo|https://zalo.me/g/xyz\nSai | zalo\n\nhttps://x.vn',
      );
      expect([for (final l in links) l.label], ['Nhóm Facebook', 'Nhóm Zalo', 'Mở link']);
      expect(
        [for (final l in links) l.url],
        ['https://facebook.com/groups/abc', 'https://zalo.me/g/xyz', 'https://x.vn'],
      );
      expect(parseNoticeLinks('Dòng 1\nDòng 2 | https://a.vn').single.label, 'Dòng 2');
      expect(parseNoticeLinks(''), isEmpty);
    });

    test('link kiểu cũ (notice_url) đứng trước các link của notice_links', () {
      final n = AppNotice.fromValues(
        text: 'a',
        url: 'https://web.vn',
        button: 'Web',
        links: 'Zalo | https://zalo.me/g/1',
      )!;
      expect([for (final l in n.links) l.label], ['Web', 'Zalo']);
    });

    test('đổi nội dung, tiêu đề hoặc link là thành thông báo khác (hiện lại sau khi đã tắt)', () {
      final a = AppNotice.fromValues(text: 'Mẹo 1', title: 'Cách dùng')!;
      expect(a.key, AppNotice.fromValues(text: 'Mẹo 1', title: 'Cách dùng')!.key);
      expect(a.key, isNot(AppNotice.fromValues(text: 'Mẹo 2', title: 'Cách dùng')!.key));
      expect(a.key, isNot(AppNotice.fromValues(text: 'Mẹo 1', title: 'Cách dùng', url: 'https://x.vn')!.key));
      expect(
        a.key,
        isNot(AppNotice.fromValues(text: 'Mẹo 1', title: 'Cách dùng', links: 'Zalo | https://zalo.me/g/1')!.key),
      );
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
    expect(find.text('Xem thêm'), findsNothing);
  });

  testWidgets('Nội dung dài thì có "Xem thêm"; bấm × thì ẩn băng và nhắc xem lại ở Cài đặt', (tester) async {
    addTearDown(() {
      currentNotice.value = null;
      activeNotice.value = null;
    });
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SizedBox(width: 360, child: NoticeBanner())),
      ),
    );
    final notice = AppNotice.fromValues(
      text: List.filled(6, 'Dòng nội dung dài').join(r'\n'),
      title: 'Nhóm hỗ trợ',
      links: 'Nhóm Facebook | https://facebook.com/groups/abc\nNhóm Zalo | https://zalo.me/g/xyz',
    );
    currentNotice.value = notice;
    activeNotice.value = notice;
    await tester.pump();
    expect(find.text('Xem thêm'), findsOneWidget);
    expect(find.text('Nhóm Facebook'), findsOneWidget);
    expect(find.text('Nhóm Zalo'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    expect(find.text('Nhóm hỗ trợ'), findsNothing);
    expect(find.textContaining('Cài đặt › Thông báo'), findsOneWidget);
    // Cài đặt › Thông báo vẫn còn nội dung sau khi đã đóng băng.
    expect(activeNotice.value, isNotNull);
  });

  testWidgets('Cài đặt › Thông báo ẩn khi không có thông báo, hiện đủ nội dung khi có', (tester) async {
    addTearDown(() => activeNotice.value = null);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: const Scaffold(body: SingleChildScrollView(child: NoticeSection())),
      ),
    );
    expect(find.text('Thông báo'), findsNothing);
    activeNotice.value = AppNotice.fromValues(text: 'Nội dung', title: 'Tiêu đề', links: 'Zalo | https://zalo.me/g/1');
    await tester.pump();
    expect(find.text('Thông báo'), findsOneWidget);
    expect(find.text('Tiêu đề'), findsOneWidget);
    expect(find.text('Nội dung'), findsOneWidget);
    expect(find.text('Zalo'), findsOneWidget);
  });
}
