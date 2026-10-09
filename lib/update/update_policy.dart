/// Quy tắc hộp nhắc cập nhật (thuần Dart, không phụ thuộc Flutter/Firebase), theo
/// `mockup/nhac-cap-nhat.html`:
///
/// - Có bản mới (`latest_version` trên Remote Config lớn hơn bản đang chạy): hiện hộp "Cần cập nhật
///   lên bản mới", mỗi `update_remind_hours` giờ tối đa một lần. Mỗi máy tự đếm số lần bấm "Để sau";
///   hết `update_max_skips` lượt thì hộp không tắt được, chỉ còn nút "Cập nhật" (0 là bắt buộc ngay).
///   Ra bản mới hơn nữa thì đếm lại từ đầu.
/// - `update_offline_days` ngày liền app không kết nối được Remote Config: hiện "Hãy bật mạng để kiểm
///   tra bản mới", tắt được, không chặn chấm công; sau đúng số ngày đó mới nhắc lại.
library;

int compareVersions(String a, String b) {
  final pa = a.split('.').map((s) => int.tryParse(s.split('+').first) ?? 0).toList();
  final pb = b.split('.').map((s) => int.tryParse(s.split('+').first) ?? 0).toList();
  for (var i = 0; i < 3; i++) {
    final va = i < pa.length ? pa[i] : 0;
    final vb = i < pb.length ? pb[i] : 0;
    if (va != vb) return va.compareTo(vb);
  }
  return 0;
}

/// Các tham số lấy từ Remote Config (mất mạng thì là giá trị lấy được lần gần nhất).
class UpdateParams {
  const UpdateParams({
    required this.latestVersion,
    required this.currentVersion,
    this.maxSkips = 3,
    this.remindHours = 24,
    this.offlineDays = 10,
  });

  final String latestVersion;
  final String currentVersion;
  final int maxSkips;
  final int remindHours;
  final int offlineDays;

  bool get hasUpdate => latestVersion.isNotEmpty && compareVersions(latestVersion, currentVersion) > 0;
}

/// Những gì mỗi máy tự nhớ (lưu trong máy).
class UpdateMemory {
  const UpdateMemory({
    this.version,
    this.skips = 0,
    this.lastShown,
    this.lastOnline,
    this.lastOfflineShown,
    this.firstSeen,
  });

  /// Bản mới đang được nhắc; đổi bản thì đếm lại số lần "Để sau".
  final String? version;
  final int skips;

  /// Lần gần nhất hiện hộp nhắc cập nhật.
  final DateTime? lastShown;

  /// Lần gần nhất kết nối được Remote Config.
  final DateTime? lastOnline;

  /// Lần gần nhất hiện hộp "Hãy bật mạng".
  final DateTime? lastOfflineShown;

  /// Lần đầu app kiểm tra cập nhật trên máy này (chưa từng có mạng thì tính số ngày từ đây).
  final DateTime? firstSeen;

  UpdateMemory copyWith({
    String? version,
    int? skips,
    DateTime? lastShown,
    bool clearLastShown = false,
    DateTime? lastOnline,
    DateTime? lastOfflineShown,
    DateTime? firstSeen,
  }) => UpdateMemory(
    version: version ?? this.version,
    skips: skips ?? this.skips,
    lastShown: clearLastShown ? null : (lastShown ?? this.lastShown),
    lastOnline: lastOnline ?? this.lastOnline,
    lastOfflineShown: lastOfflineShown ?? this.lastOfflineShown,
    firstSeen: firstSeen ?? this.firstSeen,
  );
}

enum UpdatePromptKind {
  none,

  /// Có bản mới, còn được bấm "Để sau".
  update,

  /// Có bản mới, đã hết lượt "Để sau": hộp không tắt được.
  forced,

  /// Lâu không kết nối được mạng.
  offline,
}

class UpdateDecision {
  const UpdateDecision(this.kind, this.memory, {this.remainingSkips = 0});

  final UpdatePromptKind kind;

  /// Bộ nhớ sau khi xét (đã đặt lại số lần "Để sau" nếu có bản mới hơn nữa). Chưa ghi nhận việc hiện
  /// hộp: gọi [markShown] khi hộp thật sự hiện lên.
  final UpdateMemory memory;
  final int remainingSkips;
}

/// Quyết định có hiện hộp nào không. [onlineAt]: lần gần nhất tải được Remote Config (null nếu chưa
/// từng tải được, hoặc không biết).
UpdateDecision decideUpdatePrompt(UpdateParams params, UpdateMemory memory, DateTime now, {DateTime? onlineAt}) {
  final known = memory.lastOnline;
  final lastOnline = onlineAt != null && (known == null || onlineAt.isAfter(known)) ? onlineAt : known;
  var m = memory.copyWith(firstSeen: memory.firstSeen ?? now, lastOnline: lastOnline);

  if (params.hasUpdate) {
    if (m.version != params.latestVersion) {
      m = UpdateMemory(
        version: params.latestVersion,
        lastOnline: m.lastOnline,
        lastOfflineShown: m.lastOfflineShown,
        firstSeen: m.firstSeen,
      );
    }
    final remaining = params.maxSkips - m.skips;
    if (remaining <= 0) return UpdateDecision(UpdatePromptKind.forced, m);
    final due = m.lastShown == null || now.difference(m.lastShown!).inMinutes >= params.remindHours * 60;
    return UpdateDecision(due ? UpdatePromptKind.update : UpdatePromptKind.none, m, remainingSkips: remaining);
  }

  if (params.offlineDays > 0) {
    final since = m.lastOnline ?? m.firstSeen!;
    final offlineLong = now.difference(since).inHours >= params.offlineDays * 24;
    final due = m.lastOfflineShown == null || now.difference(m.lastOfflineShown!).inHours >= params.offlineDays * 24;
    if (offlineLong && due) return UpdateDecision(UpdatePromptKind.offline, m);
  }
  return UpdateDecision(UpdatePromptKind.none, m);
}

/// Ghi nhận hộp đã hiện lên (để tính khoảng cách giữa hai lần nhắc).
UpdateMemory markShown(UpdateMemory m, UpdatePromptKind kind, DateTime now) => switch (kind) {
  UpdatePromptKind.update || UpdatePromptKind.forced => m.copyWith(lastShown: now),
  UpdatePromptKind.offline => m.copyWith(lastOfflineShown: now),
  UpdatePromptKind.none => m,
};

/// Người dùng bấm "Để sau" ở hộp nhắc cập nhật.
UpdateMemory markSkipped(UpdateMemory m, DateTime now) => m.copyWith(skips: m.skips + 1, lastShown: now);
