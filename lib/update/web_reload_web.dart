import 'package:web/web.dart' as web;

/// Tải lại trang web — lấy đúng bản mới nhất đã deploy (bỏ qua cache cũ).
void reloadPage() => web.window.location.reload();
