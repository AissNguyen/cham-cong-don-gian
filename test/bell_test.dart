import 'package:cham_cong_don_gian/bell/bell_sounds.dart';
import 'package:cham_cong_don_gian/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ba tiếng còi tạo ra file WAV hợp lệ, dài 1–3 giây', () {
    for (final s in BellSound.values) {
      final wav = buildBellWav(s);
      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF', reason: s.name);
      expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE', reason: s.name);
      final seconds = (wav.length - 44) / 2 / 22050;
      expect(seconds, inInclusiveRange(1, 3), reason: s.name);
    }
  });

  test('cài đặt còi lưu rồi đọc lại giữ nguyên; đổi Công nhân/Công nhật vẫn giữ còi', () {
    const bell = BellConfig(time: Clock(9, 15), repeats: 5, volume: 0.6, sound: BellSound.bell, enabled: false);
    final s = AppSettings.defaultsFor(WorkerKind.worker).copyWith(bells: [bell]);
    final back = AppSettings.fromJson(s.toJson()).bells.single;
    expect(back.time, const Clock(9, 15));
    expect(back.repeats, 5);
    expect(back.volume, 0.6);
    expect(back.sound, BellSound.bell);
    expect(back.enabled, isFalse);
    expect(AppSettings.defaultsFor(WorkerKind.daily, keep: s).bells, hasLength(1));
    expect(AppSettings.fromJson(AppSettings.defaultsFor(WorkerKind.worker).toJson()).bells, isEmpty);
  });
}
