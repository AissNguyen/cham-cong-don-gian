import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/store.dart';
import '../../domain/config_share.dart';
import 'settings_card.dart';

/// Sao chép phần lương và cài đặt tính công ra một dòng ngắn, hoặc lấy thẳng cấu hình đang có trong
/// clipboard để dùng lại (đọc được cả chuỗi kiểu cũ).
class ConfigShareSection extends StatelessWidget {
  const ConfigShareSection({super.key, required this.store});

  final AppStore store;

  Future<void> _copy(BuildContext context) async {
    final text = encodeSettings(store.settings);
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã sao chép cấu hình.')));
    }
  }

  Future<void> _applyFromClipboard(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.trim().isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Clipboard đang trống.')));
      return;
    }
    final settings = decodeSettings(text, current: store.settings);
    if (settings == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Nội dung trong clipboard không phải cấu hình hợp lệ.')));
      return;
    }
    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dùng cấu hình từ clipboard?'),
        content: const Text(
          'Phần lương và cài đặt tính công sẽ lấy theo cấu hình vừa sao chép. Ngày lễ, GPS và giờ chấm '
          'công của bạn giữ nguyên.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Dùng cấu hình này')),
        ],
      ),
    );
    if (confirmed != true) return;
    await store.replaceSettings(settings);
    if (context.mounted) {
      messenger.showSnackBar(const SnackBar(content: Text('Đã áp dụng cấu hình từ clipboard.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      title: 'Sao chép / dán cấu hình',
      subtitle:
          'Chỉ gồm các con số của phiếu lương và cài đặt tính công, không kèm ngày lễ và GPS. Sao chép để gửi '
          'cho máy khác; ở máy nhận chỉ cần sao chép xong rồi bấm nút dưới, không cần dán tay.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.copy),
            label: const Text('Sao chép cấu hình hiện tại'),
            onPressed: () => _copy(context),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            icon: const Icon(Icons.download),
            label: const Text('Dùng cấu hình đang có trong clipboard'),
            onPressed: () => _applyFromClipboard(context),
          ),
        ],
      ),
    );
  }
}
