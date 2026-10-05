// Service worker của bản web: lưu sẵn app trong máy để lần sau mở ngay, kể cả khi mất mạng.
//
// Cách làm ("dùng bản đã lưu, cập nhật ngầm"): mỗi file của app (cùng tên miền) được trả ngay từ
// bộ nhớ đệm nếu đã có, đồng thời tải bản mới từ máy chủ để thay vào bộ nhớ đệm. Nhờ vậy bản web
// mới deploy sẽ có hiệu lực ở lần mở kế tiếp. File của bên khác (Firebase, Google...) không lưu.
// Mọi đường dẫn trang (do Firebase Hosting chuyển hết về index.html) dùng chung bản index.html.
//
// Đổi CACHE_NAME chỉ khi cần xóa sạch bộ nhớ đệm cũ trên mọi máy.
const CACHE_NAME = 'cham-cong-v1';
const CORE = ['index.html', 'flutter_bootstrap.js', 'main.dart.js', 'manifest.json', 'favicon.png', 'icons/Icon-192.png'];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches
      .open(CACHE_NAME)
      .then((cache) => Promise.all(CORE.map((url) => fetchAndStore(cache, new Request(url)).catch(() => {}))))
      .then(() => self.skipWaiting()),
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== CACHE_NAME).map((k) => caches.delete(k))))
      .then(() => self.clients.claim()),
  );
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET') return;
  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;
  // Bản thân sw.js để trình duyệt tự kiểm tra bản mới.
  if (url.pathname.endsWith('/sw.js')) return;

  const key = request.mode === 'navigate' ? new Request('index.html') : request;
  event.respondWith(
    caches.open(CACHE_NAME).then(async (cache) => {
      const cached = await cache.match(key, { ignoreSearch: true });
      const fresh = fetchAndStore(cache, key);
      if (cached) {
        event.waitUntil(fresh.catch(() => {}));
        return cached;
      }
      return fresh;
    }),
  );
});

// Tải file từ máy chủ (luôn hỏi máy chủ xem có bản mới không) và lưu vào bộ nhớ đệm nếu tải được.
async function fetchAndStore(cache, request) {
  const response = await fetch(request, { cache: 'no-cache' });
  if (response.ok && response.type === 'basic') {
    await cache.put(request, response.clone());
  }
  return response;
}
