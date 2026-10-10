/// Hộp nhắc cập nhật, ba trạng thái theo `mockup/nhac-cap-nhat.html`: còn được "Để sau", hết lượt
/// (không tắt được, chỉ còn "Cập nhật"), và lâu không có mạng ("Thử lại" / "Để sau").
library;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'update_policy.dart';
import 'update_service.dart';
import 'web_reload.dart';

/// Kết quả người dùng chọn trong hộp nhắc.
enum UpdateChoice { update, later, retry }

void openUpdate(UpdateStatus status) {
  if (kIsWeb) {
    reloadPage();
  } else if (status.updateUrl != null && status.updateUrl!.isNotEmpty) {
    launchUrl(Uri.parse(status.updateUrl!), mode: LaunchMode.externalApplication);
  }
}

/// Hiện hộp nhắc. Trạng thái bắt buộc thì không đóng được (bấm "Cập nhật" xong hộp vẫn ở đó).
Future<UpdateChoice?> showUpdateDialog(BuildContext context, UpdateStatus status) {
  final forced = status.kind == UpdatePromptKind.forced;
  return showDialog<UpdateChoice>(
    context: context,
    barrierDismissible: !forced,
    builder: (context) => PopScope(canPop: !forced, child: UpdateDialog(status: status)),
  );
}

class UpdateDialog extends StatelessWidget {
  const UpdateDialog({super.key, required this.status});

  final UpdateStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final offline = status.kind == UpdatePromptKind.offline;
    final forced = status.kind == UpdatePromptKind.forced;
    final version = status.latestVersion ?? '';
    final String title;
    final String body;
    if (offline) {
      title = 'Hãy bật mạng để kiểm tra bản mới';
      body =
          'Đã ${status.offlineDays} ngày app chưa kết nối được mạng nên không biết có bản mới hay không. '
          'Bật Wi-Fi hoặc 4G rồi bấm "Thử lại".';
    } else if (forced) {
      title = 'Cần cập nhật lên bản mới';
      body = status.maxSkips > 0
          ? 'Bạn đã bấm "Để sau" ${status.maxSkips} lần. Hãy cập nhật lên bản $version để tiếp tục dùng app.'
          : 'Hãy cập nhật lên bản $version để tiếp tục dùng app.';
    } else {
      title = 'Cần cập nhật lên bản mới';
      body = 'Đã có bản $version. Hãy cập nhật để dùng tiếp các tính năng mới và sửa lỗi.';
    }
    final mainLabel = offline ? 'Thử lại' : (kIsWeb ? 'Tải lại trang' : 'Cập nhật');

    return AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: scheme.primary.withValues(alpha: 0.12),
            child: Icon(offline ? Icons.wifi_off : Icons.system_update_alt, color: scheme.primary, size: 28),
          ),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(body, textAlign: TextAlign.center, style: TextStyle(fontSize: 13.5, color: scheme.onSurfaceVariant)),
          if (!offline) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Dữ liệu chấm công và cài đặt của bạn được giữ nguyên.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                if (offline) {
                  Navigator.pop(context, UpdateChoice.retry);
                  return;
                }
                openUpdate(status);
                if (!forced) Navigator.pop(context, UpdateChoice.update);
              },
              child: Text(mainLabel),
            ),
          ),
          if (!forced) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, UpdateChoice.later),
                child: Text(offline ? 'Để sau' : 'Để sau (còn ${status.remainingSkips} lần)'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
