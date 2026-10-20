import '../../onboarding/pay_guide.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:provider/provider.dart';

import '../../data/store.dart';
import 'payslip_card.dart';
import 'settings_blocks.dart';
import 'work_config_card.dart';

/// Màn Cài đặt theo `mockup/luong-va-cai-dat.html`, từ trên xuống: thông báo, Công nhân / Công
/// nhật, phiếu lương, cài đặt tính công, chấm công GPS (ẩn trên web hoặc khi đã tắt), nâng cao.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.scrollToGps = false, this.payGuide = false});

  /// Mở màn rồi tự cuộn tới thẻ "Chấm công GPS" (cuối chuyến hướng dẫn làm thử).
  final bool scrollToGps;

  /// Mở màn kèm hướng dẫn tính lương (`lib/onboarding/pay_guide.dart`): phiếu lương và cài đặt tính
  /// công mở sẵn chế độ sửa.
  final bool payGuide;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _gpsKey = GlobalKey();
  final _payKeys = PayGuideKeys();
  final _scrollTick = ValueNotifier(0);
  late bool _guiding = widget.payGuide;

  @override
  void dispose() {
    _scrollTick.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.scrollToGps) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _gpsKey.currentContext;
        if (mounted && ctx != null) {
          Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt')),
      body: Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: (_) {
              _scrollTick.value++;
              return false;
            },
            child: ListView(
              // Cần dựng sẵn thẻ GPS (nằm khá xa phía dưới), các chỗ sáng của hướng dẫn lương thì mới
              // cuộn tới được.
              scrollCacheExtent: widget.scrollToGps || widget.payGuide ? const ScrollCacheExtent.pixels(6000) : null,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
              children: [
                const SettingsNoticeCard(),
                WorkerKindToggle(store: store),
                PayslipCard(store: store, startEditing: widget.payGuide, guideKeys: widget.payGuide ? _payKeys : null),
                WorkConfigCard(
                  store: store,
                  startEditing: widget.payGuide,
                  wageKey: widget.payGuide ? _payKeys.wage : null,
                ),
                if (!kIsWeb && store.settings.showGps) GpsQuickCard(key: _gpsKey, store: store, tourHint: widget.scrollToGps),
                MoreSettingsCard(store: store),
              ],
            ),
          ),
          if (_guiding)
            Positioned.fill(
              child: PayGuideOverlay(
                keys: _payKeys,
                kind: store.settings.workerKind,
                scrollTick: _scrollTick,
                onClose: () {
                  setState(() => _guiding = false);
                  Navigator.of(context).maybePop();
                },
              ),
            ),
        ],
      ),
    );
  }
}
