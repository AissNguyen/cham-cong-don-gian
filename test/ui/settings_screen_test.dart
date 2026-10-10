import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cham_cong_don_gian/data/store.dart';
import 'package:cham_cong_don_gian/domain/models.dart';
import 'package:cham_cong_don_gian/domain/pay_period.dart';
import 'package:cham_cong_don_gian/domain/payslip.dart';
import 'package:cham_cong_don_gian/theme/app_theme.dart';
import 'package:cham_cong_don_gian/ui/format.dart';
import 'package:cham_cong_don_gian/ui/settings/number_inputs.dart';
import 'package:cham_cong_don_gian/ui/settings/payslip_card.dart';
import 'package:cham_cong_don_gian/ui/settings/settings_screen.dart';

/// Lưu file trong test không làm được (không có path_provider); bỏ qua lỗi ghi, chỉ kiểm tra giao diện.
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

/// Phần lương của kỳ hiện tại (sửa phiếu lương ở kỳ nào thì ghi riêng cho kỳ đó).
AppSettings _pay(AppStore store) =>
    store.settings.payFor(periodContaining(DateTime.now(), store.settings.payPeriod).start);

Future<AppStore> _pump(WidgetTester tester, {Widget? home, AppStore? store}) async {
  tester.view.physicalSize = const Size(420, 6000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final s = store ?? (_MemoryStore()..loaded = true);
  await tester.pumpWidget(
    ChangeNotifierProvider<AppStore>.value(
      value: s,
      child: MaterialApp(theme: buildAppTheme(Brightness.light), home: home ?? const SettingsScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return s;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Màn Cài đặt có đủ các khối theo bản mẫu, các mục cũ đã bỏ', (tester) async {
    await _pump(tester);
    expect(find.text('Công nhân'), findsOneWidget);
    expect(find.text('Công nhật'), findsOneWidget);
    expect(find.text('Phiếu lương'), findsOneWidget);
    expect(find.text('Cài đặt tính công'), findsOneWidget);
    expect(find.text('Nâng cao và cài đặt khác'), findsOneWidget);
    expect(find.text('Thưởng vượt khoán'), findsOneWidget);
    expect(find.text('Bảo hiểm (10,5%)'), findsOneWidget);
    expect(find.text('THỰC NHẬN (MẪU)'), findsOneWidget); // người mới: phiếu lương mẫu
    expect(find.text('Khoản thu nhập / khấu trừ khác'), findsNothing);
    expect(find.text('Khung giờ ra vào'), findsNothing);
    // Phần nâng cao chỉ là một dòng gợi ý, bấm mới xổ.
    expect(find.text('Sao lưu dữ liệu'), findsNothing);
    await tester.tap(find.text('Nâng cao và cài đặt khác'));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.expand_more));
    await tester.pumpAndSettle();
    expect(find.text('Sao lưu dữ liệu'), findsOneWidget);
    expect(find.text('Hiện thông báo'), findsNothing); // công tắc tắt thông báo đã bỏ, thẻ thông báo tự thu gọn được
    expect(find.text('Sao chép / dán cấu hình'), findsOneWidget);
  });

  testWidgets('Đổi Công nhân -> Công nhật phải hỏi lại; Không thì giữ nguyên', (tester) async {
    final store = await _pump(tester);
    await tester.tap(find.text('Công nhật'));
    await tester.pumpAndSettle();
    expect(find.textContaining('phần lương và cài đặt tính công cũ sẽ bị mất hết'), findsOneWidget);
    await tester.tap(find.text('Không'));
    await tester.pumpAndSettle();
    expect(store.settings.workerKind, WorkerKind.worker);

    await tester.tap(find.text('Công nhật'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đổi'));
    await tester.pumpAndSettle();
    expect(store.settings.workerKind, WorkerKind.daily);
    expect(store.settings.dailyWage, 350000);
    expect(find.text('Thưởng vượt khoán'), findsNothing);
  });

  testWidgets('Sửa phiếu lương: sửa số ngay tại dòng, ✕ hỏi lại trước khi xóa', (tester) async {
    final store = await _pump(tester);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Sửa').first);
    await tester.pumpAndSettle();
    expect(find.text('Xong'), findsOneWidget);

    // Lương cơ bản là ô đầu tiên; gõ số thì tự thêm dấu chấm.
    final base = find.byType(InlineNumberField).first;
    await tester.enterText(find.descendant(of: base, matching: find.byType(TextField)), '5000000');
    await tester.pump();
    expect(find.text('5.000.000'), findsOneWidget);
    expect(_pay(store).baseSalary, 5000000);

    // Xóa Công đoàn phí: hỏi lại, đồng ý mới xóa.
    final before = _pay(store).incomeItems.length;
    final unionRow = find.ancestor(of: find.text('Công đoàn phí'), matching: find.byType(Row)).first;
    await tester.tap(find.descendant(of: unionRow, matching: find.byIcon(Icons.close)));
    await tester.pumpAndSettle();
    expect(find.text('Bạn chắc chắn muốn xóa "Công đoàn phí" không?'), findsOneWidget);
    await tester.tap(find.text('Xóa'));
    await tester.pumpAndSettle();
    expect(_pay(store).incomeItems.length, before - 1);
    expect(_pay(store).incomeItems.any((i) => i.id == payItemUnion), isFalse);
  });

  testWidgets('Bảng "Khoản mới": không có mục Loại, % nhập được dấu phẩy', (tester) async {
    final store = await _pump(tester);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Sửa').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thêm khoản khấu trừ'));
    await tester.pumpAndSettle();
    expect(find.text('Khoản khấu trừ mới'), findsOneWidget);
    expect(find.text('Loại'), findsNothing);
    await tester.enterText(find.widgetWithText(TextField, 'Tên khoản'), 'Quỹ tổ');
    await tester.tap(find.text('% lương cơ bản'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Phần trăm (%), ví dụ 1,5'), '1.5');
    await tester.pump();
    expect(find.text('1,5'), findsOneWidget);
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    final added = _pay(store).incomeItems.last;
    expect(added.name, 'Quỹ tổ');
    expect(added.type, IncomeItemType.deduction);
    expect(added.calcMethod, IncomeCalcMethod.percentOfBaseSalary);
    expect(added.amount, 1.5);
  });

  testWidgets('Chưa có kỳ nào chốt: kỳ đang chạy hiện phiếu lương mẫu 25 ngày công, 95 giờ tăng ca', (tester) async {
    final now = DateTime(2026, 10, 2, 14, 0);
    final store = _MemoryStore()..loaded = true;
    // Có chấm công trong kỳ đang chạy cũng không làm đổi phiếu mẫu.
    store.records[dateKey(DateTime(2026, 9, 22))] = DayRecord(
      date: DateTime(2026, 9, 22),
      checkIn: DateTime(2026, 9, 22, 7),
      checkOut: DateTime(2026, 9, 22, 17),
    );
    await _pump(tester, store: store, home: Scaffold(body: ListView(children: [PayslipCard(store: store, now: now)])));
    final sample = computeSamplePayslip(
      settings: store.settings,
      period: periodContaining(now, store.settings.payPeriod),
    );
    expect(sample.days, 25);
    expect(sample.slip.workDays, 25);
    expect(sample.slip.overtimeSeconds, 95 * 3600);
    // (4.000.000 + 2.000.000 + trợ cấp 800.000) ÷ 26 × 25 + 95 × 45.000 − cơm trưa 25 × 10.000 − 420.000 − 50.000
    expect(sample.slip.net, closeTo(6800000 / 26 * 25 + 95 * 45000 - 250000 - 420000 - 50000, 0.01));
    expect((tester.widget(find.byKey(const ValueKey('payslip-net'))) as Text).data, fmtMoney(sample.slip.net));
    expect(find.text('Phiếu mẫu'), findsOneWidget);
    expect(find.text('THỰC NHẬN (MẪU)'), findsOneWidget);
    expect(find.byKey(const ValueKey('payslip-sample-note')), findsOneWidget);
    expect(find.text('Chưa chốt'), findsNothing);
  });

  testWidgets('Đã có kỳ chốt: kỳ đang chạy không hiện mẫu, không hiện số tiền nào', (tester) async {
    final now = DateTime(2026, 10, 2, 14, 0);
    final store = _MemoryStore()..loaded = true;
    // Một ngày công ở kỳ trước (đã hết) -> người dùng đã có phiếu lương được chốt.
    store.records[dateKey(DateTime(2026, 9, 1))] = DayRecord(
      date: DateTime(2026, 9, 1),
      checkIn: DateTime(2026, 9, 1, 7),
      checkOut: DateTime(2026, 9, 1, 16),
    );
    for (var d = 21; d <= 30; d++) {
      final day = DateTime(2026, 9, d);
      store.records[dateKey(day)] = DayRecord(
        date: day,
        checkIn: DateTime(2026, 9, d, 7),
        checkOut: DateTime(2026, 9, d, 17),
      );
    }
    await _pump(tester, store: store, home: Scaffold(body: ListView(children: [PayslipCard(store: store, now: now)])));
    final slip = computePayslip(
      settings: store.settings,
      period: periodContaining(now, store.settings.payPeriod),
      recordOf: store.recordFor,
      now: now,
    );
    // Kỳ 21/09–20/10 chưa hết: phiếu lương chưa tính, không hiện số tiền nào.
    expect(slip.ended, isFalse);
    expect((tester.widget(find.byKey(const ValueKey('payslip-net'))) as Text).data, '—');
    expect(find.text('Chưa chốt'), findsOneWidget);
    expect(find.text(fmtMoney(slip.net)), findsNothing);
    expect(find.text('Lương cơ bản ÷ công chuẩn × ngày công'), findsOneWidget);
    expect(find.text('Phiếu mẫu'), findsNothing);
  });

  testWidgets('Kỳ đã hết: phiếu lương tính ra đủ số, Thực nhận bằng số của bộ tính', (tester) async {
    final now = DateTime(2026, 10, 25, 9, 0); // kỳ hiện tại 21/10–20/11, lùi về kỳ 21/09–20/10 đã hết
    final store = _MemoryStore()..loaded = true;
    for (var d = 21; d <= 30; d++) {
      final day = DateTime(2026, 9, d);
      store.records[dateKey(day)] = DayRecord(
        date: day,
        checkIn: DateTime(2026, 9, d, 7),
        checkOut: DateTime(2026, 9, d, 17),
      );
    }
    await _pump(tester, store: store, home: Scaffold(body: ListView(children: [PayslipCard(store: store, now: now)])));
    await tester.tap(find.byTooltip('Kỳ trước'));
    await tester.pumpAndSettle();
    final ended = computePayslip(
      settings: store.settings,
      period: periodContaining(DateTime(2026, 10, 1), store.settings.payPeriod),
      recordOf: store.recordFor,
      now: now,
    );
    expect(ended.ended, isTrue);
    expect(ended.net, isNot(0));
    expect((tester.widget(find.byKey(const ValueKey('payslip-net'))) as Text).data, fmtMoney(ended.net));
    expect(find.text('Chưa chốt'), findsNothing);
  });

  group('Ô nhập', () {
    TextEditingValue fmt(TextInputFormatter f, String text) =>
        f.formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length)));

    test('ô tiền tự thêm dấu chấm, bỏ số 0 ở đầu', () {
      expect(fmt(const MoneyInputFormatter(), '4000000').text, '4.000.000');
      expect(fmt(const MoneyInputFormatter(), '0045000').text, '45.000');
      expect(fmt(const MoneyInputFormatter(), '4.0000.00').text, '4.000.000');
      expect(fmt(const MoneyInputFormatter(), '').text, '');
      expect(parseMoney('4.000.000'), 4000000);
    });

    test('ô phần trăm nhận dấu phẩy, dấu chấm thành dấu phẩy, chỉ một dấu', () {
      expect(fmt(const PercentInputFormatter(), '10.5').text, '10,5');
      expect(fmt(const PercentInputFormatter(), '1,5,2').text, '1,52');
      expect(fmt(const PercentInputFormatter(), 'a1b').text, '1');
      expect(parsePercent('1,5'), 1.5);
    });

    test('hiển thị tiền bỏ phần lẻ, không làm tròn lên', () {
      expect(fmtMoney(19230.77), '19.230 đ');
      expect(fmtMoney(-682884.62, unit: false), '−682.884');
    });
  });
}
