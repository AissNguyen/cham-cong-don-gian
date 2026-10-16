/// Ba tiếng còi app tự tạo bằng toán (không dùng âm thanh có bản quyền): còi nhà máy (lên xuống), chuông,
/// tiếng bíp. Tạo một lần thành file WAV trong thư mục riêng của app rồi dùng lại.
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../domain/models.dart';

const _rate = 22050;

/// Dữ liệu WAV (PCM 16 bit, một kênh) của một lần hú.
Uint8List buildBellWav(BellSound sound) {
  final samples = switch (sound) {
    BellSound.siren => _siren(),
    BellSound.bell => _bell(),
    BellSound.beep => _beep(),
  };
  // Chuẩn hóa về 85% biên độ tối đa.
  final peak = samples.fold<double>(0, (m, s) => math.max(m, s.abs()));
  final gain = peak > 0 ? 0.85 / peak : 1.0;
  final data = ByteData(44 + samples.length * 2);
  void ascii(int offset, String s) {
    for (var i = 0; i < s.length; i++) {
      data.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  data.setUint32(4, 36 + samples.length * 2, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little); // PCM
  data.setUint16(22, 1, Endian.little); // một kênh
  data.setUint32(24, _rate, Endian.little);
  data.setUint32(28, _rate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  data.setUint32(40, samples.length * 2, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    data.setInt16(44 + i * 2, (samples[i] * gain * 32767).round().clamp(-32768, 32767), Endian.little);
  }
  return data.buffer.asUint8List();
}

/// Làm mềm đầu và cuối để không nghe tiếng "tách".
double _fade(int i, int n, {int edge = 600}) {
  if (i < edge) return i / edge;
  if (i > n - edge) return (n - i) / edge;
  return 1;
}

/// Còi nhà máy: một tiếng hú trầm lên cao rồi xuống, có thêm họa âm cho "chói".
List<double> _siren() {
  const seconds = 2.4;
  final n = (_rate * seconds).round();
  var phase = 0.0;
  return List.generate(n, (i) {
    final t = i / _rate;
    final f = 600 + 500 * (0.5 - 0.5 * math.cos(2 * math.pi * t / seconds));
    phase += 2 * math.pi * f / _rate;
    final s = math.sin(phase) + 0.35 * math.sin(2 * phase) + 0.15 * math.sin(3 * phase);
    return s * _fade(i, n);
  });
}

/// Chuông: một tiếng ngân tắt dần, ghép từ vài họa âm.
List<double> _bell() {
  const seconds = 1.8;
  final n = (_rate * seconds).round();
  const partials = [(523.25, 1.0, 2.2), (1046.5, 0.55, 3.0), (1568.0, 0.35, 4.0), (2093.0, 0.2, 5.5), (2637.0, 0.12, 7.0)];
  return List.generate(n, (i) {
    final t = i / _rate;
    var s = 0.0;
    for (final (f, a, d) in partials) {
      s += a * math.exp(-d * t) * math.sin(2 * math.pi * f * t);
    }
    return s * _fade(i, n, edge: 110);
  });
}

/// Ba tiếng bíp ngắn.
List<double> _beep() {
  const on = 0.22, off = 0.13, count = 3;
  final onN = (_rate * on).round();
  final offN = (_rate * off).round();
  final out = <double>[];
  for (var k = 0; k < count; k++) {
    for (var i = 0; i < onN; i++) {
      final t = i / _rate;
      out.add((math.sin(2 * math.pi * 1100 * t) + 0.3 * math.sin(2 * math.pi * 2200 * t)) * _fade(i, onN, edge: 200));
    }
    out.addAll(List.filled(offN, 0.0));
  }
  return out;
}

/// Đường dẫn file WAV của tiếng còi (tạo nếu chưa có).
Future<String> bellSoundPath(BellSound sound) async {
  final dir = await getApplicationSupportDirectory();
  final file = File('${dir.path}/bell_v1_${sound.name}.wav');
  if (!await file.exists()) await file.writeAsBytes(buildBellWav(sound), flush: true);
  return file.path;
}
