import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cham_cong_don_gian/data/store.dart';
import 'package:cham_cong_don_gian/domain/models.dart';
import 'package:cham_cong_don_gian/onboarding/tour_controller.dart';
import 'package:cham_cong_don_gian/theme/app_theme.dart';
import 'package:cham_cong_don_gian/ui/home/home_screen.dart';

/// Lưu file trong test không làm được (không có path_provider); giữ dữ liệu trong bộ nhớ.
class _MemoryStore extends AppStore {
  _MemoryStore() {
    loaded = true;
  }

  void _put(DayRecord r) {
    records[dateKey(dateOnly(r.date))] = r;
    notifyListeners();
  }

  @override
  Future<void> punchIn(DateTime date, DateTime time) async => _put(recordFor(date).copyWith(checkIn: time, isDayOff: false));

  @override
  Future<void> punchOut(DateTime date, DateTime time) async => _put(recordFor(date).copyWith(checkOut: time));

  @override
  Future<void> setDayOff(DateTime date, bool value, {bool paid = false}) async =>
      _put(recordFor(date).copyWith(isDayOff: value, paidLeave: value && paid, clearCheckIn: value, clearCheckOut: value));

  @override
  Future<void> setLate(DateTime date, bool value) async => _put(recordFor(date).copyWith(isLate: value));

  @override
  Future<void> setNote(DateTime date, {String? note, List<String>? tags}) async =>
      _put(recordFor(date).copyWith(note: note, tags: tags));

  @override
  Future<void> restoreRecord(DateTime date, DayRecord? record) async {
    if (record == null) {
      records.remove(dateKey(dateOnly(date)));
    } else {
      records[dateKey(dateOnly(date))] = record;
    }
    notifyListeners();
  }
}

