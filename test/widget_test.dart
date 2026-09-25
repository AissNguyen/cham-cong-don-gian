import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:cham_cong_don_gian/data/store.dart';
import 'package:cham_cong_don_gian/theme/app_theme.dart';
import 'package:cham_cong_don_gian/ui/home/home_screen.dart';

void main() {
  testWidgets('Màn chính hiện nút cài đặt, thu nhập tạm tính, lịch và các nút thao tác', (tester) async {
    // Màn hình cao hơn viewport mặc định để không cần cuộn khi kiểm tra các nút phía dưới.
    tester.view.physicalSize = const Size(400, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = AppStore()..loaded = true; // bỏ qua load() vì không có path_provider trong test.

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: store,
        child: MaterialApp(theme: buildAppTheme(Brightness.light), home: const HomeScreen()),
      ),
    );

    // 3 giây đầu số "Hôm nay" hiện to (số chạy theo giây); vượt qua khoảng đó để kiểm tra
    // trạng thái bình thường.
    await tester.pump(const Duration(seconds: 4));

    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    expect(find.textContaining('Thu nhập tạm tính'), findsOneWidget);
    expect(find.text('Giờ công'), findsOneWidget);
    expect(find.text('Chấm vào'), findsOneWidget);
    expect(find.text('Chấm ra'), findsOneWidget);
    expect(find.text('Ngày nghỉ'), findsNWidgets(2)); // nhãn thống kê + nhãn nút
    expect(find.text('Đi muộn'), findsOneWidget);
    expect(find.text('Ghi chú'), findsOneWidget);
    expect(find.textContaining('Thống kê thu nhập theo kỳ'), findsOneWidget);
  });
}
