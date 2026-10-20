/// Hướng dẫn tính lương (theo `mockup/huong-dan-phieu-luong.html` và `mockup/huong-dan-moi.html`):
/// mở Cài đặt ở chế độ sửa, phủ mờ cả màn, chỉ sáng đúng chỗ cần nhập (lương cơ bản, các khoản, giá
/// tăng ca), tự cuộn tới chỗ đó. Chỗ sáng vẫn bấm, gõ được. Bỏ qua được bất cứ lúc nào.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/store.dart';
import '../domain/config_share.dart';
import '../domain/models.dart';
import '../ui/settings/settings_screen.dart';
import 'setup_dialog.dart';

/// Mở hướng dẫn tính lương. [askSetup]: hỏi trước loại người dùng, kỳ lương (công nhân thêm bù tăng
/// ca, ngày phép) — chỉ khi mở từ màn Hướng dẫn; nút trên thẻ thu nhập thì không hỏi lại vì lúc mới
/// vào app đã hỏi.
Future<void> runPayGuide(BuildContext context, AppStore store, {bool askSetup = false}) async {
  if (askSetup) {
    await showSetupDialog(context, store);
    if (!context.mounted) return;
  }
  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen(payGuide: true)));
}

/// Nhãn trắng có ngón tay chỉ, nhấp nháy để người dùng thấy chỗ cần bấm / nhập.
class BlinkingHand extends StatefulWidget {
  const BlinkingHand({super.key, required this.text, this.color});

  final String text;

  /// Màu chữ và ngón tay (mặc định màu chính của app).
  final Color? color;

  @override
  State<BlinkingHand> createState() => _BlinkingHandState();
}

