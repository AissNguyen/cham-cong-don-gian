import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:cham_cong_don_gian/data/store.dart';
import 'package:cham_cong_don_gian/domain/models.dart';
import 'package:cham_cong_don_gian/domain/pay_period.dart';
import 'package:cham_cong_don_gian/domain/payslip.dart';
import 'package:cham_cong_don_gian/theme/app_theme.dart';
import 'package:cham_cong_don_gian/ui/format.dart';
import 'package:cham_cong_don_gian/ui/home/home_screen.dart';

DayRecord _shift(DateTime d, int inH, int outH, {int inM = 0, int outM = 0, bool late = false}) => DayRecord(
  date: d,
  checkIn: DateTime(d.year, d.month, d.day, inH, inM),
  checkOut: DateTime(d.year, d.month, d.day, outH, outM),
  isLate: late,
);

Future<AppStore> _pumpHome(WidgetTester tester, {required AppSettings settings, required List<DayRecord> records, required DateTime now}) async {
  // Màn hình cao hơn viewport mặc định để không cần cuộn khi kiểm tra các nút phía dưới.
  tester.view.physicalSize = const Size(400, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final store = AppStore()..loaded = true; // bỏ qua load() vì không có path_provider trong test.
  store.settings = settings;
  for (final r in records) {
    store.records[dateKey(r.date)] = r;
  }
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: store,
      child: MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: HomeScreen(clock: () => now),
      ),
    ),
  );
  // 3 giây đầu số "Hôm nay" hiện to; vượt qua khoảng đó để kiểm tra trạng thái bình thường.
  await tester.pump(const Duration(seconds: 4));
  return store;
}

String _text(WidgetTester tester, String key) => (tester.widget(find.byKey(ValueKey(key))) as Text).data!;

void main() {
  testWidgets('Màn chính hiện nút cài đặt, thực nhận tạm tính, lịch và các nút thao tác', (tester) async {
    await _pumpHome(tester, settings: AppSettings.defaultsFor(WorkerKind.worker), records: const [], now: DateTime.now());

    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    expect(find.textContaining('Thực nhận tạm tính'), findsOneWidget);
    expect(find.text('Giờ công'), findsOneWidget);
    expect(find.text('Chấm vào'), findsOneWidget);
    expect(find.text('Chấm ra'), findsOneWidget);
    expect(find.text('Ngày nghỉ'), findsNWidgets(2)); // nhãn thống kê + nhãn nút
    expect(find.text('Đi muộn'), findsOneWidget);
    expect(find.text('Ghi chú'), findsOneWidget);
    expect(find.textContaining('Thống kê thu nhập theo kỳ'), findsOneWidget);
  });

  group('Số trên thẻ thu nhập ở màn chính = Thực nhận của phiếu lương', () {
    // Kỳ 21/09–20/10/2026 của Công nhân. 27/09 là chủ nhật; 30/09 đặt làm ngày lễ.
    final holiday = DateTime(2026, 9, 30);
    final worker = AppSettings.defaultsFor(WorkerKind.worker).copyWith(
      holidays: [Holiday(date: holiday, name: 'Lễ thử')],
      incomeItems: [
        for (final i in AppSettings.defaultsFor(WorkerKind.worker).incomeItems)
          i.id == payItemAllowance ? i.copyWith(amount: 500000) : i,
      ],
    );
    final records = [
      _shift(DateTime(2026, 9, 21), 7, 18), // tăng ca 2h
      _shift(DateTime(2026, 9, 22), 7, 16, late: true), // đi muộn
      _shift(DateTime(2026, 9, 23), 7, 16),
      _shift(DateTime(2026, 9, 27), 7, 16), // chủ nhật
      _shift(holiday, 7, 12), // ngày lễ, về trước 12:30
      for (var d = 1; d <= 19; d++)
        if (DateTime(2026, 10, d).weekday != DateTime.sunday) _shift(DateTime(2026, 10, d), 7, 16, late: d == 5),
    ];

    Future<void> check(WidgetTester tester, AppSettings settings, List<DayRecord> recs, DateTime now) async {
      final store = await _pumpHome(tester, settings: settings, records: recs, now: now);
      final slip = computePayslip(
        settings: store.settings,
        period: periodContaining(now, store.settings.payPeriod),
        recordOf: store.recordFor,
        now: now,
      );
      expect(_text(tester, 'home-net'), fmtMoney(slip.net));
      expect(_text(tester, 'home-today'), fmtMoney(slip.amountOn(now)));
      expect(slip.net, isNot(0));
    }

    testWidgets('giữa kỳ, có tăng ca, chủ nhật, ngày lễ và đi muộn', (tester) async {
      await check(tester, worker, records.where((r) => r.date.isBefore(DateTime(2026, 10, 2))).toList(), DateTime(2026, 10, 2, 6, 0));
    });

    testWidgets('giữa ca (ca đang mở, sau 12:30)', (tester) async {
      final now = DateTime(2026, 10, 2, 14, 15, 30);
      final recs = [
        ...records.where((r) => r.date.isBefore(DateTime(2026, 10, 2))),
        DayRecord(date: DateTime(2026, 10, 2), checkIn: DateTime(2026, 10, 2, 7, 0)),
      ];
      await check(tester, worker, recs, now);
    });

    testWidgets('ngày chốt kỳ (20/10), ca đang mở', (tester) async {
      final now = DateTime(2026, 10, 20, 9, 30);
      final recs = [...records, DayRecord(date: DateTime(2026, 10, 20), checkIn: DateTime(2026, 10, 20, 7, 0))];
      await check(tester, worker, recs, now);
    });

    testWidgets('đi muộn trừ tiền', (tester) async {
      final s = worker.copyWith(lateRule: worker.lateRule.copyWith(unit: LateUnit.money, amount: 20000));
      await check(tester, s, records, DateTime(2026, 10, 19, 20, 0));
    });

    testWidgets('Công nhật, kỳ 1–15', (tester) async {
      final daily = AppSettings.defaultsFor(WorkerKind.daily).copyWith(holidays: [Holiday(date: holiday, name: 'Lễ')]);
      final recs = records.where((r) => r.date.month == 10 && r.date.day <= 9).toList();
      await check(tester, daily, recs, DateTime(2026, 10, 9, 17, 0));
    });
  });
}
