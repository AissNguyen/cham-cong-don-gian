import 'dart:async';
import 'dart:ui';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:provider/provider.dart';

import 'analytics/analytics_service.dart';
import 'data/store.dart';
import 'firebase_options.dart';
import 'gps/gps_scheduler.dart';
import 'notice/help_text.dart';
import 'notice/notice.dart';
import 'share/share_service.dart';
import 'share/share_state_file.dart';
import 'theme/app_theme.dart';
import 'ui/home/home_screen.dart';
import 'update/update_screen.dart';
import 'update/update_service.dart';
import 'widget/widget_sync.dart';

/// Xong khi Firebase đã khởi động (true) hoặc không khởi động được (false). Trên web không chờ cái
/// này trước khi hiện app, để mạng chậm/mất mạng vẫn mở app ngay; các việc cần Firebase chờ nó sau.
late final Future<bool> firebaseReady;

Future<bool> _initFirebase() async {
  // Thống kê chỉ là phụ trợ, không bao giờ được phép làm app không mở lên được — ví dụ trên web,
  // việc tải SDK Firebase qua mạng có thể thất bại (chặn quảng cáo/theo dõi, mất mạng...), nên bọc
  // try/catch, lỗi thì bỏ qua Analytics/Crashlytics, app vẫn chạy bình thường không thống kê.
  try {
    // Có timeout: nếu bị chặn mạng, lệnh này có thể treo mãi không ném lỗi lẫn không trả về —
    // không giới hạn thời gian thì các việc chờ Firebase sẽ không bao giờ chạy.
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform).timeout(const Duration(seconds: 5));
    return true;
  } catch (_) {
    return false;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  firebaseReady = _initFirebase();
  // Trên Android Firebase khởi động gần như tức thì nên chờ luôn (để Crashlytics bắt được lỗi
  // ngay từ đầu); trên web thì không chờ.
  if (!kIsWeb && await firebaseReady) {
    // Crashlytics chỉ có trên Android/iOS, không có trên web.
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }
  // Bản web không có GPS nền/widget màn hình chính (không phải nền tảng Android) nên bỏ qua.
  if (!kIsWeb) {
    await AndroidAlarmManager.initialize();
    HomeWidget.registerInteractivityCallback(widgetInteractiveCallback);
  }
  runApp(const ChamCongApp());
}

class ChamCongApp extends StatefulWidget {
  const ChamCongApp({super.key});

  @override
  State<ChamCongApp> createState() => _ChamCongAppState();
}

class _ChamCongAppState extends State<ChamCongApp> with WidgetsBindingObserver {
  final store = AppStore();
  UpdateStatus _updateStatus = UpdateStatus.none;
  bool _updateBannerDismissed = false;

  StreamSubscription<Uri?>? _widgetClickSub;

  void _checkUpdate() {
    checkForUpdate().then((status) {
      if (mounted) setState(() => _updateStatus = status);
      // Sau khi Remote Config đã tải mới đọc thông báo của chủ app và đồng bộ mã giới thiệu.
      loadNotice();
      loadHelpText();
      shareController.sync();
    });
  }

  /// Chạm nút "Mở khóa" trên widget (lúc đã hết ngày dùng thử) thì mở app và hiện hộp chia sẻ.
  void _onWidgetLaunch(Uri? uri) {
    if (uri?.queryParameters['action'] == 'unlock') shareController.requestLockNotice();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    store.load().then((_) async {
      await firebaseReady;
      logOncePerDay(eventAppOpen);
      processPendingAnalyticsEvents();
      await shareController.load();
      await recordUsage(usageAppOpens);
      _checkUpdate();
      if (!kIsWeb) {
        rescheduleGpsAlarms(store.settings.gps);
        refreshWidgetDisplay();
        HomeWidget.initiallyLaunchedFromHomeWidget().then(_onWidgetLaunch);
        _widgetClickSub = HomeWidget.widgetClicked.listen(_onWidgetLaunch);
      }
    });
  }

  @override
  void dispose() {
    _widgetClickSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // App quay lại foreground: đọc lại file, để thấy các lần chấm mà widget/GPS nền vừa ghi.
    if (state == AppLifecycleState.resumed && store.loaded) {
      store.reloadFromDisk();
      firebaseReady.then((_) {
        logOncePerDay(eventAppOpen);
        processPendingAnalyticsEvents();
        // Đọc lại số ngày dùng thử mà widget/GPS nền vừa ghi.
        shareController.load();
        recordUsage(usageAppOpens);
        _checkUpdate();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: store,
      child: MaterialApp(
        title: 'Chấm Công Đơn Giản',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(Brightness.light),
        darkTheme: buildAppTheme(Brightness.dark),
        // Giới hạn cỡ chữ hệ thống tối đa 1.3x — máy để cỡ chữ lớn nhất vẫn không phá bố cục.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3)),
          child: child!,
        ),
        home: Consumer<AppStore>(
          builder: (context, store, _) {
            if (!store.loaded) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            if (_updateStatus.mandatory) {
              return MandatoryUpdateScreen(status: _updateStatus);
            }
            return HomeScreen(
              updateStatus: !_updateBannerDismissed ? _updateStatus : UpdateStatus.none,
              onDismissUpdateBanner: () => setState(() => _updateBannerDismissed = true),
            );
          },
        ),
      ),
    );
  }
}
