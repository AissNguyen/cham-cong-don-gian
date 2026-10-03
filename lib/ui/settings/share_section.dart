/// Giao diện chia sẻ app + mã giới thiệu: mục trong Cài đặt, hộp "Ai giới thiệu bạn?" cho máy
/// mới cài, và hộp báo khi hết ngày dùng thử chấm công tự động (GPS, widget). Khi giới hạn chưa áp
/// dụng (tổng số máy chưa vượt X) thì chỉ còn nút gửi link, không lộ gì về mã.
library;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/share_gate.dart';
import '../../share/share_service.dart';
import '../../theme/app_theme.dart';
import 'settings_card.dart';

String _lockedText(ShareState s) =>
    'Đã hết ${s.trialDays} ngày dùng thử chấm công tự động (GPS, widget). Chấm tay vẫn dùng bình thường. '
    'Chia sẻ app cho 1 người: khi họ nhập mã của bạn, bạn được dùng lâu dài.';

String _entryText(ShareState s) =>
    'Có người giới thiệu app cho bạn? Nhập mã của họ để họ được mở chấm công tự động lâu dài. '
    '${s.entryHours > 0 ? 'Sau ${s.entryHours} giờ kể từ lúc cài, ô này sẽ biến mất. ' : ''}'
    'Nếu bạn lấy mã của mình trước thì ô này cũng biến mất.';

/// Mã 6 chữ số của máy này, chạm để sao chép.
class _CodeBox extends StatelessWidget {
  const _CodeBox({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final messenger = ScaffoldMessenger.of(context);
        await Clipboard.setData(ClipboardData(text: code));
        messenger.showSnackBar(const SnackBar(content: Text('Đã sao chép mã.')));
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: context.appColors.accentSoft.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text('Mã giới thiệu của bạn', style: TextStyle(fontSize: 12.5, color: context.appColors.ink2)),
            const SizedBox(height: 2),
            Text(
              '${code.substring(0, 3)} ${code.substring(3)}',
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: 3),
            ),
          ],
        ),
      ),
    );
  }
}

/// Nút "Lấy mã": hỏi lại trước khi cấp, vì lấy mã rồi thì máy này không nhập mã người khác được nữa.
class _TakeCodeButton extends StatefulWidget {
  const _TakeCodeButton();

  @override
  State<_TakeCodeButton> createState() => _TakeCodeButtonState();
}

class _TakeCodeButtonState extends State<_TakeCodeButton> {
  bool _busy = false;

  Future<void> _take() async {
    final messenger = ScaffoldMessenger.of(context);
    // Máy đã nhập mã cho người khác rồi thì không còn gì để mất, khỏi hỏi lại.
    if (shareController.entryIsOpen) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Lấy mã giới thiệu?'),
          content: const Text(
            'Sau khi lấy mã, máy này không nhập được mã của người khác nữa. Nếu có người nhờ bạn nhập mã '
            'của họ thì hãy nhập trước rồi mới lấy mã.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Để sau')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Lấy mã')),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    if (!mounted) return;
    setState(() => _busy = true);
    final ok = await shareController.takeCode();
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Chưa kết nối được máy chủ, bạn kiểm tra mạng rồi thử lại.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      icon: const Icon(Icons.confirmation_number_outlined),
      label: Text(_busy ? 'Đang lấy mã...' : 'Lấy mã giới thiệu'),
      onPressed: _busy ? null : _take,
    );
  }
}

/// Ô nhập mã của người giới thiệu — dùng chung cho mục Cài đặt và hộp hỏi lúc mới cài.
class _ReferralEntry extends StatefulWidget {
  const _ReferralEntry({this.onDone});

  final VoidCallback? onDone;

  @override
  State<_ReferralEntry> createState() => _ReferralEntryState();
}

class _ReferralEntryState extends State<_ReferralEntry> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final result = await shareController.redeem(_controller.text);
    if (result == RedeemResult.ok) {
      messenger.showSnackBar(SnackBar(content: Text(redeemMessage(result))));
      widget.onDone?.call();
    }
    // Nhập xong thì ô này bị gỡ khỏi màn hình (máy đã nhập mã), không còn gì để cập nhật.
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = result == RedeemResult.ok ? null : redeemMessage(result);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'Mã 6 chữ số',
              border: const OutlineInputBorder(),
              counterText: '',
              errorText: _error,
              errorMaxLines: 3,
            ),
            onSubmitted: (_) => _submit(),
          ),
        ),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: FilledButton(onPressed: _busy ? null : _submit, child: Text(_busy ? 'Đang gửi...' : 'Xác nhận')),
        ),
      ],
    );
  }
}

