import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../domain/models.dart';
import '../data/store.dart';

import '../theme/app_theme.dart';
import 'tour_controller.dart';

/// Lớp phủ của chuyến hướng dẫn (theo `mockup/huong-dan-tung-buoc.html`): phủ mờ cả màn hình,
/// khoét sáng đúng một chỗ; chỉ chỗ sáng bấm được ở các bước chờ thao tác. Đặt trong một `Stack`
/// phủ toàn màn chính.
/// Tổng số bước có số (8 trên màn chính, 9 và 10 là GPS ở Cài đặt).
const tourStepCount = 10;

class TourOverlay extends StatefulWidget {
  const TourOverlay({
    super.key,
    required this.controller,
    required this.targets,
    required this.onSkip,
    required this.onFinish,
  });

  final TourController controller;

  /// Chỗ sáng của từng bước; màn chính giữ các [GlobalKey] này.
  final Map<TourStep, GlobalKey> targets;

  /// "Bỏ qua" ở góc mỗi bước (và "Để sau" ở bước cuối).
  final VoidCallback onSkip;

  /// "Tiếp theo" ở bước cuối: dọn dữ liệu tập rồi mở Cài đặt.
  final VoidCallback onFinish;

  @override
  State<TourOverlay> createState() => _TourOverlayState();
}

