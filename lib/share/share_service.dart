/// Mã giới thiệu qua Firestore: đánh số máy, đếm tổng số máy, cấp mã 6 chữ số khi người dùng bấm
/// "Lấy mã", ghi nhận máy khác nhập mã, và nhận mở khóa khi có máy nhập mã của mình. Chỉ chạy ở
/// tiến trình chính trên Android (riêng việc hỏi "đã được mở khóa chưa" còn có bản chạy nền ở
/// `background_unlock.dart`).
///
/// Dữ liệu trên máy chủ:
/// - `meta/counter`: count = tổng số máy đã dùng app.
/// - `devices/{mã thiết bị}`: seq, firstSeen, code (mã của máy), redeemedCode (mã đã nhập),
///   autoUseDays, và các số lượt dùng (appOpens, widgetUses, gpsUses, lastSeen, appVersion).
/// - `codes/{mã}`: owner (mã thiết bị của chủ mã), redeemed (đã có máy khác nhập chưa).
/// Lưu theo mã thiết bị Android nên gỡ ra cài lại vẫn giữ nguyên số ngày đã dùng và trạng thái mở khóa.
library;

import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';

import '../domain/share_gate.dart';
import '../widget/widget_sync.dart';
import 'share_state_file.dart';

const _deviceChannel = MethodChannel('chamcong/device');
const _timeout = Duration(seconds: 10);
const _serverOnly = GetOptions(source: Source.server);

enum RedeemResult { ok, invalidFormat, notFound, ownCode, hasOwnCode, alreadyRedeemed, expired, offline }

String redeemMessage(RedeemResult r) => switch (r) {
  RedeemResult.ok => 'Đã ghi nhận. Cảm ơn bạn!',
  RedeemResult.invalidFormat => 'Mã gồm đúng 6 chữ số.',
  RedeemResult.notFound => 'Không có mã này, bạn kiểm tra lại giúp.',
  RedeemResult.ownCode => 'Đây là mã của chính máy bạn.',
  RedeemResult.hasOwnCode => 'Máy này đã lấy mã của mình nên không nhập mã của người khác được nữa.',
  RedeemResult.alreadyRedeemed => 'Máy này đã nhập mã giới thiệu rồi.',
  RedeemResult.expired => 'Đã hết thời hạn nhập mã giới thiệu.',
  RedeemResult.offline => 'Chưa kết nối được máy chủ, bạn kiểm tra mạng rồi thử lại.',
};

class ShareController extends ChangeNotifier {
  ShareState state = const ShareState();
  bool syncing = false;
  DateTime? _lastSync;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _codeSub;

  bool get allowed => autoAllowed(state, DateTime.now());
  bool get entryIsOpen => entryOpen(state, DateTime.now());

  /// Đang chờ người khác nhập mã của máy này.
  bool get _waitingForRedeem => gateOn(state) && state.code != null && !state.unlocked;

  Future<void> load() async {
    state = await readShareState();
    notifyListeners();
  }

  Future<void> _update(ShareState Function(ShareState) update) async {
    state = await updateShareState(update);
    notifyListeners();
  }

  Future<void> markEntryPromptShown() => _update((s) => s.copyWith(entryPromptShown: true));

  /// Người dùng vừa chạm nút "Mở khóa" trên widget: màn chính cần hiện lại hộp chia sẻ.
  bool lockNoticeRequested = false;

  void requestLockNotice() {
    lockNoticeRequested = true;
    notifyListeners();
  }

  Future<void> markLockNoticeShown() {
    lockNoticeRequested = false;
    return _update((s) => s.copyWith(lockNoticeShown: true));
  }

  Future<String?> _deviceId() async {
    try {
      final id = await _deviceChannel.invokeMethod<String>('androidId');
      return (id == null || id.isEmpty) ? null : id;
    } catch (_) {
      return null;
    }
  }

