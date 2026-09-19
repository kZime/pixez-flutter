import 'dart:async';
import 'dart:io';

import 'package:bot_toast/bot_toast.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:pixez/constants.dart';
import 'package:pixez/custom_icon.dart';
import 'package:pixez/deep_link_plugin.dart';
import 'package:pixez/er/leader.dart';
import 'package:pixez/er/prefer.dart';
import 'package:pixez/fluent/component/painter_avatar.dart';
import 'package:pixez/fluent/component/pixiv_image.dart';
import 'package:pixez/fluent/component/search_box/pixez_search_box.dart';
import 'package:pixez/fluent/navigation_framework.dart';
import 'package:pixez/fluent/page/Init/guide_page.dart';
import 'package:pixez/fluent/page/account/select/account_select_page.dart';
import 'package:pixez/fluent/page/follow/follow_list.dart';
import 'package:pixez/fluent/page/hello/new/illust/new_illust_page.dart';
import 'package:pixez/fluent/page/hello/ranking/rank_page.dart';
import 'package:pixez/fluent/page/hello/recom/recom_spotlight_page.dart';
import 'package:pixez/fluent/page/hello/setting/setting_page.dart';
import 'package:pixez/fluent/page/login/login_page.dart';
import 'package:pixez/fluent/page/preview/preview_page.dart';
import 'package:pixez/fluent/page/user/bookmark/bookmark_page.dart';
import 'package:pixez/fluent/page/user/users_page.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/main.dart';
import 'package:pixez/models/account.dart';

class FluentHelloPage extends StatefulWidget {
  @override
  State<FluentHelloPage> createState() => _FluentHelloPageState();

  const FluentHelloPage({super.key});
}

class _FluentHelloPageState extends State<FluentHelloPage> {
  final BookmarkPageMethodRelay relay = BookmarkPageMethodRelay();
  final FocusNode _searchFocusNode = FocusNode(debugLabel: 'fluent-search');
  bool hideEmail = true;
  StreamSubscription<dynamic>? _saveEvents;
  StreamSubscription<Uri?>? _links;
  final _receivedCodes = <String>{};

