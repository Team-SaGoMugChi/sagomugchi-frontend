import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 에뮬레이터 테스트용 파일(`--dart-define`으로 켜는 baseline JSON, 얼굴 사진 등)의
/// 위치. 앱 전용 외부 저장소라 권한 없이 adb로 넣을 수 있다:
/// `adb push <파일> /sdcard/Android/data/app.oddo.oddo/files/<이름>`
Future<File> deviceTestFile(String name) async {
  final dir =
      await getExternalStorageDirectory() ??
      await getApplicationDocumentsDirectory();
  return File('${dir.path}/$name');
}
