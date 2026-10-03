import 'package:flutter_test/flutter_test.dart';

import 'package:cham_cong_don_gian/domain/share_gate.dart';

void main() {
  final day1 = DateTime(2026, 10, 1, 7);
  List<String> days(int n) => [for (var i = 1; i <= n; i++) '2026-09-${i.toString().padLeft(2, '0')}'];

  // Tổng số máy đã vượt X = 50 nên giới hạn đang áp dụng.
  const on = ShareState(totalCount: 51);
  ShareState used(int n, {bool unlocked = false, int trialDays = 10}) =>
      ShareState(totalCount: 51, autoUseDays: days(n), unlocked: unlocked, trialDays: trialDays);

  group('Khi nào giới hạn bắt đầu áp dụng (X máy)', () {
    test('chưa hỏi được máy chủ lần nào thì chưa áp dụng', () {
      expect(gateOn(const ShareState()), isFalse);
      expect(autoAllowed(ShareState(autoUseDays: days(30)), day1), isTrue);
    });

    test('đủ đúng 50 máy vẫn chưa áp dụng, máy thứ 51 cài thì áp dụng cho mọi máy', () {
      expect(gateOn(const ShareState(totalCount: 50)), isFalse);
      expect(gateOn(const ShareState(totalCount: 51)), isTrue);
      // Kể cả máy số 1: đã dùng quá Y ngày thì bị chặn ngay khi vượt X.
      final first = ShareState(seq: 1, totalCount: 51, autoUseDays: days(20));
      expect(autoAllowed(first, day1), isFalse);
    });

    test('chưa vượt X: dùng tự do, không ô nhập, không nút lấy mã, tin nhắn chỉ có link', () {
      final free = ShareState(seq: 12, totalCount: 30, autoUseDays: days(25), code: '654321');
      expect(autoAllowed(free, day1), isTrue);
      expect(entryOpen(free, day1), isFalse);
      expect(canTakeCode(const ShareState(totalCount: 30)), isFalse);
      expect(shouldPromptReferral(const ShareState(seq: 12, totalCount: 30), day1), isFalse);
      expect(shareMessage(free), isNot(contains('654321')));
    });

    test('X đổi được từ máy chủ', () {
      expect(gateOn(const ShareState(totalCount: 80, freeUsers: 100)), isFalse);
      expect(gateOn(const ShareState(totalCount: 21, freeUsers: 20)), isTrue);
    });

    test('máy chủ đặt Y = 0 là tắt hẳn', () {
      final off = ShareState(enabled: false, totalCount: 500, autoUseDays: days(30));
      expect(gateOn(off), isFalse);
      expect(autoAllowed(off, day1), isTrue);
      expect(entryOpen(off, day1), isFalse);
    });
  });

  group('Dùng thử chấm công tự động (Y ngày)', () {
    test('chưa dùng ngày nào thì được dùng, còn đủ số ngày', () {
      expect(autoAllowed(on, day1), isTrue);
      expect(trialDaysLeft(on), 10);
    });

    test('mỗi ngày chỉ tính 1 lần dù dùng nhiều lần', () {
      var s = withAutoUse(on, day1);
      s = withAutoUse(s, day1.add(const Duration(hours: 9)));
      expect(s.autoUseDays, ['2026-10-01']);
      s = withAutoUse(s, day1.add(const Duration(days: 1)));
      expect(s.autoUseDays, ['2026-10-01', '2026-10-02']);
    });

    test('ngày dùng được đếm từ đầu, kể cả khi chưa vượt X', () {
      expect(withAutoUse(const ShareState(totalCount: 3), day1).autoUseDays, ['2026-10-01']);
      expect(withAutoUse(const ShareState(), day1).autoUseDays, ['2026-10-01']);
    });

    test('ngày không dùng thì không bị tính', () {
      // Dùng 9 ngày trong tháng 9, sang tháng 10 vẫn còn 1 ngày.
      expect(autoAllowed(used(9), day1), isTrue);
      expect(trialDaysLeft(used(9)), 1);
    });

    test('ngày dùng thử cuối được dùng hết ngày, hôm sau mới khóa', () {
      final lastDay = withAutoUse(used(9), day1);
      expect(lastDay.autoUseDays.length, 10);
      expect(autoAllowed(lastDay, day1.add(const Duration(hours: 10))), isTrue);
      expect(autoAllowed(lastDay, day1.add(const Duration(days: 1))), isFalse);
      expect(trialDaysLeft(lastDay), 0);
    });

    test('đã mở khóa thì dùng lâu dài', () {
      expect(autoAllowed(used(30, unlocked: true), day1), isTrue);
    });

    test('Y đổi được từ máy chủ', () {
      expect(autoAllowed(used(5, trialDays: 5), day1), isFalse);
      expect(autoAllowed(used(10, trialDays: 15), day1), isTrue);
    });
  });

  group('Ô nhập mã và nút lấy mã', () {
    final firstSeen = DateTime(2026, 10, 1, 8);

    test('máy chưa làm gì: có cả ô nhập lẫn nút lấy mã, không có thời hạn', () {
      expect(entryOpen(on, day1), isTrue);
      expect(entryOpen(on, day1.add(const Duration(days: 400))), isTrue);
      expect(canTakeCode(on), isTrue);
    });

    test('lấy mã rồi thì mất ô nhập', () {
      final s = on.copyWith(code: '111222');
      expect(entryOpen(s, day1), isFalse);
      expect(canTakeCode(s), isFalse);
    });

    test('nhập mã rồi thì ô nhập biến mất nhưng vẫn lấy được mã của mình', () {
      final s = on.copyWith(redeemedCode: '123456');
      expect(entryOpen(s, day1), isFalse);
      expect(canTakeCode(s), isTrue);
    });

    test('đã mở khóa thì không còn nút lấy mã', () {
      expect(canTakeCode(on.copyWith(unlocked: true)), isFalse);
    });

    test('máy chủ đặt thời hạn thì ô nhập chỉ hiện trong hạn kể từ lúc cài', () {
      final s = ShareState(totalCount: 51, firstSeen: firstSeen, entryHours: 24);
      expect(entryOpen(s, firstSeen.add(const Duration(hours: 23))), isTrue);
      expect(entryOpen(s, firstSeen.add(const Duration(hours: 25))), isFalse);
      // Có thời hạn mà chưa biết lúc cài (chưa có mạng) thì chưa hiện.
      expect(entryOpen(const ShareState(totalCount: 51, entryHours: 24), firstSeen), isFalse);
    });

    test('hộp hỏi "Ai giới thiệu bạn?" chỉ tự bật cho máy cài sau khi đã đủ X máy, và chỉ 1 lần', () {
      expect(shouldPromptReferral(const ShareState(seq: 51, totalCount: 51), day1), isTrue);
      expect(shouldPromptReferral(const ShareState(seq: 7, totalCount: 51), day1), isFalse);
      expect(shouldPromptReferral(const ShareState(seq: 51, totalCount: 51, entryPromptShown: true), day1), isFalse);
    });
  });

  group('Mã và tin nhắn chia sẻ', () {
    test('mã phải đúng 6 chữ số', () {
      expect(isValidCode('123456'), isTrue);
      expect(isValidCode('12345'), isFalse);
      expect(isValidCode('1234567'), isFalse);
      expect(isValidCode('12a456'), isFalse);
    });

    test('đang cần mở khóa thì tin nhắn kèm mã, mở rồi chỉ còn link', () {
      final locked = on.copyWith(code: '654321');
      expect(shareMessage(locked), contains('654321'));
      expect(shareMessage(locked), contains(defaultShareUrl));
      final unlocked = locked.copyWith(unlocked: true);
      expect(shareMessage(unlocked), isNot(contains('654321')));
      expect(shareMessage(unlocked), contains(defaultShareUrl));
      // Chưa lấy mã thì cũng chỉ có link.
      expect(shareMessage(on), isNot(contains('mã')));
    });

    test('lưu và đọc lại giữ nguyên trạng thái', () {
      final s = ShareState(
        enabled: false,
        seq: 73,
        totalCount: 120,
        freeUsers: 40,
        autoUseDays: const ['2026-10-01'],
        unlocked: true,
        trialDays: 7,
        entryHours: 12,
        shareUrl: 'https://example.com',
        code: '111222',
        firstSeen: DateTime(2026, 10, 1, 8),
        redeemedCode: '333444',
        entryPromptShown: true,
        lockNoticeShown: true,
      );
      final back = ShareState.fromJson(s.toJson());
      expect(back.toJson(), s.toJson());
    });
  });
}
