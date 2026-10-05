import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/backup_excel.dart';
import '../../data/store.dart';
import '../../domain/backup.dart';
import '../../gps/gps_scheduler.dart';
import 'settings_card.dart';

/// Chỗ đã lưu file, viết cho người dùng dễ tìm. Trên Android, hộp chọn chỗ lưu trả về địa chỉ dạng
/// `content://...`; đọc ra thư mục nếu được, không thì chỉ nói tên file.
String savedLocationText(Uri? uri, String fileName) {
  if (kIsWeb || uri == null || uri.scheme == 'blob' || uri.scheme == 'data' || uri.scheme.startsWith('http')) {
    return 'Thư mục Tải xuống (Downloads) của trình duyệt › $fileName';
  }
  if (uri.scheme == 'file') return uri.toFilePath();
  final id = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
  if (id.startsWith('raw:')) {
    return id.substring(4).replaceFirst(RegExp(r'^/storage/emulated/0/'), 'Bộ nhớ máy › ');
  }
  final colon = id.indexOf(':');
  if (uri.host == 'com.android.externalstorage.documents' && colon >= 0) {
    final where = id.substring(0, colon) == 'primary' ? 'Bộ nhớ máy' : 'Thẻ nhớ';
    return '$where › ${id.substring(colon + 1).replaceAll('/', ' › ')}';
  }
  if (uri.host == 'com.android.providers.downloads.documents') return 'Download (Tải xuống) › $fileName';
  if (uri.host.contains('google.android.apps.docs')) return 'Google Drive › $fileName';
  return '$fileName (trong thư mục bạn vừa chọn)';
}

String _date(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Cài đặt › Sao lưu dữ liệu: xuất toàn bộ dữ liệu ra file Excel và khôi phục lại từ file đó.
class BackupSection extends StatefulWidget {
  const BackupSection({super.key, required this.store});

  final AppStore store;

  @override
  State<BackupSection> createState() => _BackupSectionState();
}

class _BackupSectionState extends State<BackupSection> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export() async {
    final store = widget.store;
    final now = DateTime.now();
    var version = '';
    try {
      version = (await PackageInfo.fromPlatform()).version;
    } catch (_) {}
    final bytes = buildBackupExcel(
      settings: store.settings,
      records: store.records,
      periodOverrides: store.periodOverrides,
      exportedAt: now,
      appVersion: version,
    );
    final fileName = backupFileName(now);
    final Uri? uri;
    try {
      uri = await FilePicker.saveFile(
        fileName: fileName,
        bytes: bytes,
        mimeType: xlsxMimeType,
        dialogTitle: 'Chọn chỗ lưu file sao lưu',
        type: FileType.custom,
        allowedExtensions: const ['xlsx'],
      );
    } catch (_) {
      if (mounted) _showMessage('Không lưu được file', 'Máy không mở được hộp chọn chỗ lưu. Hãy thử lại.');
      return;
    }
    // Trên Android, bấm quay lại ở hộp chọn chỗ lưu là hủy.
    if (uri == null && !kIsWeb) return;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đã lưu file sao lưu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('File nằm ở:'),
            const SizedBox(height: 4),
            SelectableText(savedLocationText(uri, fileName), style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            const Text(
              'Mở được bằng Excel, Google Sheets hoặc WPS. Nên gửi thêm một bản lên Google Drive, Zalo '
              'hoặc email của bạn, để vẫn còn file khi mất hay đổi điện thoại.',
            ),
          ],
        ),
        actions: [
          if (!kIsWeb)
            TextButton.icon(
              icon: const Icon(Icons.send_outlined, size: 18),
              label: const Text('Gửi file đi'),
              onPressed: () => SharePlus.instance.share(
                ShareParams(
                  files: [XFile.fromData(bytes, name: fileName, mimeType: xlsxMimeType)],
                  fileNameOverrides: [fileName],
                ),
              ),
            ),
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Xong')),
        ],
      ),
    );
  }

  Future<void> _restore() async {
    final PlatformFile? file;
    try {
      file = await FilePicker.pickFile(
        dialogTitle: 'Chọn file sao lưu (.xlsx)',
        type: FileType.custom,
        allowedExtensions: const ['xlsx'],
      );
    } catch (_) {
      if (mounted) _showMessage('Không mở được file', 'Máy không mở được hộp chọn file. Hãy thử lại.');
      return;
    }
    if (file == null) return;

    final BackupPayload backup;
    try {
      backup = readBackupExcel(await file.xFile.readAsBytes());
    } on FormatException catch (e) {
      if (mounted) _showMessage('Không khôi phục được', e.message);
      return;
    } catch (_) {
      if (mounted) _showMessage('Không khôi phục được', 'Không đọc được file này. Hãy chọn đúng file đã xuất từ app.');
      return;
    }

    final preview = await widget.store.previewRestore(backup);
    if (!mounted) return;

    final lines = [
      'File xuất ngày ${_date(backup.exportedAt)}, có ${backup.records.length} ngày.',
      if (preview.added > 0) '• ${preview.added} ngày app chưa có sẽ được thêm vào.',
      if (preview.replaced > 0) '• ${preview.replaced} ngày trùng sẽ được thay bằng dữ liệu trong file.',
      if (preview.keptNewer > 0)
        '• ${preview.keptNewer} ngày từ ngày xuất file trở về sau giữ nguyên theo app (bạn đã chấm tiếp).',
      if (preview.changedDays == 0) '• Mọi ngày trong file đều đã có trong app, không cần thêm hay thay ngày nào.',
      'Các ngày khác trong app giữ nguyên.',
    ];
    // Mặc định lấy cả cài đặt khi app chưa có dữ liệu (máy mới); người dùng vẫn đổi được.
    var withSettings = !preview.appHadData;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Khôi phục dữ liệu?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(lines.join('\n')),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: withSettings,
                onChanged: (v) => setDialogState(() => withSettings = v ?? false),
                title: const Text('Lấy cả cài đặt theo file'),
                subtitle: const Text('Bảng lương, khung giờ, kỳ lương... GPS cần bật lại sau khi khôi phục.'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Khôi phục')),
          ],
        ),
      ),
    );
    if (ok != true) return;

    final result = await widget.store.restoreBackup(backup, restoreSettings: withSettings);
    if (!kIsWeb && result.settingsRestored) await rescheduleGpsAlarms(widget.store.settings.gps);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Đã khôi phục ${result.changedDays} ngày từ file${result.settingsRestored ? ', kèm cài đặt' : ''}.',
        ),
      ),
    );
  }

  void _showMessage(String title, String message) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      title: 'Sao lưu dữ liệu',
      collapsible: true,
      subtitle:
          'Xuất toàn bộ giờ chấm ra file Excel để cất giữ, xem lại sau này, hoặc khôi phục khi đổi máy, cài lại app.',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton.tonalIcon(
            icon: const Icon(Icons.file_download_outlined),
            label: const Text('Xuất file Excel'),
            onPressed: _busy ? null : () => _run(_export),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.restore),
            label: const Text('Khôi phục từ file'),
            onPressed: _busy ? null : () => _run(_restore),
          ),
        ],
      ),
    );
  }
}
