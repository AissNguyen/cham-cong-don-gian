import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Tọa độ ví dụ dùng trong lời hướng dẫn và hình động (không phải chỗ làm thật của ai).
const gpsExampleCoords = '10,7724983, 106,6980146';

/// Mở Google Maps. Đã có tọa độ thì mở ngay chỗ đó để người dùng xem lại ghim có đúng không.
Future<bool> openGoogleMaps({double? latitude, double? longitude}) async {
  final uri = latitude != null && longitude != null
      ? Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': '$latitude,$longitude'})
      : Uri.https('www.google.com', '/maps');
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

class GpsDemoStep {
  const GpsDemoStep(this.start, this.text, this.sub);
  final double start;
  final String text;
  final String sub;
}

const gpsDemoSteps = [
  GpsDemoStep(0, 'Mở Google Maps, tìm tới chỗ làm', 'Gõ tên công ty vào ô tìm kiếm, hoặc kéo bản đồ.'),
  GpsDemoStep(0.8, 'Phóng to bản đồ thật gần',
      'Đặt hai ngón tay lên bản đồ rồi kéo ra, tới khi thấy rõ chỗ bạn chấm công.'),
  GpsDemoStep(3.8, 'Giữ ngón tay lên đúng chỗ chấm công',
      'Ví dụ cổng công ty. Phóng càng to thì tọa độ càng chính xác. Dãy số hiện ở ô tìm kiếm.'),
  GpsDemoStep(7.2, 'Giữ ngón tay lên dãy số, bấm Sao chép', 'Máy báo đã sao chép.'),
  GpsDemoStep(12.4, 'Mở Chấm Công › Cài đặt › Chấm công GPS', 'Bấm nút Nhập tọa độ.'),
  GpsDemoStep(15.2, 'Giữ ngón tay vào ô trống, bấm Dán', 'Dãy số vừa chép hiện vào ô.'),
  GpsDemoStep(19.0, 'Bấm Lưu là xong', 'Thẻ GPS báo Đã có tọa độ.'),
];

/// Hình động dài 23,8 giây, nghỉ một chút rồi chạy lại.
const _demoEnd = 23.8;
const _demoLoop = 26.0;

int gpsDemoStepAt(double t) {
  var i = 0;
  for (var j = 0; j < gpsDemoSteps.length; j++) {
    if (t >= gpsDemoSteps[j].start) i = j;
  }
  return i;
}

Future<void> showGpsCoordsDemo(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const _GpsDemoDialog());

class _GpsDemoDialog extends StatelessWidget {
  const _GpsDemoDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Lấy tọa độ từ Google Maps', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  key: const ValueKey('gps-demo-close'),
                  tooltip: 'Đóng',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Flexible(child: Padding(padding: EdgeInsets.only(right: 8), child: GpsCoordsDemo())),
          ],
        ),
      ),
    );
  }
}

/// Hình động chỉ cách chép tọa độ chỗ làm từ Google Maps rồi dán vào app (giống mockup
/// `mockup/gps-nhap-toa-do.html`). Vẽ bằng widget, không dùng file video.
class GpsCoordsDemo extends StatefulWidget {
  const GpsCoordsDemo({super.key});

  @override
  State<GpsCoordsDemo> createState() => _GpsCoordsDemoState();
}