  /// X, Y, thời hạn ô nhập và link chia sẻ từ Remote Config. Tham số chưa đặt trên máy chủ thì
  /// dùng mặc định; riêng `share_trial_days` đặt 0 nghĩa là tắt hẳn tính năng.
  void _readRemoteConfig() {
    final rc = FirebaseRemoteConfig.instance;
    int number(String key, int fallback) {
      final v = rc.getValue(key);
      return v.source == ValueSource.valueStatic ? fallback : v.asInt();
    }

    final trialDays = number('share_trial_days', defaultTrialDays);
    final shareUrl = rc.getString('share_url');
    state = state.copyWith(
      enabled: trialDays > 0,
      trialDays: trialDays > 0 ? trialDays : defaultTrialDays,
      freeUsers: number('share_free_users', defaultFreeUsers),
      entryHours: number('share_entry_hours', defaultEntryHours),
      shareUrl: shareUrl.isNotEmpty ? shareUrl : defaultShareUrl,
    );
  }

  /// Đồng bộ với máy chủ: gọi mỗi lần mở/quay lại app (sau khi Remote Config đã tải). Không bao
  /// giờ ném lỗi — mất mạng thì giữ nguyên trạng thái đang lưu trong máy, lần sau thử lại.
  Future<void> sync({bool force = false}) async {
    if (kIsWeb || syncing) return;
    final now = DateTime.now();
    // Bình thường tối đa 10 phút hỏi máy chủ một lần; riêng máy đang chờ người khác nhập mã thì
    // lần mở app nào cũng hỏi, để được mở khóa ngay.
    final throttled = _lastSync != null && now.difference(_lastSync!) < const Duration(minutes: 10);
    if (!force && throttled && !_waitingForRedeem) return;
    syncing = true;
    notifyListeners();
    try {
      // Đọc lại file trước: widget/GPS nền có thể vừa ghi thêm ngày dùng (hoặc vừa tự mở khóa).
      state = await readShareState();
      _readRemoteConfig();

      final id = await _deviceId();
      if (id == null) return;
      final db = FirebaseFirestore.instance;
      final devRef = db.collection('devices').doc(id);

      // Đăng ký máy với máy chủ để lấy số thứ tự và góp vào tổng số máy.
      if (state.seq == null) {
        state = state.copyWith(seq: await _register(db, devRef).timeout(_timeout));
      }
      await _sendUsage(devRef);

      // Chưa vượt X máy thì hỏi lại tổng số máy; đã vượt rồi thì không cần hỏi nữa (số chỉ tăng).
      if (!gateOn(state)) {
        final counter = await db.collection('meta').doc('counter').get(_serverOnly).timeout(_timeout);
        state = state.copyWith(totalCount: counter.data()?['count'] as int?);
      }
      _lastSync = now;
      if (!gateOn(state)) return;

      final dev = await devRef.get(_serverOnly).timeout(_timeout);
      final data = dev.data() ?? const <String, dynamic>{};

      // Gộp số ngày đã dùng giữa máy và máy chủ, để cài lại không được đếm lại từ đầu.
      final serverDays = ((data['autoUseDays'] as List?) ?? const []).cast<String>();
      final days = {...serverDays, ...state.autoUseDays}.toList()..sort();
      if (days.length > serverDays.length) {
        await devRef.update({'autoUseDays': FieldValue.arrayUnion(days)}).timeout(_timeout);
      }

      final code = data['code'] as String?;
      var unlocked = state.unlocked;
      if (code != null && !unlocked) {
        final codeSnap = await db.collection('codes').doc(code).get(_serverOnly).timeout(_timeout);
        unlocked = codeSnap.data()?['redeemed'] == true;
      }

      state = state.copyWith(
        autoUseDays: days,
        code: code,
        unlocked: unlocked,
        firstSeen: (data['firstSeen'] as Timestamp?)?.toDate(),
        redeemedCode: data['redeemedCode'] as String?,
      );
    } catch (_) {
      // Mất mạng / máy chủ lỗi: bỏ qua, lần mở app sau thử lại.
    } finally {
      // Ghi lại nhưng giữ những gì tiến trình nền có thể vừa ghi trong lúc đang đồng bộ.
      final synced = state;
      try {
        state = await updateShareState(
          (onDisk) => synced.copyWith(
            autoUseDays: ({...onDisk.autoUseDays, ...synced.autoUseDays}.toList()..sort()),
            unlocked: synced.unlocked || onDisk.unlocked,
          ),
        );
        await refreshWidgetDisplay();
      } catch (_) {
        // Không ghi được file / vẽ lại widget: giữ trạng thái trong bộ nhớ, lần sau thử lại.
      }
      _watchCode();
      syncing = false;
      notifyListeners();
    }
  }

