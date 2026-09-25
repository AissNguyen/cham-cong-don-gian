import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'settings_card.dart';

/// TODO: điền email nhận góp ý của bạn vào đây.
const feedbackEmail = 'your-email@example.com';

Uri feedbackMailUri({String subject = 'Góp ý Chấm Công Đơn Giản', String body = ''}) => Uri(
  scheme: 'mailto',
  path: feedbackEmail,
  query: 'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
);

/// Nút gửi góp ý qua email — mở sẵn app Mail với địa chỉ điền sẵn.
class FeedbackSection extends StatelessWidget {
  const FeedbackSection({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      title: 'Góp ý',
      subtitle: 'Thấy thiếu gì, lỗi gì, hay muốn có thêm chức năng — gửi cho mình biết nhé.',
      child: OutlinedButton.icon(
        icon: const Icon(Icons.email_outlined),
        label: const Text('Gửi góp ý qua email'),
        onPressed: () async {
          final uri = feedbackMailUri();
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri);
          } else if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Không mở được app Mail trên máy này.')));
          }
        },
      ),
    );
  }
}
