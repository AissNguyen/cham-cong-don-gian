/// Hỏi máy chủ "đã có ai nhập mã của máy này chưa" từ tiến trình nền (báo thức GPS), để GPS tự
/// chạy lại sau khi được mở khóa mà người dùng không cần mở app.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';
import 'share_state_file.dart';

/// Trả về true nếu máy vừa được mở khóa (và đã ghi lại vào file trạng thái). Máy chưa lấy mã, mất
/// mạng hay lỗi gì cũng trả về false — lần báo thức sau thử lại.
Future<bool> tryUnlockInBackground() async {
  try {
    final state = await readShareState();
    if (state.unlocked) return true;
    if (state.code == null) return false;
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform).timeout(const Duration(seconds: 5));
    final snap = await FirebaseFirestore.instance
        .collection('codes')
        .doc(state.code)
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 10));
    if (snap.data()?['redeemed'] != true) return false;
    await updateShareState((s) => s.copyWith(unlocked: true));
    return true;
  } catch (_) {
    return false;
  }
}