  /// Trong lúc app đang mở và máy đang chờ người khác nhập mã: nghe trực tiếp ô mã của mình trên
  /// máy chủ, có người nhập là mở khóa trong vài giây mà không phải bấm gì.
  void _watchCode() {
    if (!_waitingForRedeem) {
      _codeSub?.cancel();
      _codeSub = null;
      return;
    }
    if (_codeSub != null) return;
    try {
      _codeSub = FirebaseFirestore.instance.collection('codes').doc(state.code).snapshots().listen((snap) async {
        if (snap.data()?['redeemed'] != true) return;
        await _codeSub?.cancel();
        _codeSub = null;
        try {
          await _update((s) => s.copyWith(unlocked: true));
          await refreshWidgetDisplay();
        } catch (_) {
          // Lần đồng bộ sau sẽ ghi lại.
        }
      }, onError: (_) {});
    } catch (_) {
      // Không nghe được thì vẫn còn lần đồng bộ lúc mở app.
    }
  }

  /// Gửi số lượt dùng đang chờ (mở app, bấm widget, GPS tự chấm) và các ngày đã dùng GPS/widget
  /// lên tài liệu của máy này, để xem được từng máy ở Firebase Console › Firestore › devices. Lỗi
  /// thì bỏ qua, lần sau gửi tiếp — không được chặn phần đồng bộ mã giới thiệu phía sau.
  Future<void> _sendUsage(DocumentReference<Map<String, dynamic>> devRef) async {
    try {
      // Số thứ tự máy làm mã người dùng trong Analytics (không dùng mã thiết bị).
      FirebaseAnalytics.instance.setUserId(id: '${state.seq}').ignore();
      final pending = await readPendingUsage();
      if (pending.isEmpty) return;
      await devRef.update({
        for (final e in pending.entries) e.key: FieldValue.increment(e.value),
        if (state.autoUseDays.isNotEmpty) 'autoUseDays': FieldValue.arrayUnion(state.autoUseDays),
        'lastSeen': FieldValue.serverTimestamp(),
        'appVersion': (await PackageInfo.fromPlatform()).version,
      }).timeout(_timeout);
      await clearSentUsage(pending);
    } catch (_) {
      // Bỏ qua.
    }
  }

  /// Ghi nhận máy này trên máy chủ (nếu chưa có) và cấp số thứ tự kế tiếp từ bộ đếm chung. Máy đã
  /// có số (vd gỡ ra cài lại) thì lấy lại đúng số cũ.
  Future<int> _register(FirebaseFirestore db, DocumentReference<Map<String, dynamic>> devRef) {
    final counterRef = db.collection('meta').doc('counter');
    return db.runTransaction((tx) async {
      final dev = await tx.get(devRef);
      final existing = dev.data()?['seq'] as int?;
      if (existing != null) return existing;
      final counter = await tx.get(counterRef);
      final next = ((counter.data()?['count'] as int?) ?? 0) + 1;
      tx.set(counterRef, {'count': next});
      if (dev.exists) {
        tx.update(devRef, {'seq': next});
      } else {
        tx.set(devRef, {'firstSeen': FieldValue.serverTimestamp(), 'seq': next});
      }
      return next;
    });
  }

