import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixez/network/authorization_failure.dart';

void main() {
  test('HTTP rejection keeps status but never exposes OAuth material', () {
    final request = RequestOptions(
      path: '/auth/token?code=private-code',
      data: {'code_verifier': 'private-verifier'},
      headers: {'Authorization': 'private-header'},
    );
    final failure = AuthorizationFailure.from(
      DioException(
        requestOptions: request,
        response: Response(
          requestOptions: request,
          statusCode: 400,
          data: {'access_token': 'private-token'},
        ),
        message: 'private-message',
        error: 'private-error',
      ),
      AuthorizationStage.exchange,
    );
    expect(failure.network, isFalse);
    expect(failure.statusCode, 400);
    for (final chinese in [true, false]) {
      expect(failure.message(chinese: chinese), contains('HTTP 400'));
      expect(failure.message(chinese: chinese), isNot(contains('private-')));
    }
    expect(failure.toString(), isNot(contains('private-')));
  });

  test('transport failure directs the user to OAuth network settings', () {
    final failure = AuthorizationFailure.from(
      DioException(
        requestOptions: RequestOptions(path: '/auth/token'),
        type: DioExceptionType.connectionTimeout,
      ),
      AuthorizationStage.exchange,
    );
    expect(failure.network, isTrue);
    expect(failure.message(chinese: true), contains('OAuth'));
    expect(failure.message(chinese: false), contains('OAuth'));
  });

  test('response parsing and persistence failures remain distinguishable', () {
    final parse = AuthorizationFailure.from(
      const FormatException('private-response'),
      AuthorizationStage.account,
    );
    final save = AuthorizationFailure.from(
      StateError('private-database'),
      AuthorizationStage.save,
    );
    expect(parse.message(chinese: true), contains('无法解析'));
    expect(save.message(chinese: true), contains('未能保存'));
    expect(parse.toString(), isNot(contains('private-')));
    expect(save.toString(), isNot(contains('private-')));
  });
}
