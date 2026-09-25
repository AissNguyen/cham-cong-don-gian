/// Xuất/nhập cài đặt dạng chuỗi JSON để sao chép - dán chia sẻ giữa các máy.
library;

import 'dart:convert';

import 'models.dart';

const _encoder = JsonEncoder.withIndent('  ');

String encodeSettings(AppSettings settings) => _encoder.convert(settings.toJson());

/// Trả về null nếu chuỗi dán vào không hợp lệ.
AppSettings? decodeSettings(String text) {
  try {
    final json = jsonDecode(text) as Map<String, dynamic>;
    return AppSettings.fromJson(json);
  } catch (_) {
    return null;
  }
}
