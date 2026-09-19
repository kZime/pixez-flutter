import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pixez/desktop/desktop_file_save.dart';
import 'package:pixez/models/illust.dart';

class _Illustration extends Fake implements Illusts {
  @override
  int get id => 123;
  @override
  List<MetaPages> get metaPages => [];
  @override
  MetaSinglePage get metaSinglePage =>
      MetaSinglePage(originalImageUrl: 'https://i.pximg.net/123.png');
}

class _MultiPageIllustration extends _Illustration {
  @override
  List<MetaPages> get metaPages => List.generate(
    3,
    (index) => MetaPages(
      imageUrls: MetaPagesImageUrls(
        squareMedium: '',
        medium: '',
        large: '',
        original: 'https://i.pximg.net/123_p$index.png',
      ),
    ),
  );
}

void main() {
  test(
    'batch waits for each save sheet and stops after cancellation',
    () async {
      final first = Completer<Uri?>();
      final names = <String>[];
      final save = DesktopFileSave(
        loadBytes: (_) async => Uint8List.fromList([1]),
        showSaveDialog:
            ({required fileName, required bytes, required mimeType}) {
              names.add(fileName);
              return names.length == 1 ? first.future : Future.value(null);
            },
      );
      final pending = save.savePages(_MultiPageIllustration(), [0, 1, 2]);
      await Future<void>.delayed(Duration.zero);
      expect(names, ['123_p0.png']);
      first.complete(Uri.file('/tmp/123_p0.png'));
      expect(await pending, ['/tmp/123_p0.png']);
      expect(names, ['123_p0.png', '123_p1.png']);
    },
  );

  test('batch saves only the selected pages in order', () async {
    final names = <String>[];
    final save = DesktopFileSave(
      loadBytes: (_) async => Uint8List.fromList([1]),
      showSaveDialog:
          ({required fileName, required bytes, required mimeType}) async {
            names.add(fileName);
            return Uri.file('/tmp/$fileName');
          },
    );
    expect(await save.savePages(_MultiPageIllustration(), [2, 0]), [
      '/tmp/123_p2.png',
      '/tmp/123_p0.png',
    ]);
    expect(names, ['123_p2.png', '123_p0.png']);
  });
  test('save does not complete before the picker finishes writing', () async {
    final result = Completer<Uri?>();
    var completed = false;
    final save = DesktopFileSave(
      loadBytes: (_) async => Uint8List.fromList([1, 2, 3]),
      showSaveDialog: ({required fileName, required bytes, required mimeType}) {
        expect(fileName, '123_p0.png');
        expect(bytes, [1, 2, 3]);
        expect(mimeType, 'image/png');
        return result.future;
      },
    );
    final pending = save.save(_Illustration(), 0).then((path) {
      completed = true;
      return path;
    });
    await Future<void>.delayed(Duration.zero);
    expect(completed, isFalse);
    result.complete(Uri.file('/tmp/123_p0.png'));
    expect(await pending, '/tmp/123_p0.png');
  });

  test('cancelled save returns null rather than success', () async {
    final save = DesktopFileSave(
      loadBytes: (_) async => Uint8List.fromList([1]),
      showSaveDialog:
          ({required fileName, required bytes, required mimeType}) async =>
              null,
    );
    expect(await save.save(_Illustration(), 0), isNull);
  });

  test('write errors propagate to the UI instead of reporting saved', () async {
    final save = DesktopFileSave(
      loadBytes: (_) async => Uint8List.fromList([1]),
      showSaveDialog:
          ({required fileName, required bytes, required mimeType}) async {
            throw StateError('write failed');
          },
    );
    await expectLater(save.save(_Illustration(), 0), throwsStateError);
  });

  test('failed download never opens the save dialog', () async {
    var opened = false;
    final save = DesktopFileSave(
      loadBytes: (_) async => throw StateError('download failed'),
      showSaveDialog:
          ({required fileName, required bytes, required mimeType}) async {
            opened = true;
            return Uri.file('/tmp/unwritten.png');
          },
    );
    await expectLater(save.save(_Illustration(), 0), throwsStateError);
    expect(opened, isFalse);
  });
}
