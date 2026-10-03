/// Chỉ hiện trên bản web: mời tải bản Android (chạy được GPS tự động + widget màn hình chính,
/// những thứ bản web không làm được) — link tải thẳng file APK, chưa có trên Play Store.
library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'settings_card.dart';

const androidApkUrl = 'https://github.com/AissNguyen/cham-cong-don-gian/releases/download/v1.0.0/app-release.apk';

class AndroidDownloadSection extends StatelessWidget {
  const AndroidDownloadSection({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      title: 'Tải bản Android',
      subtitle: 'Bản Android chạy được tự chấm công GPS và widget màn hình chính — những thứ bản web không làm được.',
      child: OutlinedButton.icon(
        icon: const Icon(Icons.android),
        label: const Text('Tải file cài đặt (.apk)'),
        onPressed: () => launchUrl(Uri.parse(androidApkUrl)),
      ),
    );
  }
}
