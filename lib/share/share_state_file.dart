/// Đọc/ghi trạng thái dùng thử + mã giới thiệu (`share_state.json`). Để riêng một file, không gộp
/// vào file dữ liệu chấm công, vì AppStore ghi đè cả file đó mỗi lần lưu. Dùng được từ tiến trình
/// chính lẫn các tiến trình nền (widget, GPS) — nơi không có Firebase.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';

import '../domain/share_gate.dart';

Future<File> _shareStateFile() async {
  final dir = await getApplicationDocumentsDirectory();
  return File('${dir.path}/share_state.json');
}

Future<ShareState> readShareState() async {
  if (kIsWeb) return const ShareState();
  try {
    final file = await _shareStateFile();
    if (!await file.exists()) return const ShareState();
    return ShareState.fromJson(jsonDecode(await file.readAsString()) as Map<String, dynamic>);
  } catch (_) {
    return const ShareState();
  }
}

Future<void> writeShareState(ShareState state) async {
  if (kIsWeb) return;
  final file = await _shareStateFile();
  await file.writeAsString(jsonEncode(state.toJson()));
}

/// Đọc lại file rồi mới sửa và ghi, để không đè mất thay đổi tiến trình khác vừa ghi.
Future<ShareState> updateShareState(ShareState Function(ShareState) update) async {
  final next = update(await readShareState());
  await writeShareState(next);
  return next;
}

// ---- Đếm lượt dùng (mở app, bấm widget, GPS tự chấm) ----
// Tiến trình nền không có Firebase nên chỉ cộng dồn vào file `usage_pending.json`; tiến trình chính
// gửi lên máy chủ ở lần đồng bộ kế tiếp rồi trừ phần đã gửi (xem ShareController.sync).

const usageAppOpens = 'appOpens';
const usageWidgetUses = 'widgetUses';
const usageGpsUses = 'gpsUses';
const usageFields = [usageAppOpens, usageWidgetUses, usageGpsUses];

/// Hai lần mở app cách nhau dưới khoảng này chỉ tính 1 lượt (quay lại từ khung chia sẻ, hộp xin quyền...).
const _appOpenGap = Duration(minutes: 30);

Future<File> _usageFile() async {
  final dir = await getApplicationDocumentsDirectory();
  return File('${dir.path}/usage_pending.json');
}

Future<Map<String, dynamic>> _readUsage() async {
  try {
    final file = await _usageFile();
    if (!await file.exists()) return {};
    return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  } catch (_) {
    return {};
  }
}

/// Cộng 1 lượt cho [field]. Không bao giờ ném lỗi — thống kê không được làm hỏng việc chấm công.
Future<void> recordUsage(String field) async {
  if (kIsWeb) return;
  try {
    final json = await _readUsage();
    if (field == usageAppOpens) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final last = json['lastOpenMs'] as int? ?? 0;
      json['lastOpenMs'] = now;
      if (now - last < _appOpenGap.inMilliseconds) {
        await (await _usageFile()).writeAsString(jsonEncode(json));
        return;
      }
    }
    json[field] = (json[field] as int? ?? 0) + 1;
    await (await _usageFile()).writeAsString(jsonEncode(json));
  } catch (_) {
    // Bỏ qua.
  }
}

/// Số lượt đang chờ gửi lên máy chủ (chỉ các mục > 0).
Future<Map<String, int>> readPendingUsage() async {
  final json = await _readUsage();
  return {
    for (final f in usageFields)
      if ((json[f] as int? ?? 0) > 0) f: json[f] as int,
  };
}

/// Trừ phần đã gửi — đọc lại file trước để giữ các lượt tiến trình nền vừa cộng thêm trong lúc gửi.
Future<void> clearSentUsage(Map<String, int> sent) async {
  final json = await _readUsage();
  sent.forEach((f, n) {
    final left = (json[f] as int? ?? 0) - n;
    json[f] = left > 0 ? left : 0;
  });
  await (await _usageFile()).writeAsString(jsonEncode(json));
}

/// GPS/widget có được chạy lúc này không. Lỗi đọc file thì cho chạy — không để việc giới hạn làm
/// hỏng việc chấm công.
Future<bool> autoFeatureAllowed() async {
  try {
    return autoAllowed(await readShareState(), DateTime.now());
  } catch (_) {
    return true;
  }
}

/// Ghi nhận hôm nay có dùng GPS tự chấm hoặc widget.
Future<void> recordAutoUse() async {
  try {
    await updateShareState((s) => withAutoUse(s, DateTime.now()));
  } catch (_) {
    // Bỏ qua — lần dùng sau ghi lại.
  }
}