class _GpsCoordsDemoState extends State<GpsCoordsDemo> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 26000), // = _demoLoop
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.of(context).disableAnimations) {
      // Máy tắt hiệu ứng chuyển động: đứng ở bước giữ ngón tay lên chỗ làm, người dùng tự bấm chạy.
      _c.value = 6.5 / _demoLoop;
    } else {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _toggle() => setState(() => _c.isAnimating ? _c.stop() : _c.repeat());

  void _restart() => setState(() {
    _c.value = 0;
    _c.repeat();
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = math.min(_c.value * _demoLoop, _demoEnd);
        final i = gpsDemoStepAt(t);
        final step = gpsDemoSteps[i];
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: GestureDetector(
                onTap: _toggle,
                child: AspectRatio(
                  aspectRatio: 316 / 616,
                  child: FittedBox(child: _Phone(t: t)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${i + 1}/${gpsDemoSteps.length} · ${step.text}',
              key: const ValueKey('gps-demo-caption'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
            ),
            const SizedBox(height: 2),
            Text(
              step.sub,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 6),
            Wrap(
              alignment: WrapAlignment.center,
              children: [
                TextButton.icon(
                  key: const ValueKey('gps-demo-play'),
                  icon: Icon(_c.isAnimating ? Icons.pause : Icons.play_arrow),
                  label: Text(_c.isAnimating ? 'Tạm dừng' : 'Chạy'),
                  onPressed: _toggle,
                ),
                TextButton.icon(
                  icon: const Icon(Icons.replay),
                  label: const Text('Xem lại'),
                  onPressed: _restart,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

// ---------- tính trạng thái theo thời gian ----------

double _ramp(double t, double a, double dur) => ((t - a) / dur).clamp(0.0, 1.0);

/// 0 → 1 lúc [a], 1 → 0 lúc [b].
double _win(double t, double a, double b, [double d = 0.2]) => math.min(_ramp(t, a, d), 1 - _ramp(t, b, d));

bool _in(double t, double a, double b) => t >= a && t < b;

double _ease(double k) => k < .5 ? 2 * k * k : 1 - math.pow(-2 * k + 2, 2) / 2;

const _spot = Offset(169, 336); // chỗ chấm công (cổng xưởng) trên bản đồ
const _coordText = Offset(124, 57);
const _copyBtn = Offset(112, 106);
const _btnEnter = Offset(214, 193);
const _field = Offset(150, 282);
const _pasteChip = Offset(68, 251);
const _btnSave = Offset(248, 334);
const _offscreen = Offset(330, 640);

const _keyframes = <(double, Offset)>[
  (0, _offscreen), (0.85, Offset(169 - 14, 336 + 14)), (3.6, Offset(169 - 55, 336 + 55)),
  (4.4, _spot), (6.4, _spot), (7.6, _coordText), (9.4, _coordText), (10.0, _copyBtn), (11.0, _copyBtn),
  (12.4, Offset(170, 430)), (14.0, _btnEnter), (15.4, _btnEnter), (16.0, _field), (17.4, _field),
  (17.9, _pasteChip), (18.8, _pasteChip), (19.5, _btnSave), (20.8, _btnSave), (22.2, _offscreen),
];

const _downs = [(1.1, 3.4), (4.8, 5.9), (8.0, 9.0), (10.2, 10.4), (14.4, 14.6), (16.2, 17.2), (18.1, 18.3), (19.7, 19.9)];
const _holds = [4.8, 8.0, 16.2];

// Phóng to bằng hai ngón: hai ngón cách chỗ làm từ 14 ra 55, bản đồ to gấp 2,2.
const _pinchFrom = 0.9, _pinchTo = 3.6, _pinchA = 1.1, _pinchB = 3.4, _zoom = 2.2;

Offset _fingerAt(double t) {
  if (t >= _pinchFrom && t < _pinchTo) return _spot + Offset(-1, 1) * _pinchGap(t);
  var i = 0;
  while (i < _keyframes.length - 1 && t >= _keyframes[i + 1].$1) {
    i++;
  }
  final a = _keyframes[i], b = _keyframes[math.min(i + 1, _keyframes.length - 1)];
  final k = b.$1 == a.$1 ? 1.0 : _ease(((t - a.$1) / (b.$1 - a.$1)).clamp(0.0, 1.0));
  return Offset.lerp(a.$2, b.$2, k)!;
}

double _pinchK(double t) => _ease(_ramp(t, _pinchA, _pinchB - _pinchA));
double _pinchGap(double t) => 14 + (55 - 14) * _pinchK(t);

// ---------- vẽ ----------

/// Khung cố định kích thước: chữ to quá (máy để cỡ chữ lớn) thì cắt bớt phía dưới, không báo lỗi tràn.
Widget _clipTop(Widget child) => ClipRect(
  child: OverflowBox(alignment: Alignment.topLeft, maxHeight: double.infinity, child: child),
);

const _ink = Color(0xFF1B2420);
const _green = Color(0xFF17695A);
const _greenSoft = Color(0xFFDCEEE9);
const _hitBlue = Color(0xFFE8F0FE);

class _Phone extends StatelessWidget {
  const _Phone({required this.t});
  final double t;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 316,
      height: 616,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: const Color(0xFF1A1F1D), borderRadius: BorderRadius.circular(36)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: SizedBox(
          width: 300,
          height: 600,
          child: DefaultTextStyle(
            style: const TextStyle(color: _ink, fontSize: 13, height: 1.35, decoration: TextDecoration.none),
            child: _Screen(t: t),
          ),
        ),
      ),
    );
  }
}

class _Screen extends StatelessWidget {
  const _Screen({required this.t});
  final double t;

  @override
  Widget build(BuildContext context) {
    final appK = _ramp(t, 12.4, 0.45);
    final toast = _in(t, 10.4, 12.0)
        ? 'Đã sao chép vào bộ nhớ tạm'
        : _in(t, 19.9, 22.2)
        ? 'Đã lưu tọa độ chỗ làm'
        : null;
    final toastK = math.max(_win(t, 10.4, 12.0, 0.25), _win(t, 19.9, 22.2, 0.25));
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        if (appK < 1)
          Positioned.fill(
            child: Opacity(
              opacity: 1 - appK,
              child: Transform.translate(offset: Offset(-24 * appK, 0), child: _MapsLayer(t: t)),
            ),
          ),
        if (appK > 0)
          Positioned.fill(
            child: Opacity(
              opacity: appK,
              child: Transform.translate(offset: Offset(24 * (1 - appK), 0), child: _AppLayer(t: t)),
            ),
          ),
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 24,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('7:30', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                Text('85%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
        if (toast != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 46 - 8 * (1 - toastK),
            child: Opacity(
              opacity: toastK,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: const Color(0xFF303433), borderRadius: BorderRadius.circular(99)),
                  child: Text(toast, style: const TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ),
            ),
          ),
        _finger(_fingerAt(t), _win(t, 0.4, 22.2, 0.3), _downs.any((d) => _in(t, d.$1, d.$2)), _holdProgress()),
        if (_in(t, _pinchFrom - 0.2, _pinchTo + 0.2))
          _finger(_spot + Offset(1, -1) * _pinchGap(t), _win(t, _pinchFrom, _pinchTo), _in(t, 1.1, 3.4), null),
      ],
    );
  }

  double? _holdProgress() {
    for (final s in _holds) {
      if (_in(t, s, s + 0.8)) return (t - s) / 0.8;
    }
    return null;
  }

  Widget _finger(Offset p, double opacity, bool down, double? hold) {
    return Positioned(
      left: p.dx - 19,
      top: p.dy - 19,
      width: 38,
      height: 38,
      child: IgnorePointer(
        child: Opacity(
          opacity: opacity,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (hold != null)
                Positioned.fill(
                  child: Transform.scale(
                    scale: 0.6 + 1.3 * hold,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: _green.withValues(alpha: 0.9 * (1 - hold)), width: 3),
                      ),
                    ),
                  ),
                ),
              Positioned.fill(
                child: Transform.scale(
                  scale: down ? 0.78 : 1,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: down ? _green.withValues(alpha: 0.55) : const Color(0x612A2E2C),
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: const [BoxShadow(color: Color(0x4D000000), blurRadius: 6, offset: Offset(0, 2))],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapsLayer extends StatelessWidget {
  const _MapsLayer({required this.t});
  final double t;

  @override
  Widget build(BuildContext context) {
    final coords = t >= 5.7;
    final sel = _in(t, 8.8, 10.4);
    final menuK = _win(t, 8.8, 10.4);
    final pinK = _ease(_ramp(t, 5.7, 0.35));
    final sheetK = _ease(_ramp(t, 5.7, 0.35));
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(painter: _MapPainter(1 + (_zoom - 1) * _pinchK(t))),
        ),
        Positioned(
          left: 12,
          top: 34,
          width: 276,
          height: 46,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(23),
              boxShadow: const [BoxShadow(color: Color(0x2E000000), blurRadius: 6, offset: Offset(0, 2))],
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                const Icon(Icons.search, size: 20, color: Color(0xFF5F6368)),
                const SizedBox(width: 10),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: coords
                        ? Container(
                            color: sel ? const Color(0xFFB6D4FB) : null,
                            child: const Text(
                              gpsExampleCoords,
                              maxLines: 1,
                              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: Color(0xFF202124)),
                            ),
                          )
                        : const Text('Tìm kiếm ở đây', style: TextStyle(fontSize: 13.5, color: Color(0xFF70757A))),
                  ),
                ),
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: Color(0xFF7B61B8), shape: BoxShape.circle),
                  child: const Text('A', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 12),
              ],
            ),
          ),
        ),
        if (menuK > 0)
          Positioned(
            left: 30,
            top: 88 + 6 * (1 - menuK),
            height: 36,
            child: Opacity(
              opacity: menuK,
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 12, offset: Offset(0, 3))],
                ),
                child: Row(
                  children: [
                    _menuItem('Cắt', 44, false),
                    _menuItem('Sao chép', 76, _in(t, 10.2, 10.4)),
                    _menuItem('Chọn tất cả', 92, false),
                  ],
                ),
              ),
            ),
          ),
        if (pinK > 0)
          Positioned(
            left: _spot.dx - 14,
            top: _spot.dy - 38 - 26 * (1 - pinK),
            width: 28,
            height: 38,
            child: Opacity(opacity: pinK, child: const CustomPaint(painter: _PinPainter())),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: -155 * (1 - sheetK),
          height: 150,
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              boxShadow: [BoxShadow(color: Color(0x26000000), blurRadius: 10, offset: Offset(0, -2))],
            ),
            child: _clipTop(Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 34,
                    height: 4,
                    decoration: BoxDecoration(color: const Color(0xFFD0D4D8), borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 10),
                const Text('Ghim đã thả', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const Text(gpsExampleCoords, style: TextStyle(fontSize: 12.5, color: Color(0xFF5F6368))),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final label in ['Chỉ đường', 'Lưu', 'Chia sẻ'])
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFDADCE0)),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          label,
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF1A73E8)),
                        ),
                      ),
                  ],
                ),
              ],
            )),
          ),
        ),
      ],
    );
  }

  Widget _menuItem(String label, double width, bool hit) => Container(
    width: width,
    color: hit ? _hitBlue : null,
    alignment: Alignment.center,
    child: Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: Color(0xFF202124))),
  );
}

