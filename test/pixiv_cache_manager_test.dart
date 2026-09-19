import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixez/er/pixiv_cache_manager.dart';

class _Response extends Fake implements FileServiceResponse {
  _Response(this.contentLength);
  @override
  final int? contentLength;
  @override
  Stream<List<int>> get content => Stream.value([1, 2, 3]);
  @override
  int get statusCode => 200;
  @override
  String get eTag => 'image-etag';
  @override
  DateTime get validTill => DateTime.utc(2027);
  @override
  String get fileExtension => '.jpg';
}

class _Service extends FileService {
  _Service(this.response);
  final FileServiceResponse response;
  @override
  Future<FileServiceResponse> get(
    String url, {
    Map<String, String>? headers,
  }) async {
    expect(url, 'https://i.pximg.net/image.jpg');
    expect(headers, {'Referer': 'https://www.pixiv.net/'});
    return response;
  }
}

void main() {
  for (final length in <int?>[-1, null, 0, 123]) {
    test(
      'image progress accepts length $length without losing response data',
      () async {
        final response =
            await PixivImageFileService(_Service(_Response(length))).get(
              'https://i.pximg.net/image.jpg',
              headers: {'Referer': 'https://www.pixiv.net/'},
            );
        final progress = ImageChunkEvent(
          cumulativeBytesLoaded: 0,
          expectedTotalBytes: response.contentLength,
        );
        expect(progress.expectedTotalBytes, length == -1 ? null : length);
        expect(await response.content.toList(), [
          [1, 2, 3],
        ]);
        expect(response.statusCode, 200);
        expect(response.eTag, 'image-etag');
        expect(response.validTill, DateTime.utc(2027));
        expect(response.fileExtension, '.jpg');
      },
    );
  }
}