/// Mục "Chia sẻ app" trong Cài đặt.
class ShareSection extends StatelessWidget {
  const ShareSection({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: shareController,
      builder: (context, _) {
        final s = shareController.state;
        final note = TextStyle(fontSize: 12.5, color: context.appColors.ink2);
        // Bản web không có GPS/widget, và lúc giới hạn chưa áp dụng (tổng số máy chưa vượt X, hoặc
        // máy chủ tắt): không có dùng thử, mã hay ô nhập — chỉ chia sẻ link.
        final active = !kIsWeb && gateOn(s);
        final gated = active && !s.unlocked;
        final daysLeft = trialDaysLeft(s);
        return SettingsCard(
          title: 'Chia sẻ app',
          subtitle: !gated
              ? 'Thấy app hữu ích thì giới thiệu cho bạn bè, đồng nghiệp nhé.'
              : shareController.allowed
              ? '${daysLeft > 0 ? 'Chấm công tự động (GPS, widget) còn $daysLeft ngày dùng thử' : 'Hôm nay là ngày dùng thử cuối của chấm công tự động (GPS, widget)'}. '
                    'Chia sẻ app, có 1 người nhập mã của bạn là được dùng lâu dài.'
              : _lockedText(s),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (active && s.unlocked) ...[
                Text('Chấm công tự động đã mở lâu dài. Cảm ơn bạn đã giới thiệu app!', style: note),
                const SizedBox(height: 10),
              ],
              if (gated && s.code != null) ...[_CodeBox(code: s.code!), const SizedBox(height: 10)],
              if (!kIsWeb && canTakeCode(s)) ...[const _TakeCodeButton(), const SizedBox(height: 8)],
              if (gated && s.code == null)
                OutlinedButton.icon(
                  icon: const Icon(Icons.share),
                  label: const Text('Chia sẻ app'),
                  onPressed: shareController.shareApp,
                )
              else if (kIsWeb)
                // Nhiều trình duyệt máy tính không có khung chia sẻ, nên bản web sao chép link.
                FilledButton.icon(
                  icon: const Icon(Icons.link),
                  label: const Text('Sao chép link app'),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await Clipboard.setData(ClipboardData(text: shareMessage(s)));
                    messenger.showSnackBar(const SnackBar(content: Text('Đã sao chép, bạn dán vào tin nhắn để gửi.')));
                  },
                )
              else
                FilledButton.icon(
                  icon: const Icon(Icons.share),
                  label: Text(gated ? 'Chia sẻ app kèm mã' : 'Chia sẻ app'),
                  onPressed: shareController.shareApp,
                ),
              if (gated && s.code != null)
                TextButton(
                  onPressed: shareController.syncing ? null : () => shareController.sync(force: true),
                  child: Text(shareController.syncing ? 'Đang kiểm tra...' : 'Kiểm tra đã có người nhập mã chưa'),
                ),
              if (!kIsWeb && shareController.entryIsOpen) ...[
                const Divider(height: 28),
                const Text('Ai giới thiệu bạn?', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(_entryText(s), style: note),
                const SizedBox(height: 10),
                const _ReferralEntry(),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Dòng báo trong mục GPS khi đã hết ngày dùng thử — không hiện gì nếu còn dùng được.
class AutoLockNotice extends StatelessWidget {
  const AutoLockNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: shareController,
      builder: (context, _) {
        if (kIsWeb || shareController.allowed) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Chấm công GPS đang tạm dừng vì đã hết ${shareController.state.trialDays} ngày dùng thử. '
            'Xem mục "Chia sẻ app" ở đầu trang Cài đặt để mở lại.',
            style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.error),
          ),
        );
      },
    );
  }
}

/// Hộp hỏi "Ai giới thiệu bạn?" — hiện 1 lần cho máy mới cài, bỏ qua được.
Future<void> showReferralPrompt(BuildContext context) async {
  await shareController.markEntryPromptShown();
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Ai giới thiệu bạn?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_entryText(shareController.state)),
          const SizedBox(height: 14),
          _ReferralEntry(onDone: () => Navigator.pop(context)),
          const SizedBox(height: 8),
          Text(
            'Bỏ qua bây giờ thì vẫn nhập được ở Cài đặt › Chia sẻ app.',
            style: TextStyle(fontSize: 12.5, color: context.appColors.ink2),
          ),
        ],
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Bỏ qua'))],
    ),
  );
}

/// Hộp báo hết ngày dùng thử: lấy mã (nếu chưa có), mã của máy + nút chia sẻ. Tự đóng khi máy
/// được mở khóa trong lúc hộp đang mở.
Future<void> showLockNotice(BuildContext context) async {
  await shareController.markLockNoticeShown();
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (context) => ListenableBuilder(
      listenable: shareController,
      builder: (context, _) {
        final s = shareController.state;
        return AlertDialog(
          title: Text(s.unlocked ? 'Đã mở chấm công tự động' : 'Chia sẻ để dùng tiếp chấm công tự động'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (s.unlocked)
                const Text('Đã có người nhập mã của bạn. GPS và widget dùng lại được lâu dài. Cảm ơn bạn!')
              else ...[
                Text(_lockedText(s)),
                const SizedBox(height: 14),
                if (s.code != null) _CodeBox(code: s.code!) else const _TakeCodeButton(),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(s.unlocked ? 'Đóng' : 'Để sau')),
            if (!s.unlocked && s.code != null)
              FilledButton.icon(
                icon: const Icon(Icons.share),
                label: const Text('Chia sẻ app kèm mã'),
                onPressed: shareController.shareApp,
              ),
          ],
        );
      },
    ),
  );
}
