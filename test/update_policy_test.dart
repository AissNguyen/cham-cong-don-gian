import 'package:cham_cong_don_gian/update/update_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final t0 = DateTime(2026, 10, 10, 8);
  const newer = UpdateParams(latestVersion: '1.1.0', currentVersion: '1.0.0');

  test('so sánh số phiên bản', () {
    expect(compareVersions('1.1.0', '1.0.9'), 1);
    expect(compareVersions('1.0.0', '1.0.0+5'), 0);
    expect(compareVersions('1.0', '1.0.1'), -1);
  });

  test('không có bản mới, vẫn có mạng -> không hiện gì', () {
    const p = UpdateParams(latestVersion: '1.0.0', currentVersion: '1.0.0');
    expect(decideUpdatePrompt(p, const UpdateMemory(), t0, onlineAt: t0).kind, UpdatePromptKind.none);
  });

  test('có bản mới: nhắc, mỗi 24 giờ tối đa một lần, còn 3 lần Để sau', () {
    var d = decideUpdatePrompt(newer, const UpdateMemory(), t0, onlineAt: t0);
    expect(d.kind, UpdatePromptKind.update);
    expect(d.remainingSkips, 3);
    var m = markShown(d.memory, d.kind, t0);

    // Mở lại app sau 2 giờ: chưa nhắc lại.
    d = decideUpdatePrompt(newer, m, t0.add(const Duration(hours: 2)), onlineAt: t0);
    expect(d.kind, UpdatePromptKind.none);

    // Bấm Để sau, 24 giờ sau nhắc lại, còn 2 lần.
    m = markSkipped(m, t0);
    d = decideUpdatePrompt(newer, m, t0.add(const Duration(hours: 24)), onlineAt: t0);
    expect(d.kind, UpdatePromptKind.update);
    expect(d.remainingSkips, 2);
  });

  test('hết lượt Để sau -> bắt buộc, hiện ngay không chờ 24 giờ', () {
    var m = const UpdateMemory();
    for (var i = 0; i < 3; i++) {
      final d = decideUpdatePrompt(newer, m, t0.add(Duration(days: i)), onlineAt: t0);
      m = markSkipped(d.memory, t0.add(Duration(days: i)));
    }
    final d = decideUpdatePrompt(newer, m, t0.add(const Duration(days: 2, hours: 1)), onlineAt: t0);
    expect(d.kind, UpdatePromptKind.forced);
  });

  test('update_max_skips = 0 -> bắt buộc ngay', () {
    const p = UpdateParams(latestVersion: '1.1.0', currentVersion: '1.0.0', maxSkips: 0);
    expect(decideUpdatePrompt(p, const UpdateMemory(), t0, onlineAt: t0).kind, UpdatePromptKind.forced);
  });

  test('ra bản mới hơn nữa thì đếm lại số lần Để sau', () {
    var m = const UpdateMemory();
    for (var i = 0; i < 3; i++) {
      m = markSkipped(decideUpdatePrompt(newer, m, t0, onlineAt: t0).memory, t0);
    }
    const p2 = UpdateParams(latestVersion: '1.2.0', currentVersion: '1.0.0');
    final d = decideUpdatePrompt(p2, m, t0.add(const Duration(minutes: 5)), onlineAt: t0);
    expect(d.kind, UpdatePromptKind.update);
    expect(d.remainingSkips, 3);
  });

  test('10 ngày không có mạng -> nhắc bật mạng, tắt được, 10 ngày sau mới nhắc lại', () {
    const p = UpdateParams(latestVersion: '1.0.0', currentVersion: '1.0.0');
    var d = decideUpdatePrompt(p, const UpdateMemory(), t0, onlineAt: t0);
    var m = d.memory;
    d = decideUpdatePrompt(p, m, t0.add(const Duration(days: 9)));
    expect(d.kind, UpdatePromptKind.none);
    d = decideUpdatePrompt(p, m, t0.add(const Duration(days: 10)));
    expect(d.kind, UpdatePromptKind.offline);
    m = markShown(d.memory, d.kind, t0.add(const Duration(days: 10)));
    expect(decideUpdatePrompt(p, m, t0.add(const Duration(days: 15))).kind, UpdatePromptKind.none);
    expect(decideUpdatePrompt(p, m, t0.add(const Duration(days: 20))).kind, UpdatePromptKind.offline);
    // Có mạng lại thì thôi nhắc.
    expect(
      decideUpdatePrompt(p, m, t0.add(const Duration(days: 20)), onlineAt: t0.add(const Duration(days: 19))).kind,
      UpdatePromptKind.none,
    );
  });

  test('chưa từng có mạng từ lúc cài -> tính từ lần đầu kiểm tra', () {
    const p = UpdateParams(latestVersion: '', currentVersion: '1.0.0');
    final m = decideUpdatePrompt(p, const UpdateMemory(), t0).memory;
    expect(decideUpdatePrompt(p, m, t0.add(const Duration(days: 10))).kind, UpdatePromptKind.offline);
  });

  test('mất mạng nhưng giá trị lần trước báo có bản mới -> vẫn nhắc cập nhật', () {
    final d = decideUpdatePrompt(newer, UpdateMemory(firstSeen: t0, lastOnline: t0), t0.add(const Duration(days: 12)));
    expect(d.kind, UpdatePromptKind.update);
  });
}
