/// Thông báo từ chủ app tới người dùng (hướng dẫn cách dùng, mời vào nhóm, tin cập nhật...): soạn
/// trên Firebase Remote Config, app hiện thành một băng ở đầu màn chính, không cần phát hành bản mới.
///
/// Tham số Remote Config:
/// - `notice_text`: nội dung (để trống = không có thông báo). Gõ `\n` để xuống dòng.
/// - `notice_title`: tiêu đề in đậm (không bắt buộc).
/// - `notice_url` + `notice_button`: link mở khi bấm nút và chữ trên nút (không bắt buộc; có link
///   mà không đặt chữ thì nút ghi "Xem").
/// Người dùng bấm × thì thông báo đó ẩn hẳn; đổi nội dung/tiêu đề/link là thành thông báo mới và
/// hiện lại cho mọi người.
library;

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

const _kDismissedKey = 'notice_dismissed';

class AppNotice {
  const AppNotice({required this.text, this.title = '', this.url = '', this.button = ''});

  final String text;
  final String title;
  final String url;
  final String button;

  /// Dùng để nhớ thông báo nào người dùng đã tắt — đổi nội dung là thành thông báo khác.
  String get key => '$title|$text|$url';

  bool get hasLink => url.isNotEmpty;
  String get buttonLabel => button.isNotEmpty ? button : 'Xem';

  /// Trả về null nếu không có nội dung. `\n` gõ trong Firebase Console được đổi thành xuống dòng.
  static AppNotice? fromValues({required String text, String title = '', String url = '', String button = ''}) {
    final body = text.replaceAll(r'\n', '\n').trim();
    if (body.isEmpty) return null;
    final link = url.trim();
    final uri = Uri.tryParse(link);
    final validLink = uri != null && (uri.scheme == 'https' || uri.scheme == 'http') && uri.host.isNotEmpty;
    return AppNotice(text: body, title: title.trim(), url: validLink ? link : '', button: button.trim());
  }
}

/// Thông báo đang cần hiện (null = không có, hoặc người dùng đã tắt thông báo này).
final currentNotice = ValueNotifier<AppNotice?>(null);

/// Gọi sau khi Remote Config đã tải (xem `checkForUpdate`). Không bao giờ ném lỗi.
Future<void> loadNotice() async {
  try {
    final rc = FirebaseRemoteConfig.instance;
    final notice = AppNotice.fromValues(
      text: rc.getString('notice_text'),
      title: rc.getString('notice_title'),
      url: rc.getString('notice_url'),
      button: rc.getString('notice_button'),
    );
    if (notice == null) {
      currentNotice.value = null;
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    currentNotice.value = prefs.getString(_kDismissedKey) == notice.key ? null : notice;
  } catch (_) {
    // Bỏ qua — lần mở app sau thử lại.
  }
}

Future<void> dismissNotice() async {
  final notice = currentNotice.value;
  currentNotice.value = null;
  if (notice == null) return;
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDismissedKey, notice.key);
  } catch (_) {
    // Không lưu được thì lần mở app sau thông báo hiện lại, không sao.
  }
}

/// Băng thông báo ở đầu màn chính — không chiếm chỗ khi không có thông báo.
class NoticeBanner extends StatelessWidget {
  const NoticeBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppNotice?>(
      valueListenable: currentNotice,
      builder: (context, notice, _) {
        if (notice == null) return const SizedBox.shrink();
        final color = Theme.of(context).colorScheme.primary;
        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Material(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 4, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Icon(Icons.campaign_outlined, color: color, size: 20),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (notice.title.isNotEmpty)
                            Text(notice.title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                          Text(notice.text, style: const TextStyle(fontSize: 12.5)),
                          if (notice.hasLink)
                            TextButton(
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 32),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () => launchUrl(Uri.parse(notice.url), mode: LaunchMode.externalApplication),
                              child: Text(notice.buttonLabel),
                            ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close, size: 18), onPressed: dismissNotice, tooltip: 'Đóng'),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
