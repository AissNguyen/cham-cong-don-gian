/// Màn chặn bắt buộc cập nhật: hết 14 ngày trì hoãn mà chưa cập nhật thì không dùng được app nữa
/// cho tới khi cập nhật (không có nút quay lại/thoát).
library;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'update_service.dart';
import 'web_reload.dart';

class MandatoryUpdateScreen extends StatelessWidget {
  const MandatoryUpdateScreen({super.key, required this.status});

  final UpdateStatus status;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.system_update_alt, size: 72, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 20),
                  const Text(
                    'Cần cập nhật phiên bản mới',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    kIsWeb
                        ? 'Trang đang dùng bản cũ. Bấm tải lại trang để dùng bản mới nhất.'
                        : 'Bạn đã bỏ qua nhắc cập nhật quá lâu. Hãy cập nhật lên bản mới nhất '
                              '(${status.latestVersion ?? ''}) để tiếp tục dùng app.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    icon: Icon(kIsWeb ? Icons.refresh : Icons.download),
                    label: Text(kIsWeb ? 'Tải lại trang' : 'Tải bản mới'),
                    onPressed: () {
                      if (kIsWeb) {
                        reloadPage();
                      } else if (status.updateUrl != null && status.updateUrl!.isNotEmpty) {
                        launchUrl(Uri.parse(status.updateUrl!));
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Băng nhắc cập nhật, hiện phía trên màn chính — có thể bỏ qua (sẽ hiện lại lần mở app sau, cho
/// tới khi bắt buộc).
class UpdateBanner extends StatelessWidget {
  const UpdateBanner({super.key, required this.status, required this.onDismiss});

  final UpdateStatus status;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.system_update_alt, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Có bản mới${status.latestVersion != null ? ' (${status.latestVersion})' : ''} — cập nhật để dùng tốt hơn.',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: () {
                if (kIsWeb) {
                  reloadPage();
                } else if (status.updateUrl != null && status.updateUrl!.isNotEmpty) {
                  launchUrl(Uri.parse(status.updateUrl!));
                }
              },
              child: Text(kIsWeb ? 'Tải lại' : 'Cập nhật'),
            ),
            IconButton(icon: const Icon(Icons.close, size: 18), onPressed: onDismiss, tooltip: 'Để sau'),
          ],
        ),
      ),
    );
  }
}