class _TourOverlayState extends State<TourOverlay> with SingleTickerProviderStateMixin {
  // Vòng sáng nhấp nháy; cũng làm nhịp dựng lại để chỗ sáng bám theo khi lịch đang cuộn.
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat();
  TourStep? _lastStep;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    _onChanged();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _pulse.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
    final step = widget.controller.step;
    if (step == _lastStep) return;
    _lastStep = step;
    if (step == null || step.isDialog) return;
    // Chỗ sáng nằm ngoài màn hình thì cuộn tới. Lịch và thẻ thống kê dài nên đặt sát mép trên để
    // còn chỗ cho hộp chỉ dẫn bên dưới.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = widget.targets[step]?.currentContext;
      if (!mounted || ctx == null || widget.controller.step != step) return;
      final alignment = switch (step) {
        TourStep.calendar || TourStep.stats || TourStep.topButtons => 0.0,
        _ => 0.5,
      };
      Scrollable.ensureVisible(ctx, alignment: alignment, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    });
  }

  /// Hình chữ nhật của chỗ sáng, theo toạ độ của lớp phủ; null nếu chưa đo được.
  Rect? _holeRect(TourStep step) {
    final box = widget.targets[step]?.currentContext?.findRenderObject();
    final mine = context.findRenderObject();
    if (box is! RenderBox || mine is! RenderBox) return null;
    if (!box.attached || !box.hasSize || !mine.attached || !mine.hasSize) return null;
    final topLeft = mine.globalToLocal(box.localToGlobal(Offset.zero));
    return (topLeft & box.size).inflate(4);
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.controller.step;
    if (step == null) return const SizedBox.shrink();
    if (step.isDialog) return _dialogLayer(context, step);
    return AnimatedBuilder(animation: _pulse, builder: (context, _) => _spotLayer(context, step));
  }

  // ---------------------------------------------------------------- hộp thoại giữa màn hình

  Widget _dialogLayer(BuildContext context, TourStep step) {
    final c = widget.controller;
    final String title;
    final List<Widget> body;
    final String okText;
    final String? skipText;
    final VoidCallback onOk;
    final VoidCallback? onSkip;
    switch (step) {
      case TourStep.intro:
        title = 'Hướng dẫn cách dùng';
        body = [_bodyText('Mình sẽ hướng dẫn bạn cách dùng, hãy làm theo chỉ dẫn nhé.')];
        okText = 'Bắt đầu';
        skipText = 'Bỏ qua';
        onOk = c.next;
        onSkip = widget.onSkip;
      case TourStep.manual:
        title = 'Nhập tay';
        body = [_bodyText('Chức năng nhập tay này được dùng khi bạn không muốn dùng tự động chấm công hoặc muốn sửa lại.')];
        okText = 'Tiếp';
        skipText = null;
        onOk = c.next;
        onSkip = null;
      default:
        title = 'Phần chấm công đã xong';
        body = [
          _bodyText('Bước 9 và 10: cài chấm công tự động bằng GPS. Bấm Tiếp theo nhé.'),
          const SizedBox(height: 14),
          const Text(
            'Để dùng chức năng này, bây giờ bạn hãy đến chỗ nơi bạn hay chấm công nhé, hoặc chờ lúc về, cài đặt sau.',
            style: TextStyle(fontSize: 12, height: 1.5, color: _ink2),
          ),
        ];
        okText = 'Tiếp theo';
        skipText = 'Để sau';
        onOk = widget.onFinish;
        onSkip = widget.onSkip;
    }
    return Stack(
      children: [
        // Chặn mọi chạm ra ngoài hộp.
        Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () {}, child: const ColoredBox(color: Color(0x94000000)))),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _ink)),
                    const SizedBox(height: 8),
                    ...body,
                    const SizedBox(height: 14),
                    FilledButton(
                      style: FilledButton.styleFrom(shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(vertical: 10)),
                      onPressed: onOk,
                      child: Text(okText, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                    if (skipText != null) ...[
                      const SizedBox(height: 4),
                      TextButton(
                        style: TextButton.styleFrom(foregroundColor: _ink2, padding: const EdgeInsets.all(10)),
                        onPressed: onSkip,
                        child: Text(skipText, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _bodyText(String text) => Text(text, style: const TextStyle(fontSize: 13, height: 1.55, color: _ink));

  // ---------------------------------------------------------------- khoét sáng một chỗ

  static const _tipMargin = 14.0;

  Widget _spotLayer(BuildContext context, TourStep step) {
    final c = widget.controller;
    final size = MediaQuery.sizeOf(context);
    final hole = _holeRect(step);
    final passThrough = step.waitsForAction;

    final text = switch (step) {
      TourStep.checkIn => 'Đây là nút chấm giờ vào/ra. Bạn hãy bấm vào và nhập giờ vào của bạn nhé.',
      TourStep.checkOut => 'Bấm lại nút này và nhập giờ ra của bạn nhé.',
      TourStep.pickDayOff => c.pickDayOffText,
      TourStep.chooseDayOff => context.read<AppStore>().settings.workerKind == WorkerKind.worker
          ? 'Bấm nút Ngày nghỉ, chọn Tự nghỉ hoặc Công ty cho nghỉ. Dòng nhỏ dưới "Tự nghỉ" cho biết bạn còn mấy ngày phép.'
          : 'Bấm nút Ngày nghỉ, rồi chọn nghỉ có lương hay không lương.',
      TourStep.lateButton => 'Nếu tự đi muộn, bấm nút Đi muộn.',
      TourStep.note => 'Bạn muốn ghi nhớ điều gì hôm nay thì có thể ghi lại ở đây, như bị ốm chẳng hạn.',
      TourStep.calendar =>
        'Mỗi ô có giờ vào, giờ ra, và tiền của ngày nếu đã cài lương. Số màu cam ở góc là giờ tăng ca, số có dấu "−" '
            'là giờ thiếu được lấy tăng ca bù. Ô hồng đậm "Phép" là ngày nghỉ phép. "Chưa" là ngày chưa chấm.',
      TourStep.stats =>
        'Thống kê nhanh của kỳ này: ngày công, giờ tăng ca, giờ tăng ca bị trừ và số ngày nghỉ. Bấm vào "Trừ tăng ca" '
            'để xem chi tiết trừ cho ngày nào, bao nhiêu giờ. Nút mặt trăng ở trên cùng bật ngày âm lịch.',
      _ =>
        'Nút mặt trăng bật ngày âm lịch trong từng ô lịch.',
    };

    // Hộp chỉ dẫn nằm phía có nhiều chỗ hơn so với chỗ sáng; nhãn "Bấm vào đây" ở phía đối diện.
    final tipAbove = hole != null && hole.top > size.height - hole.bottom;
    final children = <Widget>[];

    // Lớp chặn chạm: chỗ sáng ở các bước chờ thao tác thì bỏ trống để chạm xuyên xuống; các bước
    // chỉ giải thích thì chặn luôn cả chỗ sáng.
    Widget blocker(Rect r) => Positioned.fromRect(
      rect: r,
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () {}, onVerticalDragStart: (_) {}, child: const SizedBox.expand()),
    );
    final full = Offset.zero & size;
    if (hole == null || !passThrough) {
      children.add(blocker(full));
    } else {
      final h = hole.intersect(full);
      children.add(blocker(Rect.fromLTRB(0, 0, size.width, h.top)));
      children.add(blocker(Rect.fromLTRB(0, h.bottom, size.width, size.height)));
      children.add(blocker(Rect.fromLTRB(0, h.top, h.left, h.bottom)));
      children.add(blocker(Rect.fromLTRB(h.right, h.top, size.width, h.bottom)));
    }

    children.add(
      Positioned.fill(
        child: IgnorePointer(
          child: CustomPaint(painter: _SpotPainter(hole: hole, pulse: _pulse.value)),
        ),
      ),
    );

    if (hole != null && passThrough) {
      const labelWidth = 116.0;
      final left = (hole.center.dx - labelWidth / 2).clamp(8.0, math.max(8.0, size.width - labelWidth - 8)).toDouble();
      children.add(
        Positioned(
          left: left,
          top: tipAbove ? hole.bottom + 6 : null,
          bottom: tipAbove ? null : size.height - hole.top + 6,
          width: labelWidth,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
              child: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.touch_app, size: 16, color: _ink),
                    SizedBox(width: 4),
                    Text('Bấm vào đây', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _ink)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final tip = _tipCard(context, step, text);
    final pad = MediaQuery.paddingOf(context);
    if (hole == null) {
      children.add(Positioned(left: 16, right: 16, top: size.height * 0.35, child: tip));
    } else if (tipAbove) {
      children.add(Positioned(left: 16, right: 16, bottom: math.max(pad.bottom + 8, size.height - hole.top + _tipMargin), child: tip));
    } else {
      children.add(Positioned(left: 16, right: 16, top: math.max(pad.top + 8, hole.bottom + _tipMargin), child: tip));
    }
    return Stack(children: children);
  }

  Widget _tipCard(BuildContext context, TourStep step, String text) {
    final accent = Theme.of(context).colorScheme.primary;
    return Material(
      color: Colors.white,
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bước ${step.number}/$tourStepCount', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: accent)),
            const SizedBox(height: 2),
            Text(text, style: const TextStyle(fontSize: 13.5, height: 1.5, color: _ink)),
            const SizedBox(height: 6),
            Row(
              children: [
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: context.appColors.ink3,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: widget.onSkip,
                  child: const Text('Bỏ qua', style: TextStyle(fontSize: 11.5)),
                ),
                const Spacer(),
                if (step.waitsForAction)
                  Text('Chạm vào chỗ sáng để thử', style: TextStyle(fontSize: 11.5, color: context.appColors.ink3))
                else
                  FilledButton(
                    style: FilledButton.styleFrom(
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: widget.controller.next,
                    child: const Text('Tiếp', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

const _ink = Color(0xFF1B2420);
const _ink2 = Color(0xFF52615B);

/// Lớp mờ có lỗ bo góc ở chỗ sáng, cộng vòng trắng nhấp nháy quanh lỗ.
class _SpotPainter extends CustomPainter {
  _SpotPainter({required this.hole, required this.pulse});

  final Rect? hole;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final dim = Paint()..color = const Color(0x94000000);
    final full = Path()..addRect(Offset.zero & size);
    if (hole == null) {
      canvas.drawPath(full, dim);
      return;
    }
    final rrect = RRect.fromRectAndRadius(hole!, const Radius.circular(14));
    canvas.drawPath(Path.combine(PathOperation.difference, full, Path()..addRRect(rrect)), dim);
    canvas.drawRRect(rrect, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white);
    // Sóng loang ra ngoài rồi mờ dần.
    final grow = pulse * 12;
    canvas.drawRRect(
      RRect.fromRectAndRadius(hole!.inflate(grow), Radius.circular(14 + grow)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.7 * (1 - pulse)),
    );
  }

  @override
  bool shouldRepaint(_SpotPainter old) => old.hole != hole || old.pulse != pulse;
}