void main() {
  final today = DateTime(2026, 10, 16);
  final yesterday = DateTime(2026, 10, 15);
  late TourController tour;
  late _MemoryStore store;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    tour = TourController();
    store = _MemoryStore();
  });

  /// Gọi update như màn chính làm sau mỗi lần dựng; trả ngày được yêu cầu chọn.
  DateTime? sync([DateTime? selected]) => tour.update(store, selected ?? today);

  group('Bộ điều khiển chuyến hướng dẫn', () {
    test('Mở lần đầu bắt đầu ở bước nhập tay, mở từ "Xem lại" thì có lời mở trước', () async {
      await tour.start(store, today: today);
      expect(tour.step, TourStep.manual);
      await tour.end(store);
      expect(tour.step, isNull);
      await tour.start(store, today: today, replay: true);
      expect(tour.step, TourStep.intro);
      tour.next();
      expect(tour.step, TourStep.manual);
      tour.next();
      expect(tour.step, TourStep.checkIn);
    });

    test('Chuyển bước đúng theo từng thao tác', () async {
      await tour.start(store, today: today);
      tour.next(); // nhập tay -> bước 1
      expect(tour.step, TourStep.checkIn);

      sync();
      expect(tour.step, TourStep.checkIn, reason: 'chưa chấm thì chưa sang bước sau');
      await store.punchIn(today, DateTime(2026, 10, 16, 7));
      sync();
      expect(tour.step, TourStep.checkOut);

      await store.punchOut(today, DateTime(2026, 10, 16, 18));
      sync();
      expect(tour.step, TourStep.pickDayOff);
      expect(tour.practiceDate, yesterday);
      expect(tour.pickDayOffText, 'Giả sử hôm qua (ngày 15) bạn nghỉ. Hãy chọn ngày 15.');

      sync(today);
      expect(tour.step, TourStep.pickDayOff, reason: 'chưa chọn ngày hôm qua');
      sync(yesterday);
      expect(tour.step, TourStep.chooseDayOff);

      // Chọn nhầm ngày khác thì quay lại chọn ngày tập.
      sync(DateTime(2026, 10, 10));
      expect(tour.step, TourStep.pickDayOff);
      sync(yesterday);
      expect(tour.step, TourStep.chooseDayOff);

      await store.setDayOff(yesterday, true);
      final select = sync(yesterday);
      expect(tour.step, TourStep.lateButton);
      expect(select, today, reason: 'sau khi nghỉ tự chọn lại hôm nay');

      await store.setLate(today, true);
      sync();
      expect(tour.step, TourStep.note);

      await store.setNote(today, tags: const ['Ốm']);
      sync();
      expect(tour.step, TourStep.calendar);

      sync();
      expect(tour.step, TourStep.calendar, reason: 'bước chỉ giải thích chờ bấm Tiếp');
      tour.next();
      expect(tour.step, TourStep.stats);
      tour.next();
      expect(tour.step, TourStep.topButtons);
      tour.next();
      expect(tour.step, TourStep.done);
    });

    test('Mùng 1 thì ngày tập là ngày mai', () async {
      final first = DateTime(2026, 11, 1);
      await tour.start(store, today: first);
      expect(tour.practiceDate, DateTime(2026, 11, 2));
      expect(tour.pickDayOffText, 'Giả sử ngày mai (ngày 2) bạn nghỉ. Hãy chọn ngày 2.');
    });

    test('Kết thúc trả hai ngày tập về đúng như trước, kể cả ngày vốn không có bản ghi', () async {
      final original = DayRecord(date: today, checkIn: DateTime(2026, 10, 16, 8), isLate: true, note: 'cũ');
      store.records[dateKey(today)] = original;
      await tour.start(store, today: today);
      expect(store.records[dateKey(today)], isNull, reason: 'hai ngày tập được xóa trắng khi bắt đầu');

      await store.punchIn(today, DateTime(2026, 10, 16, 7));
      await store.setDayOff(yesterday, true, paid: true);
      expect(store.records[dateKey(yesterday)], isNotNull);

      await tour.end(store);
      expect(store.records[dateKey(today)]!.toJson(), original.toJson());
      expect(store.records.containsKey(dateKey(yesterday)), isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(tourSnapshotKey), isNull);
    });

    test('Chỉ hai ngày tập bị động tới, ngày khác giữ nguyên', () async {
      final other = DayRecord(date: DateTime(2026, 10, 3), checkIn: DateTime(2026, 10, 3, 7), checkOut: DateTime(2026, 10, 3, 16));
      store.records[dateKey(other.date)] = other;
      await tour.start(store, today: today);
      await tour.end(store);
      expect(store.records[dateKey(other.date)]!.toJson(), other.toJson());
    });

    test('App bị tắt giữa chừng: lần mở sau trả dữ liệu tập về', () async {
      final original = DayRecord(date: yesterday, checkIn: DateTime(2026, 10, 15, 8), checkOut: DateTime(2026, 10, 15, 17));
      store.records[dateKey(yesterday)] = original;
      await tour.start(store, today: today);
      await store.punchIn(today, DateTime(2026, 10, 16, 7));
      // Giả lập mở app lại: bộ điều khiển mới (không chạy chuyến), dữ liệu còn nguyên trong store.
      final reopened = TourController();
      await reopened.restoreIfInterrupted(store);
      expect(store.records[dateKey(yesterday)]!.toJson(), original.toJson());
      expect(store.records.containsKey(dateKey(today)), isFalse);
    });

    test('Khung giới thiệu chỉ tự hiện khi máy chưa từng thấy và chưa có ngày nào', () async {
      expect(await tour.shouldAutoStart(store), isTrue);
      await tour.markSeen();
      expect(await tour.shouldAutoStart(store), isFalse);

      SharedPreferences.setMockInitialValues({});
      store.records[dateKey(today)] = DayRecord(date: today, checkIn: DateTime(2026, 10, 16, 8));
      expect(await tour.shouldAutoStart(store), isFalse);
    });
  });

  group('Màn chính', () {
    Future<void> pumpHome(WidgetTester tester, AppStore s, {bool onboarding = true}) async {
      tester.view.physicalSize = const Size(420, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ChangeNotifierProvider<AppStore>.value(
          value: s,
          child: MaterialApp(theme: buildAppTheme(Brightness.light), home: HomeScreen(showOnboarding: onboarding)),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      // Màn chính có hẹn giờ 3 giây (số thu nhập thu nhỏ); chờ hết để test không báo hẹn giờ còn treo.
      await tester.pump(const Duration(seconds: 4));
    }

    testWidgets('Người mới mở app thấy khung giới thiệu, bấm Để sau thì đóng và không hiện lại', (tester) async {
      await pumpHome(tester, store);
      expect(find.text('Tính năng cơ bản'), findsOneWidget);
      expect(find.text('Bắt đầu'), findsOneWidget);
      await tester.tap(find.text('Để sau'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Tính năng cơ bản'), findsNothing);
      expect(tourController.active, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(tourSeenKey), isTrue);
    });

    testWidgets('Người đã có dữ liệu chấm công thì không hiện khung giới thiệu', (tester) async {
      final d = DateTime.now();
      store.records[dateKey(dateOnly(d))] = DayRecord(date: dateOnly(d), checkIn: DateTime(d.year, d.month, d.day, 8));
      await pumpHome(tester, store);
      expect(find.text('Tính năng cơ bản'), findsNothing);
    });

    testWidgets('Máy đã từng thấy khung giới thiệu thì không hiện lại', (tester) async {
      SharedPreferences.setMockInitialValues({tourSeenKey: true});
      await pumpHome(tester, store);
      expect(find.text('Tính năng cơ bản'), findsNothing);
    });

    testWidgets('Tắt showOnboarding (mặc định, như các test cũ) thì không hiện gì', (tester) async {
      await pumpHome(tester, store, onboarding: false);
      expect(find.text('Tính năng cơ bản'), findsNothing);
    });

    testWidgets('Bấm Bắt đầu: vào chuyến, qua bước nhập tay tới bước 1 và bước 1 sang bước 2 khi chấm vào', (tester) async {
      await pumpHome(tester, store);
      await tester.tap(find.text('Bắt đầu'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Nhập tay'), findsOneWidget);
      await tester.tap(find.text('Tiếp'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100)); // khung đầu chưa đo được chỗ sáng, khung sau mới có
      expect(find.text('Bước 1/8'), findsOneWidget);
      expect(find.text('Bấm vào đây'), findsOneWidget);

      // Chấm vào hôm nay (như người dùng giữ nút Chấm vào) -> sang bước 2.
      final now = DateTime.now();
      await store.punchIn(dateOnly(now), DateTime(now.year, now.month, now.day, 7));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Bước 2/8'), findsOneWidget);

      // "Bỏ qua" trả dữ liệu tập về (hôm nay không có bản ghi từ trước).
      await tester.tap(find.text('Bỏ qua'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tourController.active, isFalse);
      expect(store.records.containsKey(dateKey(dateOnly(now))), isFalse);
      expect(find.text('Bước 2/8'), findsNothing);
    });

    testWidgets('Đi hết chuyến: mọi bước đều khoét sáng được, "Tiếp theo" mở Cài đặt và trả dữ liệu tập', (tester) async {
      final now = DateTime.now();
      final today = dateOnly(now);
      // Hôm nay vốn đã có bản ghi (người dùng cũ xem lại hướng dẫn) -> phải được trả lại nguyên.
      final original = DayRecord(date: today, checkIn: DateTime(now.year, now.month, now.day, 8), note: 'cũ');
      store.records[dateKey(today)] = original;
      await pumpHome(tester, store, onboarding: false);
      tourController.requestReplay();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Hướng dẫn cách dùng'), findsOneWidget);
      expect(store.records.containsKey(dateKey(today)), isFalse);
      await tester.tap(find.text('Bắt đầu'));
      await tester.pump();
      await tester.tap(find.text('Tiếp')); // nhập tay
      await tester.pump();

      Future<void> settle() async {
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      }

      Future<void> expectStep(String label, {bool hasLabel = true}) async {
        await settle();
        expect(find.text(label), findsOneWidget);
        expect(find.text('Bấm vào đây'), hasLabel ? findsOneWidget : findsNothing, reason: label);
      }

      await expectStep('Bước 1/8');
      await store.punchIn(today, DateTime(now.year, now.month, now.day, 7));
      await expectStep('Bước 2/8');
      await store.punchOut(today, DateTime(now.year, now.month, now.day, 18));
      await expectStep('Bước 3/8');
      final practice = tourController.practiceDate!;
      expect(find.textContaining('(ngày ${practice.day})'), findsOneWidget);
      // Chạm đúng ô được khoét sáng trên lịch.
      await tester.tap(find.text('${practice.day}').first);
      await expectStep('Bước 3/8');
      expect(find.textContaining('Bấm nút Ngày nghỉ'), findsOneWidget);
      await store.setDayOff(practice, true);
      await expectStep('Bước 4/8');
      await store.setLate(today, true);
      await expectStep('Bước 5/8');
      await store.setNote(today, note: 'ốm');
      await expectStep('Bước 6/8', hasLabel: false);
      await tester.tap(find.text('Tiếp'));
      await expectStep('Bước 7/8', hasLabel: false);
      await tester.tap(find.text('Tiếp'));
      await expectStep('Bước 8/8', hasLabel: false);
      await tester.tap(find.text('Tiếp'));
      await settle();
      expect(find.text('Vậy là cơ bản đã xong'), findsOneWidget);
      await tester.tap(find.text('Tiếp theo'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(tourController.active, isFalse);
      expect(find.text('Cài đặt'), findsWidgets);
      expect(store.records[dateKey(today)]!.toJson(), original.toJson());
      expect(store.records.containsKey(dateKey(practice)), isFalse);
    });
  });
}
