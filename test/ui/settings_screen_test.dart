import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:cham_cong_don_gian/data/store.dart';
import 'package:cham_cong_don_gian/theme/app_theme.dart';
import 'package:cham_cong_don_gian/ui/settings/settings_screen.dart';

void main() {
  testWidgets('Màn Cài đặt hiện đủ các mục chính', (tester) async {
    tester.view.physicalSize = const Size(400, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = AppStore()..loaded = true;

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: store,
        child: MaterialApp(theme: buildAppTheme(Brightness.light), home: const SettingsScreen()),
      ),
    );

    expect(find.text('Khung giờ ra vào'), findsOneWidget);
    expect(find.text('Bảng lương/giờ'), findsOneWidget);
    expect(find.text('Ngày lễ'), findsNWidgets(2)); // cột bảng lương + tiêu đề mục
    expect(find.text('Cộng trừ giờ theo giờ vào'), findsOneWidget);
    expect(find.text('Đi muộn'), findsOneWidget);
    expect(find.text('Tăng ca theo khung'), findsOneWidget);
    expect(find.text('Chấm công GPS'), findsOneWidget);
    expect(find.text('Kỳ lương'), findsOneWidget);
    expect(find.text('Khoản thu nhập / khấu trừ khác'), findsOneWidget);
    expect(find.text('Sao chép / dán cấu hình'), findsOneWidget);
  });
}
