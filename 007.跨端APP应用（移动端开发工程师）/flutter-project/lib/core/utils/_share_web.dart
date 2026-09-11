import 'dart:html' as html;
import 'dart:typed_data';

/// Web 路径:share_plus 10.x 已不支持 web,所以用 dart:html 直接构造
/// Blob + 隐藏 <a download> 触发浏览器下载,效果跟系统保存一致。
/// Native 编译不会进这个文件(由 export.dart 的 conditional import 切到 _share_io.dart)。
Future<void> writeBytesForExport(Uint8List bytes, String filename) async {
  final blob = html.Blob(<Object>[bytes]);
  // ponytail: dart:html 用 `Url`(驼峰)+ `createObjectUrl`(返回 url),不是 `URL.createObjectURLFromBlob`。
  //          后者在 dart:html 里没定义。`Url.revokeObjectUrl` 同理。
  final url = html.Url.createObjectUrl(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = filename
    ..style.display = 'none';
  html.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}