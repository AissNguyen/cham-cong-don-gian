import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../theme/app_theme.dart';

/// Nhớ những mục Cài đặt người dùng đã gập (theo tiêu đề), để lần sau mở vẫn gập.
class CollapsedSettings {
  static const _key = 'settings_collapsed';
  static Set<String>? _cache;

  /// Đã tải xong thì trả ngay, để thẻ dựng đúng trạng thái từ khung hình đầu.
  static Set<String>? get loaded => _cache;

  static Future<Set<String>> load() async {
    if (_cache != null) return _cache!;
    try {
      final prefs = await SharedPreferences.getInstance();
      _cache = (prefs.getStringList(_key) ?? const <String>[]).toSet();
    } catch (_) {
      _cache = <String>{};
    }
    return _cache!;
  }

  static Future<void> set(String title, bool collapsed) async {
    final titles = await load();
    if (collapsed) {
      titles.add(title);
    } else {
      titles.remove(title);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, titles.toList());
    } catch (_) {
      // Không lưu được thì chỉ mất việc nhớ trạng thái gập, không ảnh hưởng gì khác.
    }
  }

  @visibleForTesting
  static void resetCache() => _cache = null;
}

/// Khung card dùng chung cho các mục Cài đặt.
class SettingsCard extends StatefulWidget {
  const SettingsCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.collapsible = false,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  /// true thì chạm vào tiêu đề để gập lại hoặc mở ra. Mặc định thẻ mở sẵn; người dùng gập mục
  /// nào thì mục đó giữ gập ở những lần mở Cài đặt sau.
  final bool collapsible;

  @override
  State<SettingsCard> createState() => _SettingsCardState();
}

class _SettingsCardState extends State<SettingsCard> {
  bool _collapsed = false;

  @override
  void initState() {
    super.initState();
    if (!widget.collapsible) return;
    final loaded = CollapsedSettings.loaded;
    if (loaded != null) {
      _collapsed = loaded.contains(widget.title);
    } else {
      CollapsedSettings.load().then((titles) {
        if (mounted && titles.contains(widget.title)) setState(() => _collapsed = true);
      });
    }
  }

  void _toggle() {
    setState(() => _collapsed = !_collapsed);
    CollapsedSettings.set(widget.title, _collapsed);
  }

  @override
  Widget build(BuildContext context) {
    final open = !widget.collapsible || !_collapsed;
    final title = Text(widget.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700));
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
      // Material riêng để hiệu ứng chạm của các dòng bên trong không bị nền thẻ che mất.
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.collapsible)
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: _toggle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(child: title),
                      Icon(open ? Icons.expand_less : Icons.expand_more, color: context.appColors.ink2),
                    ],
                  ),
                ),
              )
            else
              title,
            if (open) ...[
              if (widget.subtitle != null) ...[
                const SizedBox(height: 2),
                Text(widget.subtitle!, style: TextStyle(fontSize: 12.5, color: context.appColors.ink2)),
              ],
              const SizedBox(height: 12),
              widget.child,
            ],
          ],
        ),
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
