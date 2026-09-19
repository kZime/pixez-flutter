import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:pixez/constants.dart';
import 'package:pixez/deep_link_plugin.dart';
import 'package:pixez/desktop/desktop_browse_controller.dart';
import 'package:pixez/desktop/desktop_file_save.dart';
import 'package:pixez/desktop/desktop_preview_page.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/exts.dart';
import 'package:pixez/main.dart';
import 'package:pixez/models/recommend.dart';
import 'package:pixez/network/api_client.dart';
import 'package:pixez/network/auth_session.dart';
import 'package:pixez/network/oauth_client.dart';
import 'package:pixez/single_instance_plugin.dart';
import 'package:pixez/src/generated/i18n/app_localizations.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:window_manager/window_manager.dart';

Future<void> initializeDesktopPreviewWindow() async {
  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow(
    const WindowOptions(
      title: 'PixEz',
      size: Size(1180, 800),
      minimumSize: Size(760, 540),
      center: true,
      titleBarStyle: TitleBarStyle.normal,
    ),
    () async {
      await windowManager.show();
      await windowManager.focus();
    },
  );
}

class DesktopPreviewBootstrap extends StatelessWidget {
  const DesktopPreviewBootstrap({super.key, required this.arguments});
  final List<String> arguments;

  @override
  Widget build(BuildContext context) => Observer(
    builder: (_) {
      if (userSetting.themeInitState != 1) {
        return const MaterialApp(
          home: Scaffold(body: Center(child: CircularProgressIndicator())),
        );
      }
      return _DesktopApp(arguments: arguments);
    },
  );
}

class _DesktopApp extends StatefulWidget {
  const _DesktopApp({required this.arguments});
  final List<String> arguments;

  @override
  State<_DesktopApp> createState() => _DesktopAppState();
}

class _DesktopAppState extends State<_DesktopApp> {
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  final _save = DesktopFileSave.platform();
  late final DesktopBrowseController _browse;
  StreamSubscription<Uri?>? _links;
  final _receivedCodes = <String>{};
  bool _signingIn = false;

  bool get _isChinese => userSetting.locale.languageCode == 'zh';

  @override
  void initState() {
    super.initState();
    _browse = DesktopBrowseController(
      loadRecommendations: () async =>
          _decodePage((await apiClient.getRecommend()).data),
      searchIllustrations: (query) async => _decodePage(
        (await apiClient.getSearchIllust(
          query,
          search_target: 'partial_match_for_tags',
          sort: 'date_desc',
        )).data,
      ),
      loadNextPage: (url) async =>
          _decodePage((await apiClient.getNext(url)).data),
    );
    if (Platform.isMacOS) {
      _links = DeepLinkPlugin.uriLinkStream.listen(
        _handleUri,
        onError: (_) => _message(
          _isChinese
              ? '无法接收登录回调，请重试。'
              : 'Unable to receive the sign-in callback. Please retry.',
        ),
      );
      unawaited(_readInitialLink());
    } else if (Platform.isWindows) {
      SingleInstancePlugin.uriHandler = _handleUri;
      SingleInstancePlugin.argsParser(widget.arguments);
    }
    unawaited(_loadAccount());
  }

  Recommend _decodePage(Map<String, dynamic> data) {
    final page = Recommend.fromJson(data);
    page.illusts = page.illusts
        .where((item) => !item.hateByUser(includeR18Setting: true))
        .toList();
    return page;
  }

  Future<void> _loadAccount() async {
    await accountStore.fetch();
    if (mounted && accountStore.now != null) await _browse.refresh();
  }

  Future<void> _readInitialLink() async {
    try {
      _handleUri(await DeepLinkPlugin.getInitialUri());
    } catch (_) {
      // No pending link is a normal startup state.
    }
  }

  void _message(String value) {
    if (!mounted) return;
    _messenger.currentState?.showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> _login() async {
    if (_signingIn) return;
    _signingIn = true;
    try {
      final url = await OAuthClient.generateWebviewUrl();
      if (!await launchUrlString(url, mode: LaunchMode.externalApplication)) {
        throw StateError('Unable to open browser');
      }
    } catch (_) {
      _message(
        _isChinese ? '无法打开登录页面，请重试。' : 'Unable to open sign-in. Please retry.',
      );
    } finally {
      _signingIn = false;
    }
  }

  Future<void> _handleUri(Uri? uri) async {
    if (!mounted ||
        uri == null ||
        uri.scheme != 'pixiv' ||
        uri.host != 'account')
      return;
    final code = uri.queryParameters['code'];
    if (code == null || code.isEmpty || !_receivedCodes.add(code)) return;
    if (Constants.code_verifier == null) {
      _message(
        _isChinese
            ? '本次登录已失效，请重新点击登录。'
            : 'This sign-in has expired. Please start again.',
      );
      return;
    }
    try {
      await completeAuthorizationCode(code);
      if (!mounted) return;
      await _browse.showRecommendations();
      _message(_isChinese ? '登录成功' : 'Signed in');
    } catch (_) {
      _message(
        _isChinese
            ? '登录未完成，请重新发起授权。'
            : 'Sign-in failed. Please authorize again.',
      );
    }
  }

  @override
  void dispose() {
    _links?.cancel();
    if (Platform.isWindows) SingleInstancePlugin.uriHandler = null;
    _browse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Observer(
    builder: (_) {
      final light = ColorScheme.fromSeed(seedColor: const Color(0xff416b68));
      final dark = ColorScheme.fromSeed(
        seedColor: const Color(0xff416b68),
        brightness: Brightness.dark,
      );
      return MaterialApp(
        title: 'PixEz',
        debugShowCheckedModeBanner: false,
        scaffoldMessengerKey: _messenger,
        locale: userSetting.locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        themeMode: ThemeMode.values[userSetting.themeMode.index],
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: light,
          visualDensity: VisualDensity.compact,
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: dark,
          visualDensity: VisualDensity.compact,
        ),
        builder: (context, child) {
          I18n.context = context;
          return child!;
        },
        home: Scaffold(
          body: DesktopPreviewPage(
            controller: _browse,
            isLoggedIn: accountStore.now != null,
            onLogin: _login,
            onSave: _save.save,
          ),
        ),
      );
    },
  );
}
