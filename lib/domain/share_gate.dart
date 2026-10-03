/// Giới hạn dùng thử chấm công tự động (GPS + widget) và mở khóa bằng mã giới thiệu — phần quy tắc
/// thuần Dart, tách khỏi Firebase/file để kiểm tra được bằng test.
///
/// Quy tắc (X = [ShareState.freeUsers], Y = [ShareState.trialDays], đều chỉnh từ Remote Config):
/// - Tổng số máy dùng app chưa vượt X: không giới hạn gì, không hiện mã hay ô nhập — app trông
///   hoàn toàn miễn phí. Số "ngày dùng" (ngày có ít nhất 1 lần GPS tự chấm hoặc bấm widget) vẫn
///   được đếm âm thầm từ đầu.
/// - Vượt X: máy nào đã dùng quá Y ngày thì GPS/widget tạm dừng (chấm tay vẫn bình thường) cho tới
///   khi có 1 máy khác nhập mã của máy này — khi đó mở lâu dài, phần mã ẩn đi.
/// - Mỗi máy có ô nhập mã người giới thiệu và nút "Lấy mã". Lấy mã rồi thì mất ô nhập, nên không
///   thể có hai (hay một vòng nhiều) máy mở khóa lẫn nhau; nhập mã trước rồi lấy mã sau thì được.
library;

import 'models.dart';

const defaultTrialDays = 10;
const defaultFreeUsers = 50;

/// 0 = ô nhập mã không có thời hạn.
const defaultEntryHours = 0;
const defaultShareUrl = 'https://cham-cong-don-gian.web.app';

class ShareState {
  const ShareState({
    this.enabled = true,
    this.seq,
    this.totalCount,
    this.freeUsers = defaultFreeUsers,
    this.autoUseDays = const [],
    this.unlocked = false,
    this.trialDays = defaultTrialDays,
    this.entryHours = defaultEntryHours,
    this.shareUrl = defaultShareUrl,
    this.code,
    this.firstSeen,
    this.redeemedCode,
    this.entryPromptShown = false,
    this.lockNoticeShown = false,
  });

  /// Công tắc tắt hẳn: đặt Remote Config `share_trial_days` = 0 thì cả tính năng tắt và ẩn.
  final bool enabled;

  /// Số thứ tự máy chủ cấp cho máy này (máy thứ mấy dùng app).
  final int? seq;

  /// Tổng số máy đã dùng app, theo lần gần nhất hỏi được máy chủ (null = chưa hỏi được lần nào).
  final int? totalCount;

  /// X: tổng số máy vượt con số này thì giới hạn mới bắt đầu áp dụng.
  final int freeUsers;

  /// Các ngày (khóa [dateKey]) đã dùng GPS tự chấm hoặc widget.
  final List<String> autoUseDays;

  /// Đã có máy khác nhập mã của máy này.
  final bool unlocked;

  /// Y (số ngày dùng thử), thời hạn ô nhập mã (giờ, 0 = không hạn) và link chia sẻ — lấy từ Remote
  /// Config, lưu lại để tiến trình nền (không có Firebase) và lúc mất mạng vẫn đọc được.
  final int trialDays;
  final int entryHours;
  final String shareUrl;

  /// Mã giới thiệu 6 chữ số của máy này — chỉ có sau khi người dùng bấm "Lấy mã".
  final String? code;

  /// Lúc máy chủ thấy máy này lần đầu — mốc tính hạn ô nhập mã khi [entryHours] > 0.
  final DateTime? firstSeen;

  /// Mã của người giới thiệu mà máy này đã nhập (mỗi máy chỉ nhập 1 lần).
  final String? redeemedCode;

  final bool entryPromptShown;
  final bool lockNoticeShown;

