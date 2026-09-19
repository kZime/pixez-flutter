import 'package:flutter/services.dart';
import 'package:pixez/er/leader.dart';
import 'package:pixez/main.dart';

class SingleInstancePlugin {
  static final platform = const EventChannel("pixez/single_instance");
  static bool _isInitialized = false;
  static void Function(Uri)? _uriHandler;
  static Uri? _pendingUri;

  static set uriHandler(void Function(Uri)? handler) {
    _uriHandler = handler;
    final pending = _pendingUri;
    if (handler != null && pending != null) {
      _pendingUri = null;
      handler(pending);
    }
  }

  // 这个函数是确保同一时间有且只有一个Pixez实例存在的
  //
  // 它需要将其他实例的命令行参数转发给第一个实例
  // 然后结束自己的进程
  static void initialize({Function()? callback}) {
    if (_isInitialized) throw Exception('ReInitialized');
    platform.receiveBroadcastStream().listen((event) {
      final args = event.toString().split('\n');
      argsParser(args, callback: callback);
    });
    _isInitialized = true;
  }

  /// 解析命令行参数字符串
  static void argsParser(List<String> args, {Function()? callback}) async {
    if (args.length < 1) return;

    final uri = Uri.tryParse(args[0]);
    if (uri != null) {
      if (callback != null) callback();
      if (_uriHandler != null) {
        _uriHandler!(uri);
      } else {
        final context = routeObserver.navigator?.context;
        if (context != null) {
          Leader.pushWithUri(context, uri);
        } else {
          _pendingUri = uri;
        }
      }
    }
  }
}