class _AppLayer extends StatelessWidget {
  const _AppLayer({required this.t});
  final double t;

  @override
  Widget build(BuildContext context) {
    final dialogK = _win(t, 14.6, 19.9, 0.25);
    final saved = t >= 19.9;
    final pasteK = _win(t, 17.0, 18.3);
    final filled = t >= 18.3;
    final caretOn = (t * 2).floor().isEven;
    return Container(
      color: const Color(0xFFEEF2F0),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            width: 300,
            height: 80,
            child: Container(
              color: _green,
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
              child: const Row(
                children: [
                  Icon(Icons.arrow_back, color: Colors.white, size: 20),
                  SizedBox(width: 12),
                  Text('Cài đặt', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
          _card(
            top: 96,
            height: 150,
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Padding(
                          padding: EdgeInsets.only(right: 6),
                          child: Icon(Icons.place, size: 16, color: _green),
                        ),
                      ),
                      TextSpan(text: 'Chấm công GPS'),
                    ],
                  ),
                  maxLines: 1,
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 4),
                Text(
                  'Đứng ở nơi chấm công rồi bấm lấy tọa độ. Cấp đủ quyền thì app mới tự chấm khi không mở.',
                  maxLines: 2,
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF4A5853)),
                ),
              ],
            ),
          ),
          _outlined(left: 26, label: 'Lấy tọa độ', hit: false),
          _outlined(left: 154, label: 'Nhập tọa độ', hit: _in(t, 14.4, 14.6)),
          Positioned(
            left: 26,
            top: 220,
            child: Text(
              saved ? '✓ Đã có tọa độ' : '● Chưa có tọa độ',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: saved ? _green : const Color(0xFFA65A00)),
            ),
          ),
          _card(
            top: 262,
            height: 66,
            opacity: 0.55,
            child: const Text('Cài đặt tính công', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
          ),
          _card(
            top: 340,
            height: 66,
            opacity: 0.55,
            child: const Text('Lương và phụ cấp', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
          ),
          if (dialogK > 0) ...[
            Positioned.fill(child: ColoredBox(color: Colors.black.withValues(alpha: 0.4 * dialogK))),
            Positioned(
              left: 18,
              top: 150,
              width: 264,
              height: 212,
              child: Opacity(
                opacity: dialogK,
                child: Transform.scale(
                  scale: 0.96 + 0.04 * dialogK,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 30, offset: Offset(0, 10))],
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Positioned(
                          left: 20,
                          top: 20,
                          child: Text('Nhập tọa độ chỗ làm', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        ),
                        const Positioned(
                          left: 20,
                          top: 52,
                          width: 224,
                          child: Text(
                            'Dán dãy số chép từ Google Maps, ví dụ $gpsExampleCoords.',
                            maxLines: 3,
                            style: TextStyle(fontSize: 11.5, color: Color(0xFF4A5853)),
                          ),
                        ),
                        Positioned(
                          left: 20,
                          top: 106,
                          width: 224,
                          height: 46,
                          child: Container(
                            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _green, width: 2))),
                            child: Stack(
                              children: [
                                const Positioned(
                                  left: 2,
                                  top: 0,
                                  child: Text(
                                    'Tọa độ',
                                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: _green),
                                  ),
                                ),
                                Positioned(
                                  left: 2,
                                  right: 2,
                                  bottom: 5,
                                  child: Text.rich(
                                    TextSpan(
                                      children: [
                                        if (filled) const TextSpan(text: gpsExampleCoords),
                                        WidgetSpan(
                                          alignment: PlaceholderAlignment.middle,
                                          child: Container(
                                            width: 1.5,
                                            height: 16,
                                            color: caretOn ? _green : Colors.transparent,
                                          ),
                                        ),
                                      ],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.clip,
                                    style: const TextStyle(fontSize: 13.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (pasteK > 0)
                          Positioned(
                            left: 22,
                            top: 86 + 6 * (1 - pasteK),
                            width: 56,
                            height: 30,
                            child: Opacity(
                              opacity: pasteK,
                              child: Container(
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _in(t, 18.1, 18.3) ? _hitBlue : Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: const [
                                    BoxShadow(color: Color(0x40000000), blurRadius: 10, offset: Offset(0, 3)),
                                  ],
                                ),
                                child: const Text('Dán', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ),
                        _dialogAction(left: 152, label: 'Hủy', hit: false),
                        _dialogAction(left: 202, label: 'Lưu', hit: _in(t, 19.7, 19.9)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _card({required double top, required double height, required Widget child, double opacity = 1}) => Positioned(
    left: 12,
    top: top,
    width: 276,
    height: height,
    child: Opacity(
      opacity: opacity,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 3, offset: Offset(0, 1))],
        ),
        child: _clipTop(child),
      ),
    ),
  );

  Widget _outlined({required double left, required String label, required bool hit}) => Positioned(
    left: left,
    top: 176,
    width: 120,
    height: 34,
    child: Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: hit ? _greenSoft : null,
        border: Border.all(color: _green, width: 1.5),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(label, style: const TextStyle(color: _green, fontWeight: FontWeight.w700, fontSize: 12.5)),
    ),
  );

  Widget _dialogAction({required double left, required String label, required bool hit}) => Positioned(
    left: left,
    top: 166,
    width: label == 'Hủy' ? 50 : 56,
    height: 36,
    child: Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(color: hit ? _greenSoft : null, borderRadius: BorderRadius.circular(99)),
      child: Text(label, style: const TextStyle(color: _green, fontWeight: FontWeight.w700, fontSize: 13)),
    ),
  );
}

/// Bản đồ minh họa kiểu Google Maps (không phải bản đồ thật), phóng to quanh chỗ chấm công.
class _MapPainter extends CustomPainter {
  _MapPainter(this.zoom);
  final double zoom;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFEDE9E1));
    canvas.save();
    canvas.scale(size.width / 300, size.height / 600);
    canvas.translate(_spot.dx, _spot.dy);
    canvas.scale(zoom);
    canvas.translate(-_spot.dx, -_spot.dy);

    final river = Path()
      ..moveTo(-10, 470)
      ..cubicTo(60, 430, 120, 520, 200, 480)
      ..cubicTo(280, 440, 290, 430, 320, 450)
      ..lineTo(320, 520)
      ..cubicTo(260, 500, 210, 560, 140, 545)
      ..cubicTo(70, 530, 30, 520, -10, 540)
      ..close();
    canvas.drawPath(river, Paint()..color = const Color(0xFFAAD3F2));

    void block(double x, double y, double w, double h, int color, [double r = 4]) => canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r)),
      Paint()..color = Color(color),
    );
    block(18, 120, 92, 70, 0xFFC8E6C0, 6);
    block(128, 120, 70, 44, 0xFFE2DDD3);
    block(212, 120, 76, 70, 0xFFE2DDD3);
    block(18, 226, 56, 92, 0xFFE2DDD3);
    block(90, 226, 56, 60, 0xFFE2DDD3);
    block(146, 298, 48, 40, 0xFFD8D1C4);
    block(212, 226, 76, 52, 0xFFE2DDD3);
    block(212, 296, 76, 70, 0xFFE2DDD3);
    block(18, 352, 120, 60, 0xFFE2DDD3);

    final road = Paint()
      ..color = Colors.white
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(-10, 206), const Offset(310, 206), road);
    canvas.drawPath(
      Path()
        ..moveTo(-10, 340)
        ..lineTo(120, 340)
        ..quadraticBezierTo(140, 340, 150, 350)
        ..lineTo(310, 384),
      road,
    );
    canvas.drawLine(const Offset(120, 100), const Offset(120, 600), road);
    canvas.drawLine(const Offset(204, 100), const Offset(204, 430), road);
    canvas.drawLine(
      const Offset(-10, 206),
      const Offset(310, 206),
      Paint()
        ..color = const Color(0xFFFFD97A)
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round,
    );
    block(164, 333.5, 10, 4.5, 0xFF9E8F76, 1);

    void label(String text, double x, double y, int color, {double size = 9.5, bool bold = false, double angle = 0}) {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(fontSize: size, color: Color(color), fontWeight: bold ? FontWeight.w600 : FontWeight.w400),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      canvas.save();
      canvas.translate(x, y - tp.height * 0.8);
      if (angle != 0) canvas.rotate(angle);
      tp.paint(canvas, Offset.zero);
      canvas.restore();
    }

    label('Công viên', 34, 160, 0xFF3B7D3B);
    label('Quốc lộ 20', 10, 200, 0xFF7A5C00, bold: true);
    label('Xưởng may', 146, 292, 0xFF3C4043, bold: true);
    label('Đường số 3', 128, 372, 0xFF5F6368, angle: 0.21);
    label('Suối', 96, 512, 0xFF4A7FB0);
    label('Cổng', 176, 337, 0xFF5F4B2A, size: 5, bold: true);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MapPainter old) => old.zoom != zoom;
}

class _PinPainter extends CustomPainter {
  const _PinPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 28, size.height / 38);
    final pin = Path()
      ..moveTo(14, 37)
      ..cubicTo(14, 37, 26, 23.8, 26, 14.5)
      ..cubicTo(26, 7, 20.6, 1.5, 14, 1.5)
      ..cubicTo(7.4, 1.5, 2, 7, 2, 14.5)
      ..cubicTo(2, 23.8, 14, 37, 14, 37)
      ..close();
    canvas.drawPath(pin, Paint()..color = const Color(0xFFEA4335));
    canvas.drawPath(
      pin,
      Paint()
        ..color = const Color(0xFFB31412)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    canvas.drawCircle(const Offset(14, 14), 4.6, Paint()..color = const Color(0xFF7F0F0C));
  }

  @override
  bool shouldRepaint(_PinPainter old) => false;
}
