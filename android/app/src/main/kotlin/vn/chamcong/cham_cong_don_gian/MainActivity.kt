package vn.chamcong.cham_cong_don_gian

import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    // Mã thiết bị Android: giữ nguyên khi gỡ ra cài lại, dùng để nhận diện máy cho mã giới thiệu.
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "chamcong/device")
        .setMethodCallHandler { call, result ->
          if (call.method == "androidId") {
            result.success(Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID))
          } else {
            result.notImplemented()
          }
        }
  }
}
