import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// native / desktop 路径:写到临时目录 + share_plus 系统分享面板。
/// Web 编译不会进这个文件(由 export.dart 的 conditional import 切到 _share_web.dart)。
Future<void> writeBytesForExport(Uint8List bytes, String filename) async {
  if (Platform.isAndroid || Platform.isIOS) {
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/$filename');
    await f.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(f.path)], text: filename);
  } else {
    throw UnsupportedError('Use writeBytes on this platform');
  }
}