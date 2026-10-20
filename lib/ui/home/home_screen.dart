import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:provider/provider.dart';

import '../../analytics/analytics_service.dart';
import '../../data/store.dart';
import '../../domain/calc.dart';
import '../../domain/leave.dart';
import '../../domain/models.dart';
import '../../domain/pay_period.dart';
import '../../domain/payslip.dart';
import '../../domain/share_gate.dart';
import '../../notice/notice.dart';
import '../../onboarding/intro_dialog.dart';
import '../../onboarding/tour_controller.dart';
import '../../onboarding/tour_overlay.dart';
import '../../share/share_service.dart';
import '../../theme/app_theme.dart';
import '../format.dart';
import '../settings/settings_screen.dart';
import '../settings/share_section.dart';
import 'calendar_grid.dart';
import 'edit_dialogs.dart';
import 'notes_summary.dart';
import '../../onboarding/pay_guide.dart';
import '../../onboarding/setup_dialog.dart';
import 'overtime_offset_sheet.dart';
import 'period_day_chart.dart';
import 'period_history.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.clock, this.showOnboarding = false});

  /// Chỉ dùng trong test để cố định "bây giờ"; bình thường là giờ hiện tại.
  final DateTime Function()? clock;

  /// Cho phép tự hiện khung giới thiệu lần đầu mở app. Mặc định tắt để test không bị hộp thoại chặn;
  /// `main.dart` truyền true.
  final bool showOnboarding;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late DateTime _viewedMonth;
  late DateTime _selectedDate;
  bool _showLunar = false;
  final _scrollController = ScrollController();

  // Các chỗ sáng của chuyến hướng dẫn (xem `onboarding/tour_overlay.dart`).
  final _checkInKey = GlobalKey();
  final _checkOutKey = GlobalKey();
  final _dayOffKey = GlobalKey();
  final _lateKey = GlobalKey();
  final _noteKey = GlobalKey();
  final _calendarKey = GlobalKey();
  final _statsKey = GlobalKey();
  final _topButtonsKey = GlobalKey();
  final _practiceDayKey = GlobalKey();

  /// Trong 5 giây đầu mở app, số to hiện thu nhập hôm nay (tăng dần theo giây); sau đó chuyển lại
  /// hiện tổng thu nhập của kỳ như bình thường, thu nhập hôm nay thu nhỏ thành 1 ô thống kê.
  bool _showTodayIntro = true;
  Timer? _tickTimer;

  @override
  void initState() {
    super.initState();
    final today = dateOnly(DateTime.now());
    _viewedMonth = DateTime(today.year, today.month);
    _selectedDate = today;
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showTodayIntro = false);
    });
    shareController.addListener(_onShareChanged);
    tourController.addListener(_onTourChanged);
    _onShareChanged();
    if (widget.showOnboarding) WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowIntro());
  }

  @override
  void dispose() {
    shareController.removeListener(_onShareChanged);
    tourController.removeListener(_onTourChanged);
    _scrollController.dispose();
    _tickTimer?.cancel();
    super.dispose();
  }

  bool _shareDialogOpen = false;

  /// Hỏi "Ai giới thiệu bạn?" 1 lần cho máy mới cài; báo 1 lần khi hết ngày dùng thử chấm công tự
  /// động (và mỗi lần người dùng chạm nút "Mở khóa" trên widget).
  void _onShareChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Đang hiện khung giới thiệu hoặc chạy chuyến hướng dẫn thì chờ xong mới hỏi (gọi lại sau).
      if (!mounted || _shareDialogOpen || _introOpen || tourController.active) return;
      final s = shareController.state;
      final askReferral = shouldPromptReferral(s, DateTime.now());
      final tellLocked = !shareController.allowed && (!s.lockNoticeShown || shareController.lockNoticeRequested);
      if (!askReferral && !tellLocked) return;
      _shareDialogOpen = true;
      if (askReferral) {
        await showReferralPrompt(context);
      } else {
        await showLockNotice(context);
      }
      _shareDialogOpen = false;
      _maybeShowIntro();
    });
  }

  bool _introOpen = false;

  /// Khung giới thiệu lần đầu: chỉ khi máy chưa từng thấy và chưa có ngày chấm công nào; chờ hộp
  /// "Ai giới thiệu bạn?" (nếu có) xong trước. Bấm "Bắt đầu" thì vào chuyến hướng dẫn.
  Future<void> _maybeShowIntro() async {
    if (!widget.showOnboarding || _introOpen || _shareDialogOpen || tourController.active) return;
    _introOpen = true; // giữ chỗ ngay, kẻo hai lần gọi chồng nhau cùng hiện hộp
    var start = false;
    try {
      final store = context.read<AppStore>();
      // App bị tắt giữa chuyến lần trước thì trả dữ liệu tập về trước đã.
      await tourController.restoreIfInterrupted(store);
      if (!mounted || _shareDialogOpen || shouldPromptReferral(shareController.state, DateTime.now())) return;
      if (!await tourController.shouldAutoStart(store) || !mounted) return;
      await tourController.markSeen();
      if (!mounted) return;
      start = await showIntroDialog(context);
    } finally {
      _introOpen = false;
    }
    if (!mounted) return;
    if (start) {
      await showSetupDialog(context, context.read<AppStore>());
      if (!mounted) return;
      await _startTour();
    } else {
      _onShareChanged();
    }
  }

  DateTime get _today => dateOnly(widget.clock?.call() ?? DateTime.now());

  /// Bắt đầu chuyến hướng dẫn: về hôm nay, đúng tháng này, đầu trang; chụp và xóa trắng hai ngày tập.
  Future<void> _startTour({bool replay = false}) async {
    final store = context.read<AppStore>();
    final today = _today;
    setState(() {
      _selectedDate = today;
      _viewedMonth = DateTime(today.year, today.month);
    });
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    await tourController.start(store, today: today, replay: replay);
  }

  /// Kết thúc chuyến: trả hai ngày tập về như cũ; [goSettings] thì mở Cài đặt, cuộn tới thẻ GPS.
  Future<void> _endTour({bool goSettings = false}) async {
    await tourController.end(context.read<AppStore>());
    if (goSettings && mounted) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen(scrollToGps: true)));
    }
  }

  void _onTourChanged() {
    if (!mounted) return;
    if (tourController.replayRequested && !tourController.active) {
      _startTour(replay: true);
      return;
    }
    setState(() {});
    if (!tourController.active) _onShareChanged();
  }

  void _openSettings() {
    logOncePerDay(eventOpenedSettings);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
  }

  void _changeMonth(int delta) {
    setState(() => _viewedMonth = DateTime(_viewedMonth.year, _viewedMonth.month + delta));
  }

  void _jumpToDateFromNote(DateTime d) {
    setState(() {
      _selectedDate = d;
      _viewedMonth = DateTime(d.year, d.month);
    });
    _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final now = widget.clock?.call() ?? DateTime.now();
    final today = dateOnly(now);
    final period = periodContaining(today, store.settings.payPeriod);
    // Mọi con số tiền trên màn chính lấy từ phiếu lương (cùng bộ tính với Cài đặt › Phiếu lương).
    final slip = computePayslip(settings: store.settings, period: period, recordOf: store.recordFor, now: now);
    final slips = <String, Payslip>{period.key: slip};
    Payslip slipOf(DateTime date) {
      final p = periodContaining(date, store.settings.payPeriod);
      return slips[p.key] ??= computePayslip(settings: store.settings, period: p, recordOf: store.recordFor, now: now);
    }

    double moneyOf(DateTime date) => slipOf(date).amountOn(date);
    final offsetOn = store.settings.usesOvertimeOffset;
    final isWorker = store.settings.workerKind == WorkerKind.worker;

    final selectedRecord = store.recordFor(_selectedDate);
    final todayPay = slip.amountOn(today);

    final touring = tourController.active;
    if (touring) {
      // Sau khi dựng xong, tự chuyển bước theo thao tác vừa làm (và chọn lại hôm nay nếu cần).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final select = tourController.update(store, _selectedDate);
        if (select != null && select != _selectedDate) setState(() => _selectedDate = select);
      });
    }

    final list = SafeArea(
        child: ListView(
          controller: _scrollController,
          // Đang chạy chuyến thì dựng sẵn cả trang để mọi chỗ sáng đều đo được.
          scrollCacheExtent: touring ? const ScrollCacheExtent.pixels(5000) : null,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: context.appColors.accentSoft.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: _buildHeader(context, store),
            ),
            const NoticeBanner(),
            const SizedBox(height: 12),
            _buildIncomeCard(context, period, slip, todayPay),
            if (!kIsWeb &&
                !touring &&
                store.settings.showGps &&
                store.settings.gps.latitude == null &&
                !store.settings.gpsReminderOff)
              _gpsReminder(context, store),
            const SizedBox(height: 16),
            CalendarGrid(
              key: _calendarKey,
              keyFor: (d) => d == tourController.practiceDate ? _practiceDayKey : null,
              month: _viewedMonth,
              selectedDate: _selectedDate,
              store: store,
              showLunar: _showLunar,
              moneyOf: moneyOf,
              offsetOf: offsetOn ? (d) => slipOf(d).offsetOn(d) : null,
              onLeaveOf: isWorker ? (d) => slipOf(d).leaveDates.contains(dateOnly(d)) : null,
              onSelect: (d) => setState(() => _selectedDate = d),
            ),
            const SizedBox(height: 16),
            _buildActionButtons(context, store, selectedRecord, slipOf(_selectedDate)),
            const SizedBox(height: 10),
            _buildNoteButton(context, store, selectedRecord),
            const SizedBox(height: 24),
            _CollapsibleSection(
              title: 'Ghi chú đã ghi',
              child: NotesSummary(store: store, onSelectDate: _jumpToDateFromNote),
            ),
            const SizedBox(height: 12),
            _CollapsibleSection(
              title: 'Thống kê thu nhập theo kỳ',
              onExpand: () => logOncePerDay(eventViewedPeriodStats),
              child: PeriodHistorySection(store: store),
            ),
            const SizedBox(height: 12),
            PeriodDayChartSection(store: store),
          ],
        ),
      );
    return Scaffold(
      body: Stack(
        children: [
          list,
          if (touring)
            Positioned.fill(
              child: TourOverlay(
                controller: tourController,
                targets: {
                  TourStep.checkIn: _checkInKey,
                  TourStep.checkOut: _checkOutKey,
                  TourStep.pickDayOff: _practiceDayKey,
                  TourStep.chooseDayOff: _dayOffKey,
                  TourStep.lateButton: _lateKey,
                  TourStep.note: _noteKey,
                  TourStep.calendar: _calendarKey,
                  TourStep.stats: _statsKey,
                  TourStep.topButtons: _topButtonsKey,
                },
                onSkip: _endTour,
                onFinish: () => _endTour(goSettings: true),
              ),
            ),
        ],
      ),
    );
  }

  static const _headerIconConstraints = BoxConstraints(minWidth: 34, minHeight: 34);

  Widget _headerIcon({required IconData icon, required VoidCallback onPressed, Color? color, String? tooltip}) {
    return IconButton(
      icon: Icon(icon, size: 20, color: color),
      tooltip: tooltip,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: _headerIconConstraints,
    );
  }

  Widget _buildHeader(BuildContext context, AppStore store) {
    final isCurrentMonth = _viewedMonth.year == DateTime.now().year && _viewedMonth.month == DateTime.now().month;
    final primary = Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        _headerIcon(
          icon: Icons.settings_outlined,
          onPressed: _openSettings,
        ),
        _headerIcon(icon: Icons.chevron_left, onPressed: () => _changeMonth(-1)),
        Expanded(
          child: Center(
            child: Text(
              // Dạng số gọn (vd "07/26") thay vì chữ đầy đủ — hàng nút đã chật do thêm nút giờ
              // vào/ra, chữ dài dễ bị cắt.
              '${_viewedMonth.month.toString().padLeft(2, '0')}/${(_viewedMonth.year % 100).toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        _headerIcon(icon: Icons.chevron_right, onPressed: () => _changeMonth(1)),
        if (!isCurrentMonth)
          _headerIcon(
            icon: Icons.today_outlined,
            tooltip: 'Về tháng hiện tại',
            onPressed: () {
              final now = DateTime.now();
              setState(() => _viewedMonth = DateTime(now.year, now.month));
            },
          ),
        // Lịch luôn hiện giờ vào/ra và tiền của ngày, nên chỉ còn nút Âm lịch.
        KeyedSubtree(
          key: _topButtonsKey,
          child: _headerIcon(
            icon: Icons.brightness_2_outlined,
            tooltip: 'Âm lịch',
            color: _showLunar ? primary : null,
            onPressed: () => setState(() => _showLunar = !_showLunar),
          ),
        ),
      ],
    );
  }

  /// Thẻ thu nhập: số to là Thực nhận của kỳ hiện tại lấy từ phiếu lương; bấm vào thì mở Cài đặt
  /// (phiếu lương nằm trên cùng).
  Widget _buildIncomeCard(BuildContext context, PayPeriod period, Payslip slip, double todayPay) {
    final colors = context.appColors;
    final hasPay = context.read<AppStore>().settings.hasPayConfigured;
    final showIntro = _showTodayIntro;
    const animDuration = Duration(milliseconds: 500);
    const bigSize = 27.0;
    const smallSize = 15.0;

    final card = Container(
      key: _statsKey,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors.primaryGradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: colors.gradientEnd.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bên trái: thu nhập kỳ, to lúc bình thường, thu nhỏ trong 3s đầu.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Thực nhận tạm tính · kỳ ${fmtDM(period.start)}–${fmtDM(period.end)}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    if (!hasPay)
                      _payGuideButton(context)
                    else
                      AnimatedDefaultTextStyle(
                        duration: animDuration,
                        curve: Curves.easeInOut,
                        style: TextStyle(
                          fontSize: showIntro ? smallSize : bigSize,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                        child: Text(
                          fmtMoney(slip.net),
                          key: const ValueKey('home-net'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              if (hasPay) ...[
              const SizedBox(width: 10),
              // Bên phải: thu nhập hôm nay, to nổi bật trong 3s đầu, sau đó thu nhỏ về góc
              // này — nhưng số vẫn tiếp tục chạy tăng dần mỗi giây nếu ca đang mở.
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Hôm nay', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 2),
                  AnimatedDefaultTextStyle(
                    duration: animDuration,
                    curve: Curves.easeInOut,
                    style: TextStyle(
                      fontSize: showIntro ? bigSize : smallSize,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                    child: Text(
                      fmtMoney(todayPay),
                      key: const ValueKey('home-today'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Công nhân xem ngày công; công nhật không có ngày công nên xem giờ công.
              if (slip.kind == WorkerKind.worker) ...[
                _statTile(context, 'Ngày công', fmtN(slip.workDays)),
                _statTile(context, 'Tăng ca', fmtHours(slip.overtimeMinutes)),
              ] else
                _statTile(context, 'Giờ công', fmtHours(slip.normalMinutes)),
              // Công nhân: thay "Tổng giờ" bằng số giờ tăng ca bị trừ để bù (tắt bù thì là 0); bấm vào thì
              // xem chi tiết (không mở Cài đặt như phần còn lại của thẻ).
              if (slip.kind == WorkerKind.worker)
                _statTile(
                  context,
                  'Trừ tăng ca',
                  fmtHours(slip.offsetTakenSeconds ~/ 60),
                  key: const ValueKey('home-offset'),
                  onTap: () => showOvertimeOffsetSheet(context, slip),
                )
              else
                _statTile(context, 'Tăng ca', fmtHours(slip.overtimeMinutes)),
              _statTile(context, 'Ngày nghỉ', '${slip.daysOff}'),
            ],
          ),
        ],
      ),
    );
    return GestureDetector(onTap: _openSettings, child: card);
  }

  /// Chưa có tọa độ chỗ làm: nhắc cài chấm công tự động (lúc đầu bấm "Để sau" vì chưa ở chỗ làm).
  Widget _gpsReminder(BuildContext context, AppStore store) => Padding(
    key: const ValueKey('home-gps-reminder'),
    padding: const EdgeInsets.only(top: 10),
    child: Material(
      color: context.appColors.accentSoft,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SettingsScreen(scrollToGps: true)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
          child: Row(
            children: [
              Icon(Icons.location_off_outlined, size: 18, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              const Expanded(child: Text('Chưa cài chấm công tự động', style: TextStyle(fontSize: 13))),
              Text(
                'Cài ngay',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.primary),
              ),
              IconButton(
                key: const ValueKey('home-gps-reminder-off'),
                icon: const Icon(Icons.close, size: 18),
                tooltip: 'Không dùng chấm công tự động',
                visualDensity: VisualDensity.compact,
                onPressed: () => store.updateSettings((s) => s.copyWith(gpsReminderOff: true)),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  /// Chưa cài lương: nút mở hướng dẫn tính lương, kèm chữ nhỏ nói đây là chức năng phụ.
  Widget _payGuideButton(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 4),
      // Loại người dùng, kỳ lương đã hỏi lúc mới vào app nên vào thẳng phần nhập phiếu lương.
      PayGuideCta(onPressed: () => runPayGuide(context, context.read<AppStore>())),
      const SizedBox(height: 2),
      const Text(
        'Đây là chức năng ước tính lương, nếu bạn không cần thì bỏ qua nhé.',
        style: TextStyle(color: Colors.white70, fontSize: 11),
      ),
    ],
  );

  Widget _statTile(BuildContext context, String label, String value, {Key? key, VoidCallback? onTap}) {
    final column = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: Colors.white), maxLines: 1),
        // Ô bấm được thì gạch chân nhãn; nhãn dài thì tự thu nhỏ cho vừa ô.
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              color: Colors.white70,
              decoration: onTap != null ? TextDecoration.underline : null,
              decorationColor: Colors.white70,
            ),
            maxLines: 1,
          ),
        ),
      ],
    );
    return Expanded(
      key: key,
      child: onTap == null ? column : GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: column),
    );
  }

  Widget _buildActionButtons(BuildContext context, AppStore store, DayRecord record, Payslip slip) {
    // Công nhân: ngày nghỉ luôn là Tự nghỉ (trừ phép trước) hoặc Công ty cho nghỉ.
    final worker = store.settings.workerKind == WorkerKind.worker;
    final onLeave = worker && slip.leaveDates.contains(dateOnly(_selectedDate));
    final paidLook = record.paidLeave || onLeave;
    final String dayOffLabel;
    if (!record.isDayOff) {
      dayOffLabel = 'Ngày nghỉ';
    } else if (!worker || record.paidLeave) {
      dayOffLabel = record.paidLeave ? 'Có lương' : 'Không lương';
    } else {
      dayOffLabel = record.companyOff ? 'Cty nghỉ' : (onLeave ? 'Nghỉ phép' : 'Tự nghỉ');
    }
    // Giữ nút Vào/Ra: chưa có giờ vào thì chấm vào, có rồi thì chấm ra bằng giờ hiện tại.
    Future<void> punchNow() async {
      final now = DateTime.now();
      final time = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, now.hour, now.minute);
      if (record.checkIn == null) {
        await store.punchIn(_selectedDate, time);
      } else {
        await store.punchOut(_selectedDate, time);
      }
    }

    final String punchLabel;
    if (record.checkIn == null) {
      punchLabel = record.hasManualHours ? 'Giờ sửa tay' : 'Vào/Ra';
    } else {
      punchLabel = '${fmtTime(record.checkIn!)}–${record.checkOut != null ? fmtTime(record.checkOut!) : '…'}';
    }

    return Column(
      children: [
        Row(
          children: [
            // Một nút cho cả giờ vào và giờ ra; hai bước "chấm vào", "chấm ra" của chuyến hướng dẫn cùng
            // khoét sáng nút này.
            Expanded(
              child: KeyedSubtree(
                key: _checkOutKey,
                child: _ActionButton(
                  key: _checkInKey,
                  icon: record.checkIn != null && record.checkOut == null ? Icons.logout : Icons.login,
                  label: punchLabel,
                  active: record.checkIn != null || record.hasManualHours,
                  activeColor: Colors.blue,
                  onTap: () => showPunchDialog(context, store: store, date: _selectedDate),
                  onLongPress: punchNow,
                ),
              ),
            ),
            Expanded(
              child: _ActionButton(
                key: _dayOffKey,
                icon: Icons.beach_access_outlined,
                label: dayOffLabel,
                active: record.isDayOff,
                // Cùng quy ước với lịch: có lương (nghỉ phép) đậm, không lương nhạt.
                activeColor: paidLook
                    ? context.appColors.dayOffMark
                    : Color.lerp(context.appColors.dayOffMark, Colors.white, 0.45)!,
                onTap: () => worker ? _chooseDayOffOffset(store, record) : _chooseDayOff(store, record),
              ),
            ),
            Expanded(
              child: _ActionButton(
                key: _lateKey,
                icon: Icons.watch_later_outlined,
                label: 'Đi muộn',
                active: record.isLate,
                activeColor: context.appColors.lateMark,
                onTap: record.isDayOff ? null : () => store.setLate(_selectedDate, !record.isLate),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Chạm để chọn giờ · giữ để chấm giờ hiện tại',
          style: TextStyle(fontSize: 11, color: context.appColors.ink3),
        ),
        if (isMissedCheckOut(record, DateTime.now())) _missedCheckOutNote(context, record),
      ],
    );
  }

  /// Dòng lưu ý đỏ khi ngày đang chọn đã chấm vào mà không có giờ về.
  Widget _missedCheckOutNote(BuildContext context, DayRecord record) {
    final red = context.appColors.lateMark;
    final past = dateOnly(record.date).isBefore(dateOnly(DateTime.now()));
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: red.withValues(alpha: 0.1),
        border: Border.all(color: red),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: red, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              record.gpsLeftUnknown && !past
                  ? 'GPS không xác định được bạn còn ở chỗ làm hay đã về (không có sóng GPS, không thấy Wi-Fi '
                        'quen). Nếu bạn đã về, hãy bấm nút Chấm ra để nhập giờ về.'
                  : past
                  ? 'Ngày này đã chấm vào lúc ${fmtTime(record.checkIn!)} nhưng chưa có giờ về nên chưa được tính công. '
                        'Hãy bấm nút Chấm ra để nhập giờ về.'
                  : 'Đã qua $missedCheckOutHour:00 mà chưa chấm được giờ về. Hãy bấm nút Chấm ra để nhập giờ về, nếu không sang '
                        'ngày mai ngày này sẽ không được tính công.',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: red),
            ),
          ),
        ],
      ),
    );
  }

  /// Bấm "Ngày nghỉ": chọn nghỉ có lương (tính một ngày lương cơ bản) hay không lương.
  Future<void> _chooseDayOff(AppStore store, DayRecord record) async {
    final date = _selectedDate;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.payments_outlined),
              title: const Text('Nghỉ có lương'),
              subtitle: const Text('Tính một ngày lương cơ bản'),
              trailing: record.isDayOff && record.paidLeave ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(context, 'paid'),
            ),
            ListTile(
              leading: const Icon(Icons.money_off),
              title: const Text('Nghỉ không lương'),
              subtitle: const Text('Không tính tiền ngày này'),
              trailing: record.isDayOff && !record.paidLeave ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(context, 'unpaid'),
            ),
            if (record.isDayOff)
              ListTile(
                leading: const Icon(Icons.undo),
                title: const Text('Bỏ đánh dấu nghỉ'),
                onTap: () => Navigator.pop(context, 'clear'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    switch (choice) {
      case 'paid':
        await store.setDayOff(date, true, paid: true);
      case 'unpaid':
        await store.setDayOff(date, true);
      case 'clear':
        await store.setDayOff(date, false);
    }
  }

  /// Bấm "Ngày nghỉ" (công nhân): tự nghỉ (trừ phép trước, hết phép là không lương) hay công ty cho
  /// nghỉ (không trừ phép; bật bù tăng ca thì lấy tăng ca bù).
  Future<void> _chooseDayOffOffset(AppStore store, DayRecord record) async {
    final date = _selectedDate;
    final balance = leaveBalanceFor(store.settings, store.recordFor, date);
    final self = isSelfDayOff(record);
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const ValueKey('dayoff-self'),
              leading: const Icon(Icons.person_off_outlined),
              title: const Text('Tự nghỉ'),
              subtitle: Text(
                balance >= 1
                    ? 'Bạn còn ${fmtN(balance)} ngày phép · ngày này trừ 1 ngày phép'
                    : 'Bạn đã hết ngày phép · ngày này nghỉ không lương',
              ),
              trailing: self ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(context, 'self'),
            ),
            ListTile(
              key: const ValueKey('dayoff-company'),
              leading: const Icon(Icons.apartment_outlined),
              title: const Text('Công ty cho nghỉ'),
              subtitle: Text(
                store.settings.usesOvertimeOffset
                    ? 'Không trừ phép, lấy tăng ca bù vào'
                    : 'Không trừ phép, nghỉ không lương',
              ),
              trailing: record.isDayOff && record.companyOff ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(context, 'company'),
            ),
            if (record.isDayOff)
              ListTile(
                leading: const Icon(Icons.undo),
                title: const Text('Bỏ đánh dấu nghỉ'),
                onTap: () => Navigator.pop(context, 'clear'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    switch (choice) {
      case 'self':
        await store.setDayOff(date, true);
      case 'company':
        await store.setDayOff(date, true, company: true);
      case 'clear':
        await store.setDayOff(date, false);
    }
  }

  Widget _buildNoteButton(BuildContext context, AppStore store, DayRecord record) {
    final hasContent = record.note != null && record.note!.isNotEmpty;
    final hasNote = hasContent || record.tags.isNotEmpty;
    String label;
    if (hasContent) {
      label = record.note!;
    } else if (record.tags.isNotEmpty) {
      label = record.tags.join(', ');
    } else {
      label = 'Ghi chú';
    }
    final note = SizedBox(
      key: _noteKey,
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: Icon(hasNote ? Icons.edit_note : Icons.note_add_outlined),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        onPressed: () => showNoteSheet(context, store: store, date: _selectedDate),
      ),
    );
    return note;
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.active,
    required this.activeColor,
    required this.onTap,
    this.onLongPress,
  });

  final IconData icon;
  final String label;
  final bool active;
  final Color activeColor;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Opacity(
      opacity: disabled ? 0.4 : 1,
      child: InkWell(
        onTap: onTap,
        onLongPress: disabled ? null : onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: active
                      ? LinearGradient(colors: [activeColor, Color.lerp(activeColor, Colors.black, 0.25)!], begin: Alignment.topLeft, end: Alignment.bottomRight)
                      : null,
                  color: active ? null : context.appColors.accentSoft,
                  boxShadow: active ? [BoxShadow(color: activeColor.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 4))] : null,
                ),
                child: Icon(icon, color: active ? Colors.white : Theme.of(context).colorScheme.primary, size: 21),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10.5),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Khung gấp lại được, tránh chiếm chỗ khi không cần xem (thống kê theo kỳ, ghi chú...).
class _CollapsibleSection extends StatefulWidget {
  const _CollapsibleSection({required this.title, required this.child, this.onExpand});

  final String title;
  final Widget child;
  final VoidCallback? onExpand;

  @override
  State<_CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<_CollapsibleSection> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: colors.line.withValues(alpha: 0.6), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              setState(() => expanded = !expanded);
              if (expanded) widget.onExpand?.call();
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(child: Text(widget.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more, color: colors.ink2),
                ],
              ),
            ),
          ),
          if (expanded) Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 14), child: widget.child),
        ],
      ),
    );
  }
}
