import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Khung card dùng chung cho các mục Cài đặt.
class SettingsCard extends StatelessWidget {
  const SettingsCard({super.key, required this.title, this.subtitle, required this.child});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: context.appColors.line.withValues(alpha: 0.6), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: TextStyle(fontSize: 12.5, color: context.appColors.ink2)),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// Nút chọn giờ dạng chip nhỏ, dùng nhiều nơi trong Cài đặt.
class TimeChip extends StatelessWidget {
  const TimeChip({super.key, required this.label, required this.time, required this.onPick});

  final String label;
  final TimeOfDay time;
  final ValueChanged<TimeOfDay> onPick;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      icon: const Icon(Icons.schedule, size: 16),
      label: Text('$label ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'),
      onPressed: () async {
        final picked = await showTimePicker(context: context, initialTime: time);
        if (picked != null) onPick(picked);
      },
    );
  }
}
