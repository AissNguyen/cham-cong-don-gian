import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/store.dart';
import 'payslip_card.dart';
import 'settings_blocks.dart';
import 'work_config_card.dart';

/// Màn Cài đặt theo `mockup/luong-va-cai-dat.html`, từ trên xuống: thông báo, Công nhân / Công
/// nhật, phiếu lương, cài đặt tính công, chấm công GPS (ẩn trên web hoặc khi đã tắt), nâng cao.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          const SettingsNoticeCard(),
          WorkerKindToggle(store: store),
          PayslipCard(store: store),
          WorkConfigCard(store: store),
          if (!kIsWeb && store.settings.showGps) GpsQuickCard(store: store),
          MoreSettingsCard(store: store),
        ],
      ),
    );
  }
}
