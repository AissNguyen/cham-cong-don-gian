/// Nội dung "Hướng dẫn sử dụng" soạn trên Firebase Remote Config (`help_text`), thay cho nội dung
/// có sẵn trong app mà không cần ra bản mới.
///
/// Cách gõ: mỗi mục một dòng dạng `Tiêu đề | Nội dung` (trong ô nhập một dòng của Firebase Console
/// thì gõ `\n` giữa các mục). Dòng không có dấu `|` được nối vào nội dung của mục ngay trên nó, để
/// một mục có thể dài nhiều đoạn. Để trống `help_text` thì app dùng hướng dẫn có sẵn.
library;

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

class HelpEntry {
  const HelpEntry(this.title, this.body);

  final String title;
  final String body;
}

/// Trả về null nếu không có mục nào (để app dùng hướng dẫn có sẵn).
List<HelpEntry>? parseHelpText(String raw) {
  final entries = <(String, List<String>)>[];
  for (final line in raw.replaceAll(r'\n', '\n').split('\n')) {
    final text = line.trim();
    if (text.isEmpty) continue;
    final bar = text.indexOf('|');
    if (bar >= 0) {
      entries.add((text.substring(0, bar).trim(), [text.substring(bar + 1).trim()]));
    } else if (entries.isNotEmpty) {
      entries.last.$2.add(text);
    } else {
      // Dòng đầu không có `|`: coi cả dòng là tiêu đề.
      entries.add((text, []));
    }
  }
  final result = [
    for (final (title, body) in entries)
      if (title.isNotEmpty || body.any((b) => b.isNotEmpty))
        HelpEntry(title, body.where((b) => b.isNotEmpty).join('\n')),
  ];
  return result.isEmpty ? null : result;
}

/// Hướng dẫn tải từ Firebase (null = dùng hướng dẫn có sẵn trong app).
final remoteHelpEntries = ValueNotifier<List<HelpEntry>?>(null);

/// Gọi sau khi Remote Config đã tải (xem `checkForUpdate`). Không bao giờ ném lỗi.
void loadHelpText() {
  try {
    remoteHelpEntries.value = parseHelpText(FirebaseRemoteConfig.instance.getString('help_text'));
  } catch (_) {
    // Firebase không có (bị chặn, mất mạng...) thì dùng hướng dẫn có sẵn.
  }
}
