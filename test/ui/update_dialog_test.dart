import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cham_cong_don_gian/update/update_policy.dart';
import 'package:cham_cong_don_gian/update/update_screen.dart';
import 'package:cham_cong_don_gian/update/update_service.dart';

void main() {
  Future<void> open(WidgetTester tester, UpdateStatus status) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(onPressed: () => showUpdateDialog(context, status), child: const Text('mở')),
        ),
      ),
    );
    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();
  }

  testWidgets('còn lượt: có Cập nhật và Để sau (còn N lần), kèm dòng giữ dữ liệu', (tester) async {
    await open(tester, const UpdateStatus(kind: UpdatePromptKind.update, latestVersion: '1.1.0', remainingSkips: 2));
    expect(find.text('Cần cập nhật lên bản mới'), findsOneWidget);
    expect(find.text('Cập nhật'), findsOneWidget);
    expect(find.text('Để sau (còn 2 lần)'), findsOneWidget);
    expect(find.text('Dữ liệu chấm công và cài đặt của bạn được giữ nguyên.'), findsOneWidget);
    await tester.tap(find.text('Để sau (còn 2 lần)'));
    await tester.pumpAndSettle();
    expect(find.text('Cần cập nhật lên bản mới'), findsNothing);
  });

  testWidgets('hết lượt: chỉ còn Cập nhật, chạm ra ngoài hay bấm quay lại cũng không tắt', (tester) async {
    await open(tester, const UpdateStatus(kind: UpdatePromptKind.forced, latestVersion: '1.1.0', maxSkips: 3));
    expect(find.byType(OutlinedButton), findsNothing);
    expect(find.textContaining('Bạn đã bấm "Để sau" 3 lần'), findsOneWidget);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.text('Cần cập nhật lên bản mới'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Cần cập nhật lên bản mới'), findsOneWidget);
  });

  testWidgets('lâu không có mạng: Thử lại và Để sau, tắt được', (tester) async {
    await open(tester, const UpdateStatus(kind: UpdatePromptKind.offline, offlineDays: 10));
    expect(find.text('Hãy bật mạng để kiểm tra bản mới'), findsOneWidget);
    expect(find.textContaining('Đã 10 ngày'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
    await tester.tap(find.text('Để sau'));
    await tester.pumpAndSettle();
    expect(find.text('Hãy bật mạng để kiểm tra bản mới'), findsNothing);
  });
}