class _BlinkingHandState extends State<BlinkingHand> with SingleTickerProviderStateMixin {
  late final _blink = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    return FadeTransition(
      opacity: Tween(begin: 0.35, end: 1.0).animate(_blink),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1))],
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.touch_app, size: 16, color: color),
              const SizedBox(width: 4),
              Text(widget.text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Nút "Hướng dẫn tính lương" trên thẻ thu nhập: viền nút sáng lên rồi tắt, ngón tay nhấp nháy đè lên
/// mép phải, đầu ngón chỉ vào nút. Lỡ ấn trúng ngón tay thì cũng mở hướng dẫn như ấn nút.
class PayGuideCta extends StatefulWidget {
  const PayGuideCta({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<PayGuideCta> createState() => _PayGuideCtaState();
}

class _PayGuideCtaState extends State<PayGuideCta> with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) => Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            // Chừa chỗ bên phải, bên dưới cho ngón tay đè lên mép nút.
            padding: const EdgeInsets.only(right: 18, bottom: 10),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.25 + 0.5 * _pulse.value),
                    blurRadius: 4 + 10 * _pulse.value,
                    spreadRadius: 1 + 2 * _pulse.value,
                  ),
                ],
              ),
              child: FilledButton.icon(
                key: const ValueKey('home-pay-guide'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: primary,
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.calculate_outlined, size: 18),
                label: const Text('Hướng dẫn tính lương'),
                onPressed: widget.onPressed,
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: -4,
            child: GestureDetector(
              key: const ValueKey('home-pay-hand'),
              onTap: widget.onPressed,
              child: Opacity(
                opacity: 0.45 + 0.55 * _pulse.value,
                child: Transform.translate(
                  offset: Offset(-3 * _pulse.value, -3 * _pulse.value),
                  child: const Icon(
                    Icons.touch_app,
                    size: 30,
                    color: Colors.white,
                    shadows: [Shadow(color: Colors.black38, blurRadius: 4)],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Các chỗ sáng của hướng dẫn, gắn vào thẻ Phiếu lương và Cài đặt tính công.
class PayGuideKeys {
  final basis = GlobalKey();
  final income = GlobalKey();
  final deduction = GlobalKey();
  final wage = GlobalKey();
}

class _GuideStep {
  const _GuideStep(this.key, this.text);
  final GlobalKey key;
  final String text;
}

/// Lớp phủ của hướng dẫn, đặt trên danh sách Cài đặt. [scrollTick] tăng mỗi lần danh sách cuộn để
/// đo lại chỗ sáng.
class PayGuideOverlay extends StatefulWidget {
  const PayGuideOverlay({super.key, required this.keys, required this.kind, required this.scrollTick, required this.onClose});

  final PayGuideKeys keys;
  final WorkerKind kind;
  final ValueNotifier<int> scrollTick;
  final VoidCallback onClose;

  @override
  State<PayGuideOverlay> createState() => _PayGuideOverlayState();
}

class _PayGuideOverlayState extends State<PayGuideOverlay> {
  /// -1: lời mở; bằng số bước: lời kết.
  int _i = -1;

  List<_GuideStep> get _steps {
    final k = widget.keys;
    return widget.kind == WorkerKind.worker
        ? [
            _GuideStep(
              k.basis,
              'Nhập đúng lương cơ bản trên phiếu lương. Có thưởng thành tích (tính theo ngày công) thì nhập luôn ở dưới.',
            ),
            _GuideStep(
              k.income,
              'Khoản thu nhập: phiếu có phụ cấp nào (nhà ở, xăng xe, chuyên cần...) thì sửa số ở đây hoặc bấm '
              '"Thêm khoản thu nhập", mỗi khoản một dòng.',
            ),
            _GuideStep(
              k.deduction,
              'Khoản khấu trừ: bảo hiểm app tự tính BHXH 8% + BHYT 1,5% + BHTN 1% = 10,5% lương cơ bản. Có công đoàn '
              'phí, tiền cơm, tạm ứng thì sửa số hoặc bấm "Thêm khoản khấu trừ".',
            ),
            _GuideStep(
              k.wage,
              'Giá tăng ca: một giờ tăng ca ngày thường, Chủ nhật, ngày lễ được bao nhiêu tiền? Nhập theo phiếu.',
            ),
          ]
        : [
            _GuideStep(k.basis, 'Lương ngày: một ngày làm đủ 8 tiếng được bao nhiêu tiền? App tính một giờ = lương ngày ÷ 8.'),
            _GuideStep(
              k.wage,
              'Giá tăng ca: tăng ca, Chủ nhật, ngày lễ có giá riêng thì nhập vào bảng. Ô nào để 0 thì app lấy lương ngày ÷ 8.',
            ),
            _GuideStep(k.deduction, 'Khoản trừ: có tiền cơm hay khoản trừ khác thì sửa số hoặc bấm "Thêm khoản khấu trừ".'),
          ];
  }

  @override
  void initState() {
    super.initState();
    widget.scrollTick.addListener(_remeasure);
  }

  @override
  void dispose() {
    widget.scrollTick.removeListener(_remeasure);
    super.dispose();
  }

  void _remeasure() {
    if (mounted) setState(() {});
  }

  /// "Đồng nghiệp đã cài sẵn? Dán cấu hình": dán chuỗi đồng nghiệp gửi, rồi chỉ hỏi lại lương cơ bản
  /// (mỗi người một số), xong thì bỏ qua các bước nhập tay.
  Future<void> _pasteConfig() async {
    final store = context.read<AppStore>();
    final clip = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final input = TextEditingController(text: (clip?.text ?? '').trim());
    String? error;
    final applied = await showDialog<AppSettings>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Dán cấu hình của đồng nghiệp'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Nhờ đồng nghiệp vào Cài đặt › Nâng cao › Sao chép cấu hình rồi gửi cho bạn (Zalo, tin nhắn). Bạn '
                'chép dòng đó rồi dán vào đây.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const ValueKey('pay-guide-paste-input'),
                controller: input,
                maxLines: 3,
                decoration: InputDecoration(border: const OutlineInputBorder(), hintText: 'CCDG1 {...}', errorText: error),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
            FilledButton(
              key: const ValueKey('pay-guide-paste-ok'),
              onPressed: () {
                final decoded = decodeSettings(input.text, current: store.settings);
                if (decoded == null) {
                  setDialogState(() => error = 'Không phải cấu hình của app. Nhờ đồng nghiệp sao chép lại nhé.');
                } else {
                  Navigator.pop(context, decoded);
                }
              },
              child: const Text('Dùng cấu hình này'),
            ),
          ],
        ),
      ),
    );
    if (applied == null || !mounted) return;
    await store.replaceSettings(applied);
    if (!mounted) return;
    // Lương cơ bản (công nhật: lương ngày) mỗi người một khác: hỏi lại đúng một ô đó.
    final worker = applied.workerKind == WorkerKind.worker;
    final current = worker ? applied.baseSalary : applied.dailyWage;
    final salary = TextEditingController(text: current > 0 ? current.toStringAsFixed(0) : '');
    final mine = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(worker ? 'Lương cơ bản của bạn' : 'Lương ngày của bạn'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Đã lấy cách tính lương của đồng nghiệp. ${worker ? 'Lương cơ bản' : 'Lương ngày'} mỗi người thường '
              'khác nhau, bạn sửa thành số của mình nhé.',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey('pay-guide-salary'),
              controller: salary,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(border: const OutlineInputBorder(), suffixText: worker ? 'đ/tháng' : 'đ/ngày'),
            ),
          ],
        ),
        actions: [
          FilledButton(
            key: const ValueKey('pay-guide-salary-ok'),
            onPressed: () => Navigator.pop(context, double.tryParse(salary.text.trim())),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    if (mine != null) {
      await store.updateSettings((s) => worker ? s.copyWith(baseSalary: mine) : s.copyWith(dailyWage: mine));
    }
    if (mounted) setState(() => _i = _steps.length); // sang lời kết
  }

  Future<void> _go(int i) async {
    setState(() => _i = i);
    if (i < 0 || i >= _steps.length) return;
    await WidgetsBinding.instance.endOfFrame;
    final ctx = _steps[i].key.currentContext;
    if (ctx != null && ctx.mounted) {
      await Scrollable.ensureVisible(ctx, alignment: 0.3, duration: const Duration(milliseconds: 350));
    }
    _remeasure();
  }

  Rect? _hole() {
    if (_i < 0 || _i >= _steps.length) return null;
    final target = _steps[_i].key.currentContext?.findRenderObject() as RenderBox?;
    final me = context.findRenderObject() as RenderBox?;
    if (target == null || me == null || !target.attached) return null;
    final topLeft = target.localToGlobal(Offset.zero, ancestor: me);
    return (topLeft & target.size).inflate(6);
  }

  @override
  Widget build(BuildContext context) {
    final steps = _steps;
    final scheme = Theme.of(context).colorScheme;
    final shade = Colors.black.withValues(alpha: 0.55);

    Widget box({
      required String? number,
      required String title,
      required String text,
      required List<Widget> actions,
      Widget? below,
    }) =>
        Material(
          color: scheme.surface,
          elevation: 6,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (number != null)
                  Text(number, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: scheme.primary)),
                if (title.isNotEmpty) Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(text, style: const TextStyle(fontSize: 13.5, height: 1.5)),
                const SizedBox(height: 4),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: actions),
                ?below,
              ],
            ),
          ),
        );

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        // Lời mở và lời kết: hộp giữa màn, phủ mờ hết.
        if (_i < 0 || _i >= steps.length) {
          final intro = _i < 0;
          return Stack(
            children: [
              Positioned.fill(child: ColoredBox(color: shade)),
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: box(
                    number: null,
                    title: intro ? 'Hướng dẫn nhập phiếu lương' : 'Đã nhập xong phiếu lương',
                    text: intro
                        ? 'Bạn lấy phiếu lương tháng trước ra (giấy hoặc ảnh chụp) để nhập theo từng dòng nhé. Số tiền app '
                              'tính chỉ là ước tính để tham khảo, bạn có thể bỏ qua phần này.'
                        : 'Số tiền ước tính hiện ở thẻ thu nhập trên màn chính. Phiếu lương của kỳ được tính khi hết kỳ.',
                    below: intro
                        ? Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              key: const ValueKey('pay-guide-paste'),
                              icon: const Icon(Icons.content_paste, size: 18),
                              label: const Text('Đồng nghiệp đã cài sẵn? Dán cấu hình'),
                              onPressed: _pasteConfig,
                            ),
                          )
                        : null,
                    actions: [
                      if (intro) TextButton(onPressed: widget.onClose, child: const Text('Để sau')),
                      FilledButton(
                        key: const ValueKey('pay-guide-next'),
                        onPressed: intro ? () => _go(0) : widget.onClose,
                        child: Text(intro ? 'Bắt đầu' : 'Xong'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }

        final hole = _hole() ?? Rect.fromLTWH(16, size.height * 0.3, size.width - 32, 80);
        final tipAbove = hole.top > size.height - hole.bottom;
        final last = _i == steps.length - 1;
        // Bốn tấm phủ quanh chỗ sáng: chỗ sáng để trống nên chạm, gõ xuyên xuống được.
        Widget shadeRect(Rect r) => Positioned.fromRect(
          rect: r,
          child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () {}, child: ColoredBox(color: shade)),
        );
        return Stack(
          children: [
            shadeRect(Rect.fromLTRB(0, 0, size.width, hole.top.clamp(0, size.height))),
            shadeRect(Rect.fromLTRB(0, hole.bottom.clamp(0, size.height), size.width, size.height)),
            shadeRect(Rect.fromLTRB(0, hole.top, hole.left.clamp(0, size.width), hole.bottom)),
            shadeRect(Rect.fromLTRB(hole.right.clamp(0, size.width), hole.top, size.width, hole.bottom)),
            Positioned.fromRect(
              rect: hole,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: scheme.primary, width: 2.5),
                  ),
                ),
              ),
            ),
            // Nhãn ngón tay "Nhập vào đây", cùng kiểu chuyến hướng dẫn cơ bản: nằm phía đối diện hộp chỉ
            // dẫn; sát mép màn quá thì đặt ngay trong mép trên của chỗ sáng.
            Positioned(
              key: const ValueKey('pay-guide-hand'),
              left: (hole.center.dx - 58).clamp(8.0, math.max(8.0, size.width - 124)).toDouble(),
              width: 116,
              top: tipAbove
                  ? (hole.bottom + 6 > size.height - 40 ? hole.bottom - 34 : hole.bottom + 6)
                  : (hole.top - 34 < 4 ? hole.top + 6 : hole.top - 34),
              child: const IgnorePointer(child: BlinkingHand(text: 'Nhập vào đây')),
            ),
            Positioned(
              left: 16,
              right: 16,
              top: tipAbove ? null : (hole.bottom + 10).clamp(0, size.height - 160),
              bottom: tipAbove ? (size.height - hole.top + 10).clamp(0, size.height - 160) : null,
              child: box(
                number: 'Bước ${_i + 1}/${steps.length}',
                title: '',
                text: steps[_i].text,
                actions: [
                  TextButton(onPressed: widget.onClose, child: const Text('Bỏ qua')),
                  if (_i > 0) TextButton(onPressed: () => _go(_i - 1), child: const Text('Lùi')),
                  FilledButton(
                    key: const ValueKey('pay-guide-next'),
                    onPressed: () => _go(_i + 1),
                    child: Text(last ? 'Xong' : 'Tiếp'),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
