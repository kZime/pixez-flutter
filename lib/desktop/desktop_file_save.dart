import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:pixez/component/pixiv_image.dart';
import 'package:pixez/er/hoster.dart';
import 'package:pixez/models/illust.dart';

typedef DesktopSaveDialog =
    Future<Uri?> Function({
      required String fileName,
      required Uint8List bytes,
      required String mimeType,
    });

/// The picker writes the bytes before completing; null means user cancellation.
/// This path deliberately leaves the mobile Photos/download queue unchanged.
class DesktopFileSave {
  DesktopFileSave({required this.loadBytes, required this.showSaveDialog});

  factory DesktopFileSave.platform() => DesktopFileSave(
    loadBytes: (url) async {
      final file = await pixivCacheManager!.getSingleFile(
        url,
        headers: Hoster.header(url: url),
      );
      return file.readAsBytes();
    },
    showSaveDialog: ({required fileName, required bytes, required mimeType}) =>
        FilePicker.saveFile(
          fileName: fileName,
          bytes: bytes,
          mimeType: mimeType,
        ),
  );

  final Future<Uint8List> Function(String url) loadBytes;
  final DesktopSaveDialog showSaveDialog;

  /// Present one native save sheet at a time; cancellation stops the batch.
  Future<List<String>> savePages(Illusts illust, Iterable<int> pages) async {
    final saved = <String>[];
    for (final page in pages) {
      final path = await save(illust, page);
      if (path == null) break;
      saved.add(path);
    }
    return saved;
  }

  Future<String?> save(Illusts illust, int pageIndex) async {
    final String? original;
    if (illust.metaPages.isNotEmpty) {
      if (pageIndex < 0 || pageIndex >= illust.metaPages.length) {
        throw RangeError.index(pageIndex, illust.metaPages);
      }
      original = illust.metaPages[pageIndex].imageUrls?.original;
    } else {
      if (pageIndex != 0) throw RangeError.value(pageIndex);
      original = illust.metaSinglePage?.originalImageUrl;
    }
    if (original == null || original.isEmpty) {
      throw StateError('Original image is unavailable');
    }
    final path = Uri.parse(original).path.toLowerCase();
    final extension = path.endsWith('.png') ? 'png' : 'jpg';
    final bytes = await loadBytes(original);
    if (bytes.isEmpty) throw StateError('Image download was empty');
    final result = await showSaveDialog(
      fileName: '${illust.id}_p$pageIndex.$extension',
      bytes: bytes,
      mimeType: extension == 'png' ? 'image/png' : 'image/jpeg',
    );
    return result?.toFilePath();
  }
}
