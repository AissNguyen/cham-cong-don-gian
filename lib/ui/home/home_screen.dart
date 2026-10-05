import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../analytics/analytics_service.dart';
import '../../data/store.dart';
import '../../domain/calc.dart';
import '../../domain/models.dart';
import '../../domain/pay_period.dart';
import '../../domain/share_gate.dart';
import '../../notice/notice.dart';
import '../../share/share_service.dart';
import '../../theme/app_theme.dart';
import '../format.dart';
import '../../update/update_screen.dart';
import '../../update/update_service.dart';
import '../settings/settings_screen.dart';
import '../settings/share_section.dart';
import 'calendar_grid.dart';
import 'edit_dialogs.dart';
import 'notes_summary.dart';
import 'period_day_chart.dart';
import 'period_history.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.updateStatus = UpdateStatus.none, this.onDismissUpdateBanner});

  final UpdateStatus updateStatus;
  final VoidCallback? onDismissUpdateBanner;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late DateTime _viewedMonth;
  late DateTime _selectedDate;
  bool _showLunar = false;
  bool _showMoneyPerDay = false;
  bool _showCheckTimes = false;
  final _scrollController = ScrollController();

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
    _onShareChanged();
  }

  @override
  void dispose() {
    shareController.removeListener(_onShareChanged);
    _scrollController.dispose();
    _tickTimer?.cancel();
    super.dispose();
  }

  bool _shareDialogOpen = false;

  /// Hỏi "Ai giới thiệu bạn?" 1 lần cho máy mới cài; báo 1 lần khi hết ngày dùng thử chấm công tự
  /// động (và mỗi lần người dùng chạm nút "Mở khóa" trên widget).
  void _onShareChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _shareDialogOpen) return;
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
    });
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
    final today = dateOnly(DateTime.now());
    final period = periodContaining(today, store.settings.payPeriod);
    final recordsInPeriod = store.records.values.where((r) => period.contains(r.date));
    final stats = computePeriodStats(period, recordsInPeriod, store.settings);
    final incomeOverridden = store.periodOverrides.containsKey(period.key);
    final totalIncome = store.periodOverrides[period.key] ?? stats.totalIncome;
    final selectedRecord = store.recordFor(_selectedDate);

    final todayRecord = store.recordFor(today);
    final now = DateTime.now();
    final todayPay =
        liveEstimatedPay(todayRecord, store.settings, now) +
        liveItemsEstimate(todayRecord, store.settings, now, stats.workDayCount);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          controller: _scrollController,
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
            if (widget.updateStatus.hasUpdate) ...[
              const SizedBox(height: 10),
              UpdateBanner(status: widget.updateStatus, onDismiss: () => widget.onDismissUpdateBanner?.call()),
            ],
            const NoticeBanner(),
            const SizedBox(height: 12),
            _buildIncomeCard(context, period, stats, totalIncome, incomeOverridden, todayPay),
            const SizedBox(height: 16),
            CalendarGrid(
              month: _viewedMonth,
              selectedDate: _selectedDate,
              store: store,
              showLunar: _showLunar,
              showMoneyPerDay: _showMoneyPerDay,
              showCheckTimes: _showCheckTimes,
              onSelect: (d) => setState(() => _selectedDate = d),
            ),
            const SizedBox(height: 16),
            _buildActionButtons(context, store, selectedRecord),
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
          onPressed: () {
            logOncePerDay(eventOpenedSettings);
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
          },
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
        _headerIcon(
          icon: Icons.brightness_2_outlined,
          tooltip: 'Âm lịch',
          color: _showLunar ? primary : null,
          onPressed: () => setState(() => _showLunar = !_showLunar),
        ),
        _headerIcon(
          icon: Icons.access_time_outlined,
          tooltip: 'Giờ vào/ra',
          color: _showCheckTimes ? primary : null,
          onPressed: () => setState(() => _showCheckTimes = !_showCheckTimes),
        ),
        _headerIcon(
          icon: Icons.payments_outlined,
          tooltip: 'Lương mỗi ngày',
          color: _showMoneyPerDay ? primary : null,
          onPressed: () => setState(() => _showMoneyPerDay = !_showMoneyPerDay),
        ),
      ],
    );
  }

  Widget _buildIncomeCard(
    BuildContext context,
    PayPeriod period,
    PeriodStats stats,
    double totalIncome,
    bool isOverridden,
    double todayPay,
  ) {
    final colors = context.appColors;
    final showIntro = _showTodayIntro;
    const animDuration = Duration(milliseconds: 500);
    const bigSize = 27.0;
    const smallSize = 15.0;

    return Container(
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Thu nhập tạm tính · kỳ ${fmtDM(period.start)}–${fmtDM(period.end)}',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isOverridden)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(6)),
                            child: const Text('đã sửa tay', style: TextStyle(color: Colors.white, fontSize: 10)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    AnimatedDefaultTextStyle(
                      duration: animDuration,
                      curve: Curves.easeInOut,
                      style: TextStyle(
                        fontSize: showIntro ? smallSize : bigSize,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                      child: Text(fmtMoney(totalIncome), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
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
                    child: Text(fmtMoney(todayPay), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _statTile(context, 'Giờ công', fmtHours(stats.normalMinutes)),
              _statTile(context, 'Tăng ca', fmtHours(stats.overtimeMinutes)),
              _statTile(context, 'Tổng giờ', fmtHours(stats.normalMinutes + stats.overtimeMinutes)),
              _statTile(context, 'Ngày nghỉ', '${stats.daysOff}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statTile(BuildContext context, String label, String value) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: Colors.white), maxLines: 1),
          Text(label, style: const TextStyle(fontSize: 11.5, color: Colors.white70), maxLines: 1),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, AppStore store, DayRecord record) {
    final result = computeDay(record, store.settings);
    final errorColor = Theme.of(context).colorScheme.error;

    Future<void> punchNow(bool isCheckIn) async {
      final now = DateTime.now();
      final time = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, now.hour, now.minute);
      if (isCheckIn) {
        await store.punchIn(_selectedDate, time);
      } else {
        await store.punchOut(_selectedDate, time);
      }
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: Icons.login,
                label: record.checkIn != null ? fmtTime(record.checkIn!) : 'Chấm vào',
                active: record.checkIn != null,
                activeColor: Colors.blue,
                onTap: () => punchNow(true),
                onLongPress: () => showPunchEditSheet(context, store: store, date: _selectedDate, isCheckIn: true),
              ),
            ),
            Expanded(
              child: _ActionButton(
                icon: Icons.logout,
                label: record.checkOut != null ? fmtTime(record.checkOut!) : 'Chấm ra',
                active: record.checkOut != null,
                activeColor: Colors.blue,
                onTap: () => punchNow(false),
                onLongPress: () => showPunchEditSheet(context, store: store, date: _selectedDate, isCheckIn: false),
              ),
            ),
            Expanded(
              child: _ActionButton(
                icon: Icons.beach_access_outlined,
                label: 'Ngày nghỉ',
                active: record.isDayOff,
                activeColor: context.appColors.dayOffMark,
                onTap: () => store.setDayOff(_selectedDate, !record.isDayOff),
              ),
            ),
            Expanded(
              child: _ActionButton(
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
          'Chạm để chấm giờ hiện tại · giữ để tự sửa giờ',
          style: TextStyle(fontSize: 11, color: context.appColors.ink3),
        ),
        if (result.breakRuleWarning)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: errorColor.withValues(alpha: 0.1),
              border: Border.all(color: errorColor),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, color: errorColor, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Giờ vào/ra không khớp khung cộng-trừ giờ nào đã cài — đang tạm tính không kể giờ '
                    'nghỉ ${unmatchedBreakFrom.formatted}–${unmatchedBreakTo.formatted} '
                    '(trừ ${result.breakRuleDeltaMinutes.abs()} phút). Hãy chấm lại cho đúng giờ.',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: errorColor),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
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
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: Icon(hasNote ? Icons.edit_note : Icons.note_add_outlined),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        onPressed: () => showNoteSheet(context, store: store, date: _selectedDate),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
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
