import 'package:flutter/material.dart';

import '../../notice/help_text.dart';
import 'settings_card.dart';

class HelpEntrySection extends StatelessWidget {
  const HelpEntrySection({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      title: 'Hướng dẫn sử dụng',
      subtitle: 'Xem nhanh từng nút, từng chức năng của app.',
      child: OutlinedButton.icon(
        icon: const Icon(Icons.help_outline),
        label: const Text('Xem hướng dẫn'),
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HelpScreen())),
      ),
    );
  }
}

class _HelpItem {
  const _HelpItem(this.icon, this.title, this.body);
  final IconData icon;
  final String title;
  final String body;
}

const _items = [
  _HelpItem(
    Icons.calendar_today_outlined,
    'Lịch',
    'Chạm một ngày để chọn — các nút bên dưới sẽ thao tác trên ngày đang chọn. Ô xanh lá là ngày đã chấm đủ, xanh dương là đang mở ca (mới chấm vào), hồng là ngày nghỉ, viền vàng là chưa chấm.',
  ),
  _HelpItem(
    Icons.login,
    'Chấm vào / Chấm ra',
    'Chạm để mở bảng chọn giờ (lấy giờ hiện tại, tự sửa giờ hoặc chọn giờ có sẵn). Giữ (ấn lâu) để chấm ngay giờ hiện tại.',
  ),
  _HelpItem(Icons.beach_access_outlined, 'Ngày nghỉ', 'Đánh dấu cả ngày là nghỉ, xóa hết giờ đã chấm trong ngày đó.'),
  _HelpItem(
    Icons.watch_later_outlined,
    'Đi muộn',
    'Đánh dấu ngày đang chọn là đi muộn, trừ theo số phút/tiền đã cài trong Cài đặt.',
  ),
  _HelpItem(
    Icons.note_add_outlined,
    'Ghi chú',
    'Viết ghi chú cho ngày đang chọn, có sẵn vài thẻ gợi ý — chỉ để ghi nhớ, không ảnh hưởng tính lương.',
  ),
  _HelpItem(
    Icons.brightness_2_outlined,
    'Âm lịch / Lương mỗi ngày',
    '2 nút nhỏ ở đầu trang: bật hiện ngày âm lịch, hoặc đổi số dưới mỗi ngày từ giờ công sang tiền tạm tính.',
  ),
  _HelpItem(
    Icons.settings_outlined,
    'Cài đặt',
    'Bánh răng góc trái trên cùng — nơi cài khung giờ làm việc, bảng lương, kỳ lương, GPS...',
  ),
];

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hướng dẫn sử dụng')),
      body: ValueListenableBuilder<List<HelpEntry>?>(
        valueListenable: remoteHelpEntries,
        builder: (context, remote, _) {
          // Có hướng dẫn soạn trên Firebase thì dùng, không thì dùng nội dung có sẵn.
          final items = remote == null
              ? _items
              : [for (final e in remote) _HelpItem(Icons.tips_and_updates_outlined, e.title, e.body)];
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final item = items[i];
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(item.icon, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (item.title.isNotEmpty)
                          Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                        if (item.title.isNotEmpty && item.body.isNotEmpty) const SizedBox(height: 2),
                        if (item.body.isNotEmpty)
                          Text(item.body, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
