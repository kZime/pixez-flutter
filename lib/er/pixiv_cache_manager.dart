import 'package:dio/dio.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_cache_manager_dio/flutter_cache_manager_dio.dart';

/// Shared image cache; keep the existing key so saved cache entries survive.
class PixivCacheManager extends CacheManager {
  static late final PixivCacheManager instance;

  static void initialize(Dio client) {
    instance = PixivCacheManager._(client);
  }

  PixivCacheManager._(Dio client)
    : super(
        Config(
          DioCacheManager.key,
          fileService: PixivImageFileService(DioHttpFileService(client)),
        ),
      );
}

/// flutter_cache_manager_dio uses -1 for an unknown Content-Length, while
/// FileServiceResponse and Flutter's ImageChunkEvent require null instead.
class PixivImageFileService extends FileService {
  PixivImageFileService(this.delegate);
  final FileService delegate;

  @override
  Future<FileServiceResponse> get(
    String url, {
    Map<String, String>? headers,
  }) async {
    return _ImageResponse(await delegate.get(url, headers: headers));
  }
}

class _ImageResponse implements FileServiceResponse {
  _ImageResponse(this.delegate);
  final FileServiceResponse delegate;

  @override
  int? get contentLength {
    final length = delegate.contentLength;
    return length == null || length < 0 ? null : length;
  }

  @override
  Stream<List<int>> get content => delegate.content;
  @override
  int get statusCode => delegate.statusCode;
  @override
  DateTime get validTill => delegate.validTill;
  @override
  String? get eTag => delegate.eTag;
  @override
  String get fileExtension => delegate.fileExtension;
}