  /// Người dùng bấm "Lấy mã": cấp mã 6 chữ số cho máy này (máy đã có mã từ trước, vd cài lại, thì
  /// lấy lại mã cũ). Từ lúc có mã, máy này không nhập mã của người khác được nữa. Trả về false nếu
  /// chưa kết nối được máy chủ.
  Future<bool> takeCode() async {
    if (kIsWeb) return false;
    try {
      final id = await _deviceId();
      if (id == null) return false;
      final db = FirebaseFirestore.instance;
      final devRef = db.collection('devices').doc(id);
      if (state.seq == null) {
        state = state.copyWith(seq: await _register(db, devRef).timeout(_timeout));
      }
      final dev = await devRef.get(_serverOnly).timeout(_timeout);
      final code = dev.data()?['code'] as String? ?? await _createCode(db, devRef, id);
      if (code == null) return false;
      await _update((s) => s.copyWith(seq: state.seq, code: code));
      _watchCode();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Tạo mã 6 chữ số chưa ai dùng cho máy này.
  Future<String?> _createCode(FirebaseFirestore db, DocumentReference<Map<String, dynamic>> devRef, String id) async {
    final random = Random.secure();
    for (var attempt = 0; attempt < 5; attempt++) {
      final code = (100000 + random.nextInt(900000)).toString();
      final codeRef = db.collection('codes').doc(code);
      final created = await db.runTransaction((tx) async {
        if ((await tx.get(codeRef)).exists) return false;
        tx.set(codeRef, {'owner': id, 'createdAt': FieldValue.serverTimestamp(), 'redeemed': false});
        tx.update(devRef, {'code': code});
        return true;
      }).timeout(_timeout);
      if (created) return code;
    }
    return null;
  }

  /// Nhập mã của người giới thiệu. Chỉ máy chưa lấy mã của mình mới nhập được.
  Future<RedeemResult> redeem(String input) async {
    final code = input.trim();
    if (!isValidCode(code)) return RedeemResult.invalidFormat;
    if (state.redeemedCode != null) return RedeemResult.alreadyRedeemed;
    if (state.code != null) return RedeemResult.hasOwnCode;
    if (!entryOpen(state, DateTime.now())) return RedeemResult.expired;
    try {
      final id = await _deviceId();
      if (id == null) return RedeemResult.offline;
      final db = FirebaseFirestore.instance;
      final devRef = db.collection('devices').doc(id);
      final codeRef = db.collection('codes').doc(code);

      final result = await db.runTransaction((tx) async {
        final dev = await tx.get(devRef);
        if (!dev.exists) return RedeemResult.offline;
        if (dev.data()?['redeemedCode'] != null) return RedeemResult.alreadyRedeemed;
        if (dev.data()?['code'] != null) return RedeemResult.hasOwnCode;
        final codeSnap = await tx.get(codeRef);
        if (!codeSnap.exists) return RedeemResult.notFound;
        final owner = codeSnap.data()?['owner'] as String?;
        if (owner == null) return RedeemResult.notFound;
        if (owner == id) return RedeemResult.ownCode;
        tx.update(devRef, {'redeemedCode': code, 'redeemedAt': FieldValue.serverTimestamp()});
        tx.update(codeRef, {
          'redeemed': true,
          'redeemedAt': FieldValue.serverTimestamp(),
          'redeemedCount': FieldValue.increment(1),
        });
        return RedeemResult.ok;
      }).timeout(_timeout);

      if (result == RedeemResult.ok) {
        await _update((s) => s.copyWith(redeemedCode: code, entryPromptShown: true));
      } else if (result == RedeemResult.alreadyRedeemed || result == RedeemResult.hasOwnCode) {
        await sync(force: true);
      }
      return result;
    } catch (_) {
      return RedeemResult.offline;
    }
  }

  /// Mở khung chia sẻ của điện thoại (Zalo, Messenger...).
  Future<void> shareApp() async {
    await SharePlus.instance.share(ShareParams(text: shareMessage(state)));
  }
}

final shareController = ShareController();
