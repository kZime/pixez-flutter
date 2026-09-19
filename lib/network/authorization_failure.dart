import 'package:dio/dio.dart';

enum AuthorizationStage { exchange, account, save }

/// Keeps only safe diagnostics: never retain the response, request, or tokens.
class AuthorizationFailure implements Exception {
  const AuthorizationFailure(
    this.stage, {
    this.statusCode,
    this.network = false,
  });

  final AuthorizationStage stage;
  final int? statusCode;
  final bool network;

  factory AuthorizationFailure.from(Object error, AuthorizationStage stage) {
    return AuthorizationFailure(
      stage,
      statusCode: error is DioException ? error.response?.statusCode : null,
      network: error is DioException && error.response == null,
    );
  }

  String message({required bool chinese}) {
    switch (stage) {
      case AuthorizationStage.exchange:
        if (network) {
          return chinese
              ? '无法连接登录服务。请检查设置中的 OAuth 网络模式，然后重新登录。'
              : 'Cannot reach the sign-in service. Check the OAuth network mode in Settings, then sign in again.';
        }
        final status = statusCode == null ? '' : ' (HTTP $statusCode)';
        return chinese
            ? '登录服务未能完成授权$status。请从应用重新发起登录，不要使用之前的授权页面。'
            : 'The sign-in service could not complete authorization$status. Start again from the app instead of an earlier browser page.';
      case AuthorizationStage.account:
        return chinese
            ? '登录服务已响应，但账号信息无法解析。请更新应用后重试。'
            : 'The sign-in service responded, but the account could not be read. Update the app and retry.';
      case AuthorizationStage.save:
        return chinese
            ? '账号未能保存到本机。请检查可用磁盘空间，然后重试。'
            : 'The account could not be saved locally. Check available disk space and retry.';
    }
  }

  @override
  String toString() =>
      'AuthorizationFailure(${stage.name}, status: $statusCode, network: $network)';
}
