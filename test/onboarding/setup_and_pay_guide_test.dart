import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cham_cong_don_gian/data/store.dart';
import 'package:cham_cong_don_gian/domain/config_share.dart';
import 'package:cham_cong_don_gian/domain/leave.dart';
import 'package:cham_cong_don_gian/domain/models.dart';
import 'package:cham_cong_don_gian/onboarding/setup_dialog.dart';
import 'package:cham_cong_don_gian/theme/app_theme.dart';
import 'package:cham_cong_don_gian/ui/settings/settings_screen.dart';

/// Lưu file trong test không làm được; giữ cài đặt trong bộ nhớ.
class _MemoryStore extends AppStore {
  @override
  Future<void> updateSettings(AppSettings Function(AppSettings) update) async {
    settings = update(settings);
    notifyListeners();
  }

  @override
  Future<void> replaceSettings(AppSettings newSettings) async {
    settings = newSettings;
    notifyListeners();
  }
}

Future<void> _pump(WidgetTester tester, AppStore store, Widget home) async {
  tester.view.physicalSize = const Size(420, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider<AppStore>.value(
      value: store,
      child: MaterialApp(theme: buildAppTheme(Brightness.light), home: home),
    ),
  );
  await tester.pump();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Câu hỏi lần đầu (công nhân): kỳ lương, lấy tăng ca bù, ngày phép được lưu', (tester) async {
    final store = _MemoryStore()..loaded = true;
    await _pump(
      tester,
      store,
      Builder(
        builder: (context) => TextButton(onPressed: () => showSetupDialog(context, store), child: const Text('mở')),
      ),
    );
    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();
    expect(find.text('Câu hỏi 1/4'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('setup-next'))); // giữ Công nhân
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('setup-start-day')), '26');
    await tester.tap(find.byKey(const ValueKey('setup-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('setup-offset-company')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('setup-next')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('setup-leave')), '3');
    await tester.tap(find.text('Xong'));
    await tester.pumpAndSettle();

    final s = store.settings;
    expect(s.payPeriod.monthlyStartDay, 26);
    expect(s.offsetMode, OvertimeOffsetMode.company);
    expect(leaveBalanceFor(s, store.recordFor, DateTime.now()), 3);
    expect(find.text('Lấy tăng ca bù'), findsNothing);
  });

  testWidgets('Câu hỏi lần đầu: chọn Công nhật thì đổi loại và chỉ hỏi kỳ lương', (tester) async {
    final store = _MemoryStore()..loaded = true;
    await _pump(
      tester,
      store,
      Builder(
        builder: (context) => TextButton(onPressed: () => showSetupDialog(context, store), child: const Text('mở')),
      ),
    );
    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('setup-daily')));
    await tester.pump();
    expect(find.text('Câu hỏi 1/2'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('setup-next')));
    await tester.pumpAndSettle();
    expect(store.settings.workerKind, WorkerKind.daily);
    expect(find.text('Kỳ lương'), findsOneWidget);
    await tester.tap(find.text('Xong'));
    await tester.pumpAndSettle();
    expect(find.text('Kỳ lương'), findsNothing);
  });

  testWidgets('Hướng dẫn lương: lời mở, 4 bước sáng từng chỗ (công nhân), lời kết', (tester) async {
    final store = _MemoryStore()..loaded = true;
    await _pump(tester, store, const SettingsScreen(payGuide: true));
    // Nhãn ngón tay nhấp nháy mãi nên chờ theo thời gian, không chờ "đứng yên".
    Future<void> settle() async {
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    await settle();
    expect(find.text('Hướng dẫn nhập phiếu lương'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pay-guide-next')));
    await settle();
    for (var i = 1; i <= 4; i++) {
      expect(find.text('Bước $i/4'), findsOneWidget);
      expect(find.text('Nhập vào đây'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('pay-guide-next')));
      await settle();
    }
    expect(find.text('Đã nhập xong phiếu lương'), findsOneWidget);
  });

  testWidgets('Hướng dẫn lương: dán cấu hình của đồng nghiệp, chỉ hỏi lại lương cơ bản, rồi tới lời kết', (tester) async {
    final store = _MemoryStore()..loaded = true;
    final colleague = AppSettings.defaultsFor(WorkerKind.worker).copyWith(
      baseSalary: 5000000,
      payPeriod: const PayPeriodConfig(monthlyStartDay: 26),
      offsetMode: OvertimeOffsetMode.company,
    );
    // Bộ nhớ tạm (clipboard) trong test: trống.
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') return <String, dynamic>{'text': ''};
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await _pump(tester, store, const SettingsScreen(payGuide: true));
    Future<void> settle() async {
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    await settle();
    await tester.tap(find.byKey(const ValueKey('pay-guide-paste')));
    await settle();
    await tester.enterText(find.byKey(const ValueKey('pay-guide-paste-input')), 'không phải cấu hình');
    await tester.tap(find.byKey(const ValueKey('pay-guide-paste-ok')));
    await settle();
    expect(find.textContaining('Không phải cấu hình của app'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('pay-guide-paste-input')), encodeSettings(colleague));
    await tester.tap(find.byKey(const ValueKey('pay-guide-paste-ok')));
    await settle();
    expect(find.text('Lương cơ bản của bạn'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('pay-guide-salary')), '4500000');
    await tester.tap(find.byKey(const ValueKey('pay-guide-salary-ok')));
    await settle();
    expect(store.settings.baseSalary, 4500000);
    expect(store.settings.payPeriod.monthlyStartDay, 26);
    expect(store.settings.offsetMode, OvertimeOffsetMode.company);
    expect(find.text('Đã nhập xong phiếu lương'), findsOneWidget);
  });
}
