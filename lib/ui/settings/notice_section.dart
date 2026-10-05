import 'package:flutter/material.dart';

import '../../notice/notice.dart';
import 'settings_card.dart';

/// Cài đặt › Thông báo: xem lại thông báo của chủ app sau khi đã đóng băng ở màn chính. Không có
/// thông báo nào đang đặt trên Firebase thì mục này ẩn đi.
class NoticeSection extends StatelessWidget {
  const NoticeSection({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppNotice?>(
      valueListenable: activeNotice,
      builder: (context, notice, _) {
        if (notice == null) return const SizedBox.shrink();
        return SettingsCard(
          title: 'Thông báo',
          child: NoticeFullContent(notice: notice),
        );
      },
    );
  }
}
