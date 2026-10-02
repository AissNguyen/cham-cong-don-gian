/// Bản web: lưu dữ liệu vào localStorage của trình duyệt thay cho file.
library;

import 'dart:js_interop';

const _key = 'cham_cong_data';

@JS('localStorage.getItem')
external JSString? _getItem(JSString key);

@JS('localStorage.setItem')
external void _setItem(JSString key, JSString value);

Future<bool> rawDataExists() async => _getItem(_key.toJS) != null;

Future<String?> readRawData() async => _getItem(_key.toJS)?.toDart;

Future<void> writeRawData(String data) async => _setItem(_key.toJS, data.toJS);
