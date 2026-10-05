import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cham_cong_don_gian/data/store.dart';
import 'package:cham_cong_don_gian/theme/app_theme.dart';
import 'package:cham_cong_don_gian/ui/settings/settings_card.dart';
import 'package:cham_cong_don_gian/ui/settings/settings_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CollapsedSettings.resetCache();
  });

  Future<void> pumpSettings(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = AppStore()..loaded = true;

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: store,
        child: MaterialApp(theme: buildAppTheme(Brightness.light), home: const SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Màn Cài đặt hiện đủ các mục chính', (tester) async {
    await pumpSettings(tester);

    expect(find.text('Khung giờ ra vào'), findsOneWidget);
    expect(find.text('Bảng lương/giờ'), findsOneWidget);
    expect(find.text('Ngày lễ'), findsNWidgets(2)); // cột bảng lương + tiêu đề mục
    expect(find.textContaining('Cộng trừ giờ theo giờ vào'), findsOneWidget);
    expect(find.textContaining('Khung nhiều mục'), findsNothing); // mục dự phòng đã bỏ
    expect(find.text('Đi muộn'), findsOneWidget);
    expect(find.text('Tăng ca theo khung'), findsOneWidget);
    expect(find.text('Chấm công GPS'), findsOneWidget);
    expect(find.text('Kỳ lương'), findsOneWidget);
    expect(find.text('Khoản thu nhập / khấu trừ khác'), findsOneWidget);
    expect(find.text('Sao chép / dán cấu hình'), findsOneWidget);
  });

  testWidgets('Mục mở sẵn; gập mục nào thì lần sau mở Cài đặt mục đó vẫn gập', (tester) async {
    await pumpSettings(tester);
    expect(find.text('Thêm khung cố định'), findsOneWidget);
    expect(find.text('Thêm khung'), findsOneWidget);

    await tester.tap(find.textContaining('Cộng trừ giờ theo giờ vào'));
    await tester.pumpAndSettle();
    expect(find.text('Thêm khung cố định'), findsNothing);

    // Đóng màn Cài đặt rồi mở lại (cả khi app khởi động lại, bộ nhớ tạm đã mất).
    await tester.pumpWidget(const SizedBox());
    CollapsedSettings.resetCache();
    await pumpSettings(tester);
    expect(find.text('Thêm khung cố định'), findsNothing);
    expect(find.text('Thêm khung'), findsOneWidget); // mục khác không bị ảnh hưởng

    // Chạm lần nữa thì mở ra lại.
    await tester.tap(find.textContaining('Cộng trừ giờ theo giờ vào'));
    await tester.pumpAndSettle();
    expect(find.text('Thêm khung cố định'), findsOneWidget);
  });
}
