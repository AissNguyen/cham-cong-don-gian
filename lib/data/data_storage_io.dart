import 'dart:io';

import 'package:path_provider/path_provider.dart';

Future<File> _dataFile() async {
  final dir = await getApplicationDocumentsDirectory();
  return File('${dir.path}/cham_cong_data.json');
}

Future<bool> rawDataExists() async => (await _dataFile()).exists();

Future<String?> readRawData() async {
  final file = await _dataFile();
  if (!await file.exists()) return null;
  return file.readAsString();
}

Future<void> writeRawData(String data) async => (await _dataFile()).writeAsString(data);
