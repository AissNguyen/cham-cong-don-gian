/// Thông báo từ chủ app tới người dùng (hướng dẫn cách dùng, mời vào nhóm, tin cập nhật...): soạn
/// trên Firebase Remote Config, app hiện thành một băng ở đầu màn chính, không cần phát hành bản mới.
///
/// Tham số Remote Config:
/// - `notice_text`: nội dung (để trống = không có thông báo). Gõ `\n` để xuống dòng.
/// - `notice_title`: tiêu đề in đậm (không bắt buộc).
/// - `notice_links`: nhiều link, mỗi dòng (hoặc cách nhau bằng `\n`) một link dạng
///   `Nhóm Zalo | https://zalo.me/g/...`; mỗi link thành một nút (không bắt buộc).
/// - `notice_url` + `notice_button`: kiểu cũ, một link và chữ trên nút; vẫn dùng được, đứng trước
///   các link của `notice_links` (có link mà không đặt chữ thì nút ghi "Xem").
/// Băng chỉ hiện vài dòng đầu, nội dung dài thì có nút "Xem thêm". Người dùng bấm × thì băng ẩn
/// hẳn và app nhắc rằng xem lại được ở Cài đặt › Thông báo; đổi nội dung/tiêu đề/link là thành
/// thông báo mới và hiện lại cho mọi người.
library;

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

const _kDismissedKey = 'notice_dismissed';

/// Số dòng nội dung tối đa trên băng; dài hơn thì có nút "Xem thêm".
const noticeBannerMaxLines = 3;

class NoticeLink {
  const NoticeLink(this.label, this.url);

  final String label;
  final String url;
}

class AppNotice {
  const AppNotice({required this.text, this.title = '', this.links = const []});

  final String text;
  final String title;
  final List<NoticeLink> links;

  /// Dùng để nhớ thông báo nào người dùng đã tắt — đổi nội dung là thành thông báo khác.
  String get key => '$title|$text|${links.map((l) => l.url).join(' ')}';

  bool get hasLink => links.isNotEmpty;

  /// Trả về null nếu không có nội dung. `\n` gõ trong Firebase Console được đổi thành xuống dòng.
  static AppNotice? fromValues({
    required String text,
    String title = '',
    String url = '',
    String button = '',
    String links = '',
  }) {
    final body = text.replaceAll(r'\n', '\n').trim();
    if (body.isEmpty) return null;
    final all = <NoticeLink>[];
    final legacy = _validUrl(url);
    if (legacy != null) all.add(NoticeLink(button.trim().isNotEmpty ? button.trim() : 'Xem', legacy));
    all.addAll(parseNoticeLinks(links));
    return AppNotice(text: body, title: title.trim(), links: all);
  }
}

/// Đọc danh sách link dạng `Chữ trên nút | https://...`, mỗi dòng một link. Dòng chỉ có link thì nút
/// ghi "Mở link"; dòng có link sai (không phải http/https) thì bỏ qua.
List<NoticeLink> parseNoticeLinks(String raw) {
  final result = <NoticeLink>[];
  for (final line in raw.replaceAll(r'\n', '\n').split('\n')) {
    final bar = line.lastIndexOf('|');
    final label = bar < 0 ? '' : line.substring(0, bar).trim();
    final url = _validUrl(bar < 0 ? line : line.substring(bar + 1));
    if (url == null) continue;
    result.add(NoticeLink(label.isNotEmpty ? label : 'Mở link', url));
  }
  return result;
}

String? _validUrl(String raw) {
  final link = raw.trim();
  final uri = Uri.tryParse(link);
  final ok = uri != null && (uri.scheme == 'https' || uri.scheme == 'http') && uri.host.isNotEmpty;
  return ok ? link : null;
}

/// Thông báo đang đặt trên Firebase, kể cả khi người dùng đã tắt băng — mục Cài đặt › Thông báo
/// đọc cái này (null = không có thông báo, mục đó ẩn đi).
final activeNotice = ValueNotifier<AppNotice?>(null);

/// Thông báo cần hiện trên băng ở màn chính (null = không có, hoặc người dùng đã tắt thông báo này).
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
      links: rc.getString('notice_links'),
    );
    activeNotice.value = notice;
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

void _openLink(String url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

/// Các nút link của thông báo, xếp xuống dòng khi không đủ chỗ.
class NoticeLinkButtons extends StatelessWidget {
  const NoticeLinkButtons({super.key, required this.links, this.compact = false});

  final List<NoticeLink> links;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: compact ? 0 : 8,
      children: [
        for (final link in links)
          compact
              ? TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => _openLink(link.url),
                  child: Text(link.label),
                )
              : OutlinedButton.icon(
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: Text(link.label),
                  onPressed: () => _openLink(link.url),
                ),
      ],
    );
  }
}

/// Toàn bộ nội dung thông báo (dùng trong hộp "Xem thêm" và mục Cài đặt › Thông báo).
class NoticeFullContent extends StatelessWidget {
  const NoticeFullContent({super.key, required this.notice});

  final AppNotice notice;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (notice.title.isNotEmpty) ...[
          Text(notice.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
        ],
        Text(notice.text, style: const TextStyle(fontSize: 13.5)),
        if (notice.hasLink) ...[const SizedBox(height: 12), NoticeLinkButtons(links: notice.links)],
      ],
    );
  }
}

void showNoticeDetails(BuildContext context, AppNotice notice) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: SizedBox(
            width: double.infinity,
            child: NoticeFullContent(notice: notice),
          ),
        ),
      ),
    ),
  );
}

/// Băng thông báo ở đầu màn chính — không chiếm chỗ khi không có thông báo.
class NoticeBanner extends StatelessWidget {
  const NoticeBanner({super.key});

  void _close(BuildContext context) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    dismissNotice();
    messenger?.showSnackBar(
      const SnackBar(content: Text('Bạn có thể xem lại thông báo này trong Cài đặt › Thông báo.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppNotice?>(
      valueListenable: currentNotice,
      builder: (context, notice, _) {
        if (notice == null) return const SizedBox.shrink();
        final color = Theme.of(context).colorScheme.primary;
        const textStyle = TextStyle(fontSize: 12.5);
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
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final painter = TextPainter(
                            text: TextSpan(
                              text: notice.text,
                              style: DefaultTextStyle.of(context).style.merge(textStyle),
                            ),
                            maxLines: noticeBannerMaxLines,
                            textDirection: Directionality.of(context),
                            textScaler: MediaQuery.textScalerOf(context),
                          )..layout(maxWidth: constraints.maxWidth);
                          final tooLong = painter.didExceedMaxLines;
                          painter.dispose();
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (notice.title.isNotEmpty)
                                Text(notice.title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                              Text(
                                notice.text,
                                style: textStyle,
                                maxLines: noticeBannerMaxLines,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (tooLong || notice.hasLink)
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    if (tooLong)
                                      TextButton(
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 4),
                                          minimumSize: const Size(0, 32),
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        onPressed: () => showNoticeDetails(context, notice),
                                        child: const Text('Xem thêm'),
                                      ),
                                    if (notice.hasLink) NoticeLinkButtons(links: notice.links, compact: true),
                                  ],
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => _close(context),
                    tooltip: 'Đóng',
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
