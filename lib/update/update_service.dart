/// Kiểm tra bản mới qua Firebase Remote Config: người dùng ra bản mới bằng cách đưa APK lên GitHub
/// Releases rồi đổi `latest_version` (và `update_url` nếu đổi chỗ tải) trên Firebase Console, không
/// cài ngày nào cả. Quy tắc nhắc ở `update_policy.dart`; file này chỉ lấy tham số từ Remote Config và
/// lưu những gì máy tự nhớ (số lần "Để sau", lần nhắc gần nhất, lần có mạng gần nhất).
library;

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'update_policy.dart';

const _kVersion = 'update_version';
const _kSkips = 'update_skips';
const _kLastShown = 'update_last_shown';
const _kLastOnline = 'update_last_online';
const _kLastOfflineShown = 'update_last_offline_shown';
const _kFirstSeen = 'update_first_seen';

class UpdateStatus {
  const UpdateStatus({
    this.kind = UpdatePromptKind.none,
    this.latestVersion,
    this.updateUrl,
    this.remainingSkips = 0,
    this.maxSkips = 3,
    this.offlineDays = 10,
  });

  final UpdatePromptKind kind;
  final String? latestVersion;
  final String? updateUrl;
  final int remainingSkips;
  final int maxSkips;
  final int offlineDays;

  static const none = UpdateStatus();
}

DateTime? _date(SharedPreferences prefs, String key) => DateTime.tryParse(prefs.getString(key) ?? '');

Future<UpdateMemory> _loadMemory() async {
  final prefs = await SharedPreferences.getInstance();
  return UpdateMemory(
    version: prefs.getString(_kVersion),
    skips: prefs.getInt(_kSkips) ?? 0,
    lastShown: _date(prefs, _kLastShown),
    lastOnline: _date(prefs, _kLastOnline),
    lastOfflineShown: _date(prefs, _kLastOfflineShown),
    firstSeen: _date(prefs, _kFirstSeen),
  );
}

Future<void> _saveMemory(UpdateMemory m) async {
  final prefs = await SharedPreferences.getInstance();
  Future<void> setDate(String key, DateTime? v) async =>
      v == null ? prefs.remove(key) : prefs.setString(key, v.toIso8601String());
  if (m.version == null) {
    await prefs.remove(_kVersion);
  } else {
    await prefs.setString(_kVersion, m.version!);
  }
  await prefs.setInt(_kSkips, m.skips);
  await setDate(_kLastShown, m.lastShown);
  await setDate(_kLastOnline, m.lastOnline);
  await setDate(_kLastOfflineShown, m.lastOfflineShown);
  await setDate(_kFirstSeen, m.firstSeen);
}

/// Gọi mỗi lần mở/quay lại app. Không bao giờ được ném lỗi ra ngoài. [firebaseOk] false (Firebase
/// không khởi động được) thì coi như không có mạng.
Future<UpdateStatus> checkForUpdate({bool firebaseOk = true}) async {
  try {
    final now = DateTime.now();
    final memory = await _loadMemory();
    final currentVersion = (await PackageInfo.fromPlatform()).version;

    var latestVersion = '';
    var updateUrl = '';
    var params = UpdateParams(latestVersion: '', currentVersion: currentVersion);
    DateTime? onlineAt;
    if (firebaseOk) {
      final rc = FirebaseRemoteConfig.instance;
      await rc.setConfigSettings(
        RemoteConfigSettings(fetchTimeout: const Duration(seconds: 10), minimumFetchInterval: const Duration(hours: 6)),
      );
      await rc.setDefaults({
        'latest_version': '0.0.0',
        'update_url': '',
        'update_max_skips': 3,
        'update_remind_hours': 24,
        'update_offline_days': 10,
      });
      try {
        await rc.fetchAndActivate().timeout(const Duration(seconds: 10));
      } catch (_) {
        // Mất mạng: dùng giá trị lấy được lần gần nhất (Remote Config tự giữ trong máy).
      }
      // Lần tải thành công gần nhất (tải bị bỏ qua vì chưa đủ 6 giờ thì vẫn giữ mốc cũ).
      final fetched = rc.lastFetchTime;
      if (fetched.year > 2000) onlineAt = fetched;
      latestVersion = rc.getString('latest_version');
      updateUrl = rc.getString('update_url');
      params = UpdateParams(
        latestVersion: latestVersion,
        currentVersion: currentVersion,
        maxSkips: rc.getInt('update_max_skips'),
        remindHours: rc.getInt('update_remind_hours'),
        offlineDays: rc.getInt('update_offline_days'),
      );
    }

    final decision = decideUpdatePrompt(params, memory, now, onlineAt: onlineAt);
    await _saveMemory(decision.memory);
    return UpdateStatus(
      kind: decision.kind,
      latestVersion: latestVersion,
      updateUrl: updateUrl,
      remainingSkips: decision.remainingSkips,
      maxSkips: params.maxSkips,
      offlineDays: params.offlineDays,
    );
  } catch (_) {
    return UpdateStatus.none;
  }
}

/// Hộp nhắc vừa hiện lên.
Future<void> recordUpdatePromptShown(UpdatePromptKind kind) async {
  try {
    await _saveMemory(markShown(await _loadMemory(), kind, DateTime.now()));
  } catch (_) {}
}

/// Người dùng bấm "Để sau" ở hộp nhắc cập nhật.
Future<void> recordUpdateSkipped() async {
  try {
    await _saveMemory(markSkipped(await _loadMemory(), DateTime.now()));
  } catch (_) {}
}
