import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/store.dart';
import '../../notice/help_text.dart';
import '../../onboarding/pay_guide.dart';
import '../../onboarding/tour_controller.dart';
import '../widgets/gps_coords_demo.dart';
import 'settings_card.dart';

class HelpEntrySection extends StatelessWidget {
  const HelpEntrySection({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      title: 'Hướng dẫn sử dụng',
      subtitle: 'Hướng dẫn cơ bản, hướng dẫn lương và phần nâng cao.',
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

/// Phần "Nâng cao": giải thích những thứ không có trong hai chuyến hướng dẫn cơ bản và lương.
const _advancedItems = [
  _HelpItem(
    Icons.swap_horiz,
    'Lấy tăng ca bù vào ngày nghỉ',
    'Dành cho công ty lấy giờ tăng ca để bù giờ thiếu. Khi bật, mỗi ngày T2–T6 đủ 8 tiếng mới tính tăng ca (thứ 7 '
        'là 7:00–11:30). Phần thiếu lấy từ tổng giờ tăng ca trong kỳ, 1 giờ tăng ca bù 1 giờ công, lấy tăng ca ngày '
        'thường trước rồi mới tới Chủ nhật, ngày lễ.\n'
        '• Công ty cho nghỉ: bù ngày công ty cho nghỉ và ngày công ty cho vào muộn, về sớm.\n'
        '• Tự nghỉ: bù thêm cả ngày tự nghỉ (đã hết phép) và ngày tự đi muộn.\n'
        'Tăng ca trong kỳ không đủ bù thì phần thiếu bị mất như bình thường. Bấm "Trừ tăng ca" trên thẻ thu nhập để '
        'xem chi tiết. Cài ở Cài đặt › Cài đặt tính công.',
  ),
  _HelpItem(
    Icons.event_available_outlined,
    'Ngày phép',
    'Công nhân mỗi kỳ lương được cộng 1 ngày phép, không dùng thì dồn sang kỳ sau. Tự nghỉ thì trừ phép trước, ngày '
        'đó vẫn có lương; hết phép mới là nghỉ không lương. Số phép còn lại hiện ở nút Ngày nghỉ, ở Cài đặt tính công '
        'và ở phiếu lương. Sửa số phép ở Cài đặt tính công (bấm Sửa), ví dụ khi công ty cho thêm phép hay xóa phép '
        'cuối năm.',
  ),
  _HelpItem(
    Icons.receipt_long_outlined,
    'Kỳ lương và phiếu lương',
    'Mọi con số trên thẻ thu nhập và phiếu lương đều tính theo kỳ đang chạy. Phiếu lương chỉ được tính khi hết kỳ, '
        'trước đó các dòng hiện 0. Sửa ở kỳ nào thì áp dụng cho kỳ đó, các kỳ trước giữ nguyên. Ngày công, giờ tăng '
        'ca của kỳ sửa tay được theo số công ty chốt (Phiếu lương › Sửa).',
  ),
  _HelpItem(
    Icons.gps_fixed,
    'GPS: tùy chọn thêm',
    '1. Từ 7:00 tới 14:00, cứ phút 00 và 30 app dò vị trí; trong khoảng 200 m quanh chỗ làm thì chấm vào đúng mốc '
        'đó.\n'
        '2. Sau khi vào, cứ phút 15 và 45 app dò lại; ra khỏi chỗ làm thì chấm ra (giờ ra là x:00 hoặc x:30).\n'
        '3. Dò 3 lần (cách 3 phút) vẫn không ra vị trí thì coi như bạn đang ở chỗ làm.\n'
        '4. Quá 22:00 mà chưa có giờ ra thì ngày đó báo đỏ, bạn tự nhập giờ ra.\n'
        'Đổi bán kính, khung giờ, thêm địa điểm khác (nhà trọ sát công ty, xưởng xa), xem nhật ký GPS: Cài đặt › '
        'Nâng cao › GPS: tùy chọn thêm.',
  ),
  _HelpItem(
    Icons.celebration_outlined,
    'Ngày lễ, tăng ca theo khung',
    'Ngày lễ tính theo giá ngày lễ trong bảng lương/giờ, thêm hoặc bớt ở Cài đặt › Nâng cao › Ngày lễ. Tăng ca theo '
        'khung dùng khi công ty trừ phút nghỉ giữa các khung tăng ca.',
  ),
  _HelpItem(
    Icons.save_alt,
    'Sao lưu, sao chép cấu hình',
    'Sao lưu ra file Excel để đổi máy không mất dữ liệu. Sao chép cấu hình để gửi cách tính lương cho bạn cùng công '
        'ty dán vào máy họ.',
  ),
];

/// Màn Hướng dẫn: ba mục Cơ bản (chuyến làm thử trên màn chính), Lương (hỏi loại người dùng, kỳ
/// lương rồi hướng dẫn nhập phiếu lương) và Nâng cao (trang chữ).
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget entry({required IconData icon, required String title, required String sub, required VoidCallback onTap, Key? key}) =>
        Card(
          key: key,
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: Icon(icon, color: scheme.primary),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(sub),
            trailing: const Icon(Icons.chevron_right),
            onTap: onTap,
          ),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Hướng dẫn')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          entry(
            key: const ValueKey('help-basic'),
            icon: Icons.play_circle_outline,
            title: 'Hướng dẫn cơ bản',
            sub: 'Chấm công, ngày nghỉ, lịch, thống kê, GPS. Làm thử lại trên màn chính.',
            onTap: () {
              // Về màn chính rồi chuyến hướng dẫn tự bắt đầu.
              Navigator.of(context).popUntil((route) => route.isFirst);
              tourController.requestReplay();
            },
          ),
          const SizedBox(height: 10),
          entry(
            key: const ValueKey('help-pay'),
            icon: Icons.calculate_outlined,
            title: 'Hướng dẫn lương',
            sub: 'Loại người dùng, kỳ lương, lương cơ bản, các khoản, giá tăng ca.',
            onTap: () => runPayGuide(context, context.read<AppStore>(), askSetup: true),
          ),
          const SizedBox(height: 10),
          entry(
            key: const ValueKey('help-gps-demo'),
            icon: Icons.map_outlined,
            title: 'Lấy tọa độ từ Google Maps',
            sub: 'Hình động: phóng to bản đồ, chép tọa độ chỗ chấm công, dán vào app.',
            onTap: () => showGpsCoordsDemo(context),
          ),
          const SizedBox(height: 10),
          entry(
            key: const ValueKey('help-advanced'),
            icon: Icons.tune,
            title: 'Nâng cao',
            sub: 'Lấy tăng ca bù, ngày phép, kỳ lương, GPS tùy chọn thêm, ngày lễ, sao lưu.',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _AdvancedHelpScreen())),
          ),
        ],
      ),
    );
  }
}

class _AdvancedHelpScreen extends StatelessWidget {
  const _AdvancedHelpScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nâng cao')),
      body: ValueListenableBuilder<List<HelpEntry>?>(
        valueListenable: remoteHelpEntries,
        builder: (context, remote, _) {
          // Có hướng dẫn soạn trên Firebase thì dùng, không thì dùng nội dung có sẵn.
          final items = remote == null
              ? _advancedItems
              : [for (final e in remote) _HelpItem(Icons.tips_and_updates_outlined, e.title, e.body)];
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 14),
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
                          Text(
                            item.body,
                            style: TextStyle(height: 1.45, color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
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
