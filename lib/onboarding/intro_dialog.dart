import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Khung giới thiệu hiện một lần khi mở app lần đầu (theo `mockup/gioi-thieu.html`).
/// Trả về true nếu người dùng bấm "Bắt đầu", false nếu "Để sau" (hoặc chạm ra ngoài).
Future<bool> showIntroDialog(BuildContext context) async {
  final result = await showDialog<bool>(context: context, builder: (_) => const _IntroDialog());
  return result ?? false;
}

class _IntroDialog extends StatelessWidget {
  const _IntroDialog();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final primary = Theme.of(context).colorScheme.primary;
    final ink = Theme.of(context).colorScheme.onSurface;
    final bold = TextStyle(fontWeight: FontWeight.w700, color: primary);

    Widget paragraph(List<InlineSpan> spans, {Color? color}) => Text.rich(
      TextSpan(children: spans, style: TextStyle(color: color ?? ink)),
      style: const TextStyle(fontSize: 14.5, height: 1.5),
    );

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Tính năng cơ bản', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            paragraph([
              const TextSpan(text: 'App '),
              TextSpan(text: 'tự động ghi lại giờ đi làm và giờ về', style: bold),
              const TextSpan(text: ' của bạn, mà bạn không cần phải nhập tay.'),
            ]),
            const SizedBox(height: 14),
            paragraph([
              const TextSpan(text: 'Tính ra '),
              TextSpan(text: 'số giờ tăng ca', style: bold),
              const TextSpan(text: ' mỗi ngày.'),
            ]),
            const SizedBox(height: 14),
            paragraph([
              const TextSpan(text: 'Tính ra '),
              TextSpan(text: 'số ngày công', style: bold),
              const TextSpan(text: ', tổng số giờ tăng ca.'),
            ]),
            const SizedBox(height: 14),
            // Tính năng phụ: chữ nhạt hơn, kèm dòng lưu ý nhỏ.
            paragraph([
              TextSpan(text: 'Ước tính số tiền lương', style: bold.copyWith(color: colors.ink2)),
              const TextSpan(text: ' nhận được, dựa trên phiếu lương thật.'),
            ], color: colors.ink2),
            const SizedBox(height: 4),
            Text(
              'Lưu ý, đây là số tiền ước tính, mang tính chất tham khảo, đây là tính năng phụ, bạn có thể bỏ qua.',
              style: TextStyle(fontSize: 12.5, height: 1.45, color: colors.ink3),
            ),
            const SizedBox(height: 22),
            FilledButton(
              style: FilledButton.styleFrom(shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(vertical: 12)),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Bắt đầu', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 6),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: colors.ink2, padding: const EdgeInsets.all(8)),
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Để sau', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      ),
    );
  }
}