  ShareState copyWith({
    bool? enabled,
    int? seq,
    int? totalCount,
    int? freeUsers,
    List<String>? autoUseDays,
    bool? unlocked,
    int? trialDays,
    int? entryHours,
    String? shareUrl,
    String? code,
    DateTime? firstSeen,
    String? redeemedCode,
    bool? entryPromptShown,
    bool? lockNoticeShown,
  }) => ShareState(
    enabled: enabled ?? this.enabled,
    seq: seq ?? this.seq,
    totalCount: totalCount ?? this.totalCount,
    freeUsers: freeUsers ?? this.freeUsers,
    autoUseDays: autoUseDays ?? this.autoUseDays,
    unlocked: unlocked ?? this.unlocked,
    trialDays: trialDays ?? this.trialDays,
    entryHours: entryHours ?? this.entryHours,
    shareUrl: shareUrl ?? this.shareUrl,
    code: code ?? this.code,
    firstSeen: firstSeen ?? this.firstSeen,
    redeemedCode: redeemedCode ?? this.redeemedCode,
    entryPromptShown: entryPromptShown ?? this.entryPromptShown,
    lockNoticeShown: lockNoticeShown ?? this.lockNoticeShown,
  );

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'seq': seq,
    'totalCount': totalCount,
    'freeUsers': freeUsers,
    'autoUseDays': autoUseDays,
    'unlocked': unlocked,
    'trialDays': trialDays,
    'entryHours': entryHours,
    'shareUrl': shareUrl,
    'code': code,
    'firstSeen': firstSeen?.millisecondsSinceEpoch,
    'redeemedCode': redeemedCode,
    'entryPromptShown': entryPromptShown,
    'lockNoticeShown': lockNoticeShown,
  };

  factory ShareState.fromJson(Map<String, dynamic> json) => ShareState(
    enabled: json['enabled'] as bool? ?? true,
    seq: json['seq'] as int?,
    totalCount: json['totalCount'] as int?,
    freeUsers: json['freeUsers'] as int? ?? defaultFreeUsers,
    autoUseDays: ((json['autoUseDays'] as List?) ?? const []).cast<String>().toList(),
    unlocked: json['unlocked'] as bool? ?? false,
    trialDays: json['trialDays'] as int? ?? defaultTrialDays,
    entryHours: json['entryHours'] as int? ?? defaultEntryHours,
    shareUrl: json['shareUrl'] as String? ?? defaultShareUrl,
    code: json['code'] as String?,
    firstSeen: json['firstSeen'] != null ? DateTime.fromMillisecondsSinceEpoch(json['firstSeen'] as int) : null,
    redeemedCode: json['redeemedCode'] as String?,
    entryPromptShown: json['entryPromptShown'] as bool? ?? false,
    lockNoticeShown: json['lockNoticeShown'] as bool? ?? false,
  );
}

/// Giới hạn + mã giới thiệu đã bắt đầu áp dụng chưa: máy chủ không tắt, và tổng số máy đã vượt X.
/// Chưa hỏi được máy chủ lần nào thì coi như chưa — không chặn ai khi chưa chắc.
bool gateOn(ShareState s) => s.enabled && s.totalCount != null && s.totalCount! > s.freeUsers;

/// GPS/widget có được chạy vào lúc [now] không. Ngày đã bắt đầu dùng thì được dùng hết ngày đó,
/// nên ngày dùng thử cuối cùng không bị cắt giữa chừng.
bool autoAllowed(ShareState s, DateTime now) =>
    !gateOn(s) || s.unlocked || s.autoUseDays.length < s.trialDays || s.autoUseDays.contains(dateKey(dateOnly(now)));

/// Số ngày dùng thử còn lại (không tính hôm nay nếu hôm nay đã dùng).
int trialDaysLeft(ShareState s) => s.autoUseDays.length >= s.trialDays ? 0 : s.trialDays - s.autoUseDays.length;

/// Ghi nhận hôm nay có dùng GPS/widget (mỗi ngày chỉ tính 1 lần). Đếm từ đầu, kể cả khi giới hạn
/// chưa áp dụng.
ShareState withAutoUse(ShareState s, DateTime now) {
  final key = dateKey(dateOnly(now));
  if (s.autoUseDays.contains(key)) return s;
  return s.copyWith(autoUseDays: [...s.autoUseDays, key]);
}

/// Ô nhập mã người giới thiệu còn hiện không: giới hạn đã áp dụng, máy chưa nhập mã nào và chưa
/// lấy mã của mình (lấy mã rồi thì mất quyền nhập). Nếu máy chủ đặt thời hạn thì còn phải trong hạn.
bool entryOpen(ShareState s, DateTime now) {
  if (!gateOn(s) || s.redeemedCode != null || s.code != null) return false;
  if (s.entryHours <= 0) return true;
  return s.firstSeen != null && now.isBefore(s.firstSeen!.add(Duration(hours: s.entryHours)));
}

/// Có hiện nút "Lấy mã" không: giới hạn đã áp dụng, máy chưa có mã và chưa được mở khóa.
bool canTakeCode(ShareState s) => gateOn(s) && !s.unlocked && s.code == null;

/// Có tự bật hộp hỏi "Ai giới thiệu bạn?" khi mở app không: chỉ với máy cài sau khi đã đủ X máy
/// (máy cũ thì ô nhập nằm sẵn trong Cài đặt, không làm phiền bằng hộp hỏi).
bool shouldPromptReferral(ShareState s, DateTime now) =>
    entryOpen(s, now) && !s.entryPromptShown && s.seq != null && s.seq! > s.freeUsers;

bool isValidCode(String code) => RegExp(r'^[0-9]{6}$').hasMatch(code);

/// Nội dung tin nhắn chia sẻ: đang cần mở khóa và đã có mã thì kèm mã để người nhận nhập, còn lại
/// chỉ có link.
String shareMessage(ShareState s) {
  final base = 'Mình đang dùng app Chấm Công Đơn Giản để chấm công và tính lương. Tải ở đây: ${s.shareUrl}';
  if (!gateOn(s) || s.unlocked || s.code == null) return base;
  return '$base\nCài xong, bạn vào Cài đặt › Chia sẻ app và nhập mã giới thiệu của mình: ${s.code}';
}
