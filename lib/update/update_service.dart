/// Kiểm tra bản mới qua Firebase Remote Config: máy chủ chỉ cần đổi giá trị "latest_version"
/// (và "update_url" nếu đổi chỗ tải) trong Firebase Console, không cần phát hành app mới để app
/// biết có bản mới. Có bản mới thì nhắc (được bỏ qua) tối đa 14 ngày kể từ lần đầu phát hiện, sau
/// đó bắt buộc cập nhật mới dùng tiếp được app.
library;

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kPendingVersionKey = 'update_pending_version';
const _kPendingSinceKey = 'update_pending_since';

/// Số ngày được phép trì hoãn kể từ khi phát hiện bản mới trước khi bắt buộc cập nhật
/// (1 tuần nhắc lần đầu + 1 tuần gia hạn = 14 ngày).
const gracePeriodDays = 14;

class UpdateStatus {
  const UpdateStatus({this.hasUpdate = false, this.mandatory = false, this.latestVersion, this.updateUrl});

  final bool hasUpdate;
  final bool mandatory;
  final String? latestVersion;
  final String? updateUrl;

  static const none = UpdateStatus();
}

int _compareVersions(String a, String b) {
  final pa = a.split('.').map((s) => int.tryParse(s) ?? 0).toList();
  final pb = b.split('.').map((s) => int.tryParse(s) ?? 0).toList();
  for (var i = 0; i < 3; i++) {
    final va = i < pa.length ? pa[i] : 0;
    final vb = i < pb.length ? pb[i] : 0;
    if (va != vb) return va.compareTo(vb);
  }
  return 0;
}

/// Gọi mỗi lần mở/quay lại app. Không bao giờ được ném lỗi ra ngoài — lỗi mạng/Remote Config thì
/// coi như chưa có bản mới, thử lại lần sau.
Future<UpdateStatus> checkForUpdate() async {
  try {
    final remoteConfig = FirebaseRemoteConfig.instance;
    await remoteConfig.setConfigSettings(
      RemoteConfigSettings(fetchTimeout: const Duration(seconds: 10), minimumFetchInterval: const Duration(hours: 6)),
    );
    await remoteConfig.setDefaults({'latest_version': '0.0.0', 'update_url': ''});
    await remoteConfig.fetchAndActivate().timeout(const Duration(seconds: 10));

    final latestVersion = remoteConfig.getString('latest_version');
    final updateUrl = remoteConfig.getString('update_url');
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;

    final prefs = await SharedPreferences.getInstance();
    if (latestVersion.isEmpty || _compareVersions(latestVersion, currentVersion) <= 0) {
      // Đang dùng bản mới nhất (hoặc mới hơn) -> xóa trạng thái đang chờ cập nhật nếu có.
      await prefs.remove(_kPendingVersionKey);
      await prefs.remove(_kPendingSinceKey);
      return UpdateStatus.none;
    }

    final pendingVersion = prefs.getString(_kPendingVersionKey);
    DateTime since;
    if (pendingVersion != latestVersion) {
      // Lần đầu thấy bản này mới hơn -> bắt đầu đếm lại từ hôm nay.
      since = DateTime.now();
      await prefs.setString(_kPendingVersionKey, latestVersion);
      await prefs.setString(_kPendingSinceKey, since.toIso8601String());
    } else {
      final sinceStr = prefs.getString(_kPendingSinceKey);
      since = sinceStr != null ? DateTime.parse(sinceStr) : DateTime.now();
    }

    final daysSince = DateTime.now().difference(since).inDays;
    return UpdateStatus(
      hasUpdate: true,
      mandatory: daysSince >= gracePeriodDays,
      latestVersion: latestVersion,
      updateUrl: updateUrl,
    );
  } catch (_) {
    return UpdateStatus.none;
  }
}
