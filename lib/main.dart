import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:provider/provider.dart';

import 'data/store.dart';
import 'gps/gps_scheduler.dart';
import 'theme/app_theme.dart';
import 'ui/home/home_screen.dart';
import 'widget/widget_sync.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Bản web không có báo thức nền / widget màn hình chính.
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    store.load().then((_) {
      rescheduleGpsAlarms(store.settings.gps);
      refreshWidgetDisplay();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // App quay lại foreground: đọc lại file, để thấy các lần chấm mà widget/GPS nền vừa ghi.
    if (state == AppLifecycleState.resumed && store.loaded) {
      store.reloadFromDisk();
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
            return const HomeScreen();
          },
        ),
      ),
    );
  }
}
