import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:pixez/network/oauth_client.dart';

class _RecordingAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString('{}', 200);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test(
    'refreshes OAuth timestamp and matching hash for every request',
    () async {
      var now = DateTime(2026, 9, 19, 12, 34, 56);
      final client = OAuthClient(now: () => now);
      final adapter = _RecordingAdapter();
      client.httpClient.httpClientAdapter = adapter;

      await client.postAuthToken('test-user', 'test-password');
      now = now.add(const Duration(seconds: 1));
      await client.postRefreshAuthToken(refreshToken: 'test-refresh-token');

      expect(adapter.requests, hasLength(2));
      final format = DateFormat("yyyy-MM-dd'T'HH:mm:ss'+00:00'");
      final expectedTimes = [
        format.format(DateTime(2026, 9, 19, 12, 34, 56).toUtc()),
        format.format(DateTime(2026, 9, 19, 12, 34, 57).toUtc()),
      ];

      for (var i = 0; i < adapter.requests.length; i++) {
        final request = adapter.requests[i];
        final time = request.headers['X-Client-Time'];
        expect(time, expectedTimes[i]);
        expect(
          request.headers['X-Client-Hash'],
          OAuthClient.getHash('$time${client.hashSalt}'),
        );
      }
      expect(
        adapter.requests[0].headers['X-Client-Time'],
        isNot(adapter.requests[1].headers['X-Client-Time']),
      );
    },
  );
}
