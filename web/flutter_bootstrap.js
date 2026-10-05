{{flutter_js}}
{{flutter_build_config}}

// Tự viết file khởi động thay cho file mặc định của Flutter để:
// - Lấy CanvasKit (phần vẽ giao diện) từ chính trang này thay vì máy chủ gstatic.com của Google,
//   để service worker lưu sẵn được và app mở được khi mất mạng.
// - Không đăng ký service worker cũ của Flutter (đã bị Flutter bỏ); app dùng `sw.js` riêng, đăng
//   ký trong index.html.
_flutter.loader.load({
  config: {
    canvasKitBaseUrl: "canvaskit/",
  },
});
