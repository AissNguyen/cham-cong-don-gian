/// Màn "Còi báo giờ": danh sách giờ hú còi (ví dụ 9:15, 12:30, 14:45), mỗi giờ có tiếng còi, số lần hú,
/// độ to riêng; bật/tắt từng giờ; nghe thử. Còi không hú vào ngày đã đánh dấu nghỉ.
library;

import 'package:flutter/material.dart';

import '../../bell/bell_service.dart';
import '../../data/store.dart';
import '../../domain/models.dart';
import 'number_inputs.dart';
import 'settings_card.dart';

class BellSection extends StatelessWidget {
  const BellSection({super.key, required this.store});

  final AppStore store;

  Future<void> _save(List<BellConfig> bells) async {
    final sorted = [...bells]..sort((a, b) => a.time.totalMinutes.compareTo(b.time.totalMinutes));
    await store.updateSettings((s) => s.copyWith(bells: sorted));
    await rescheduleBells(store.settings.bells);
  }

  Future<void> _edit(BuildContext context, {int? index}) async {
    final bells = store.settings.bells;
    final result = await showDialog<_BellEditResult>(
      context: context,
      builder: (_) => _BellDialog(initial: index == null ? null : bells[index]),
    );
    if (result == null) return;
    final list = [...bells];
    if (result.delete) {
      if (index != null) list.removeAt(index);
    } else if (index == null) {
      list.add(result.bell!);
    } else {
      list[index] = result.bell!;
    }
    await _save(list);
  }

  @override
  Widget build(BuildContext context) {
    final bells = store.settings.bells;
    final muted = TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurfaceVariant);
    return SettingsCard(
      title: 'Còi báo giờ',
      subtitle: 'Tới giờ điện thoại hú còi, kể cả khi đang để im lặng. Ngày đã đánh dấu nghỉ thì không hú.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (bells.isEmpty) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('Chưa có giờ nào.', style: muted)),
          for (var i = 0; i < bells.length; i++)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(bells[i].time.formatted, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              subtitle: Text(
                '${bells[i].sound.label} · hú ${bells[i].repeats} lần · to ${(bells[i].volume * 100).round()}%',
              ),
              onTap: () => _edit(context, index: i),
              trailing: Switch(
                value: bells[i].enabled,
                onChanged: (v) => _save([
                  for (var k = 0; k < bells.length; k++) k == i ? bells[k].copyWith(enabled: v) : bells[k],
                ]),
              ),
            ),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            icon: const Icon(Icons.add_alarm),
            label: const Text('Thêm giờ hú còi'),
            onPressed: () => _edit(context),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Độ to tính theo âm lượng báo thức của điện thoại: nếu còi nhỏ quá, tăng âm lượng báo thức lên. '
              'Lúc còi hú có thông báo với nút "Tắt còi".',
              style: muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _BellEditResult {
  const _BellEditResult({this.bell, this.delete = false});
  final BellConfig? bell;
  final bool delete;
}

class _BellDialog extends StatefulWidget {
  const _BellDialog({this.initial});

  final BellConfig? initial;

  @override
  State<_BellDialog> createState() => _BellDialogState();
}

class _BellDialogState extends State<_BellDialog> {
  late BellConfig _bell = widget.initial ?? const BellConfig(time: Clock(7, 0));
  bool _playing = false;

  Future<void> _preview() async {
    if (_playing) {
      await stopBell();
      return;
    }
    setState(() => _playing = true);
    await ringBell(_bell);
    if (mounted) setState(() => _playing = false);
  }

  @override
  void dispose() {
    if (_playing) stopBell();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Thêm giờ hú còi' : 'Sửa giờ hú còi'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TimeChip(
              label: 'Giờ',
              time: TimeOfDay(hour: _bell.time.hour, minute: _bell.time.minute),
              onPick: (t) => setState(() => _bell = _bell.copyWith(time: Clock(t.hour, t.minute))),
            ),
            const SizedBox(height: 12),
            const Text('Tiếng còi', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final s in BellSound.values)
                  ChoiceChip(
                    label: Text(s.label),
                    selected: _bell.sound == s,
                    onSelected: (_) => setState(() => _bell = _bell.copyWith(sound: s)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Số lần hú: ${_bell.repeats}', style: const TextStyle(fontWeight: FontWeight.w600)),
            Slider(
              value: _bell.repeats.toDouble(),
              min: 1,
              max: 10,
              divisions: 9,
              label: '${_bell.repeats}',
              onChanged: (v) => setState(() => _bell = _bell.copyWith(repeats: v.round())),
            ),
            Text('Độ to: ${(_bell.volume * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w600)),
            Slider(
              value: _bell.volume,
              min: 0.1,
              max: 1,
              divisions: 9,
              label: '${(_bell.volume * 100).round()}%',
              onChanged: (v) => setState(() => _bell = _bell.copyWith(volume: v)),
            ),
            OutlinedButton.icon(
              icon: Icon(_playing ? Icons.stop : Icons.play_arrow),
              label: Text(_playing ? 'Dừng' : 'Nghe thử'),
              onPressed: _preview,
            ),
          ],
        ),
      ),
      actions: [
        if (widget.initial != null)
          TextButton(
            onPressed: () async {
              final ok = await confirmAsk(
                context,
                title: 'Xóa giờ hú còi?',
                text: 'Bạn chắc chắn muốn xóa giờ ${widget.initial!.time.formatted} không?',
                yes: 'Xóa',
              );
              if (ok && context.mounted) Navigator.pop(context, const _BellEditResult(delete: true));
            },
            child: const Text('Xóa'),
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
        FilledButton(onPressed: () => Navigator.pop(context, _BellEditResult(bell: _bell)), child: const Text('Lưu')),
      ],
    );
  }
}