  @override
  void initState() {
    Constants.type = 0;
    super.initState();
    fetcher.context = context;
    saveStore.ctx = this.context;
    _saveEvents = saveStore.saveStream.listen(saveStore.listenBehavior);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (Prefer.getInt('language_num') == null) {
        Navigator.of(
          context,
        ).pushReplacement(FluentPageRoute(builder: (context) => GuidePage()));
        return;
      }
      if (Platform.isMacOS) unawaited(_listenForLinks());
    });
  }

  Future<void> _listenForLinks() async {
    // Subscribe before reading the pending launch URL. The native bridge
    // consumes the pending URL once, whichever path receives it first.
    _links = DeepLinkPlugin.uriLinkStream.listen(
      _handleLink,
      onError: (_) => _linkError(),
    );
    try {
      _handleLink(await DeepLinkPlugin.getInitialUri());
    } catch (_) {
      _linkError();
    }
  }

  void _linkError() {
    if (mounted) BotToast.showText(text: I18n.of(context).failed);
  }

  void _handleLink(Uri? uri) {
    if (!mounted || uri == null) return;
    if (uri.scheme == 'pixiv' && uri.host == 'account') {
      final code = uri.queryParameters['code'];
      if (code == null || code.isEmpty || !_receivedCodes.add(code)) return;
    }
    unawaited(Leader.pushWithUri(context, uri));
  }

  @override
  void dispose() {
    _links?.cancel();
    _saveEvents?.cancel();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initIndex = userSetting.fluentWelcomePageIndex;
    return Observer(
      builder: (context) {
        // Pixiv UWP 样式
        bool isTop = userSetting.isTopMode;
        return NavigationFramework(
          initIndex: initIndex,
          defaultTitle: const Text('PixEz'),
          displayMode: isTop ? PaneDisplayMode.top : PaneDisplayMode.auto,
          header: isTop ? null : _buildHeader(accountStore.now != null),
          searchFocusNode: _searchFocusNode,
          autoSuggestBox: PixEzSearchBox(focusNode: _searchFocusNode),
          items: [
            PaneItem(
              icon: const Icon(FluentIcons.home),
              title: Text(I18n.of(context).home),
              body: Observer(
                builder: (context) => accountStore.now != null
                    ? RecomSpolightPage()
                    : PreviewPage(),
              ),
            ),
            PaneItem(
              icon: const Icon(CustomIcons.leaderboard),
              title: Text(I18n.of(context).rank),
              body: RankPage(),
            ),
            PaneItemExpander(
              icon: const Icon(FluentIcons.bookmarks),
              title: Text(I18n.of(context).quick_view),
              items: [
                PaneItem(
                  icon: const Icon(FluentIcons.news),
                  title: Text(I18n.of(context).news),
                  body: Observer(
                    builder: (context) => accountStore.now != null
                        ? const NewIllustPage()
                        : PreviewPage(),
                  ),
                ),
                PaneItem(
                  icon: const Icon(FluentIcons.bookmarks),
                  title: Text(I18n.of(context).bookmark),
                  body: Observer(
                    builder: (context) => accountStore.now != null
                        ? BookmarkPage(
                            relay: relay,
                            isNested: false,
                            id: int.parse(accountStore.now!.userId),
                          )
                        : PreviewPage(),
                  ),
                ),
                PaneItem(
                  icon: const Icon(FluentIcons.follow_user),
                  title: Text(I18n.of(context).followed),
                  body: Observer(
                    builder: (context) => accountStore.now != null
                        ? FollowList(id: int.parse(accountStore.now!.userId))
                        : PreviewPage(),
                  ),
                ),
              ],
            ),
          ],
          footerItems: [
            PaneItem(
              icon: const Icon(FluentIcons.settings),
              title: Text(I18n.of(context).setting),
              body: const SettingPage(),
            ),
            if (isTop)
              PaneItem(
                icon: SizedBox(
                  height: 24,
                  width: 24,
                  child: CircleAvatar(
                    backgroundImage: PixivProvider.url(
                      accountStore.now?.userImage ??
                          'https://s.pximg.net/common/images/no_profile.png',
                      preUrl:
                          'https://s.pximg.net/common/images/no_profile.png',
                    ),
                    radius: 100.0,
                    backgroundColor: FluentTheme.of(context).accentColor,
                  ),
                ),
                title: Text(accountStore.now?.name ?? 'Account'),
                body: Observer(
                  builder: (context) => accountStore.now != null
                      ? UsersPage(id: int.parse(accountStore.now!.userId))
                      : LoginPage(),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(bool isLogin) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      child: isLogin
          ? IconButton(
              icon: Row(
                children: [
                  PainterAvatar(
                    url: accountStore.now!.userImage,
                    id: int.parse(accountStore.now!.userId),
                    size: const Size(64, 64),
                  ),
                  Container(
                    margin: const EdgeInsets.only(left: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          accountStore.now?.name ?? 'Account',
                          style: FluentTheme.of(context).typography.title,
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              hideEmail
                                  ? accountStore.now!.hiddenEmail()
                                  : accountStore.now!.mailAddress,
                              style: FluentTheme.of(context).typography.caption,
                            ),
                            SizedBox(width: 6),
                            HyperlinkButton(
                              onPressed: () =>
                                  setState(() => hideEmail = !hideEmail),
                              child: Text(
                                hideEmail
                                    ? I18n.of(context).reveal
                                    : I18n.of(context).hide,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AccountSelectPage(),
                  useRootNavigator: false,
                );
              },
            )
          : Tooltip(
              message: I18n.of(context).login,
              child: IconButton(
                icon: Row(
                  children: [
                    Image.asset(
                      'assets/images/icon.png',
                      height: 64,
                      width: 64,
                    ),
                    Container(
                      margin: const EdgeInsets.only(left: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'PixEz',
                            style: FluentTheme.of(context).typography.title,
                          ),
                          Text(
                            'Your Favorite Pixiv Client!',
                            style: FluentTheme.of(context).typography.caption,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                onPressed: () {
                  Leader.push(
                    context,
                    LoginPage(),
                    icon: Icon(FluentIcons.signin),
                    title: Text(I18n.of(context).login),
                  );
                },
              ),
            ),
    );
  }
}
