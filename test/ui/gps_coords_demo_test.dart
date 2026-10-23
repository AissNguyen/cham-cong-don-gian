import 'package:cham_cong_don_gian/ui/settings/help_screen.dart';
import 'package:cham_cong_don_gian/ui/settings/settings_blocks.dart';
import 'package:cham_cong_don_gian/ui/widgets/gps_coords_demo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bước theo thời gian: có bước phóng to bản đồ trước khi giữ ngón tay', () {
    expect(gpsDemoSteps.length, 7);
    expect(gpsDemoStepAt(0), 0);
    expect(gpsDemoSteps[gpsDemoStepAt(2)].text, contains('Phóng to'));
    expect(gpsDemoSteps[gpsDemoStepAt(5)].text, contains('chỗ chấm công'));
    expect(gpsDemoStepAt(22), 6);
  });

  test('tọa độ ví dụ dán được vào ô Nhập tọa độ', () {
    expect(parseLatLng(gpsExampleCoords), (10.7724983, 106.6980146));
  });

  testWidgets('hình động chạy qua các bước, tạm dừng được', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Center(child: GpsCoordsDemo()))));
    final caption = find.byKey(const ValueKey('gps-demo-caption'));
    expect(tester.widget<Text>(caption).data, startsWith('1/7'));

    await tester.pump(const Duration(seconds: 2));
    expect(tester.widget<Text>(caption).data, startsWith('2/7'));
    await tester.pump(const Duration(seconds: 3));
    expect(tester.widget<Text>(caption).data, startsWith('3/7'));
    // Chạy hết một vòng không lỗi vẽ (tràn chữ, v.v.).
    for (var i = 0; i < 22; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('gps-demo-play')));
    await tester.pump();
    final paused = tester.widget<Text>(caption).data;
    await tester.pump(const Duration(seconds: 5));
    expect(tester.widget<Text>(caption).data, paused);
    expect(find.text('Chạy'), findsOneWidget);
  });

  testWidgets('màn Hướng dẫn mở được hình động lấy tọa độ', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HelpScreen()));
    await tester.tap(find.byKey(const ValueKey('help-gps-demo')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(GpsCoordsDemo), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('gps-demo-close')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(GpsCoordsDemo), findsNothing);
  });
}
