import 'package:flutter/widgets.dart';
import 'package:pixez/src/generated/i18n/app_localizations.dart';

/// Small, desktop-only additions until these labels can move into the ARB
/// files. Existing app labels are reused whenever they already exist.
class DesktopStrings {
  DesktopStrings(this.locale, this.localizations);

  final Locale locale;
  final AppLocalizations? localizations;

  factory DesktopStrings.of(BuildContext context) => DesktopStrings(
    Localizations.localeOf(context),
    AppLocalizations.of(context),
  );

  bool get isChinese => locale.languageCode == 'zh';

  String get recommendations =>
      localizations?.recommend_for_you ??
      (isChinese ? '为你推荐' : 'Recommendations');
  String get search => localizations?.search ?? (isChinese ? '搜索' : 'Search');
  String get searchHint => isChinese ? '搜索作品标签' : 'Search work tags';
  String get refresh =>
      localizations?.refresh ?? (isChinese ? '刷新' : 'Refresh');
  String get login =>
      localizations?.go_to_login ?? (isChinese ? '登录' : 'Sign in');
  String get loginRequired =>
      localizations?.login_message ??
      (isChinese ? '登录后可保存图片' : 'Sign in to save images');
  String get detail => localizations?.detail ?? (isChinese ? '详情' : 'Details');
  String get save => isChinese ? '另存为…' : 'Save as…';
  String get saved => localizations?.saved ?? (isChinese ? '已保存' : 'Saved');
  String get title => localizations?.title ?? (isChinese ? '标题' : 'Title');
  String get author =>
      localizations?.painter_name ?? (isChinese ? '作者' : 'Artist');
  String get dimensions => isChinese ? '尺寸' : 'Dimensions';
  String get pages => isChinese ? '页数' : 'Pages';
  String get previous => isChinese ? '上一张' : 'Previous';
  String get next => localizations?.next ?? (isChinese ? '下一张' : 'Next');
  String get close => isChinese ? '关闭' : 'Close';
  String get viewDetails => isChinese ? '查看详情' : 'View details';
  String get openImage => isChinese ? '查看大图' : 'Open full image';
  String get loading => isChinese ? '加载中…' : 'Loading…';
  String get loadMore => isChinese ? '加载更多' : 'Load more';
  String get loadingMore => isChinese ? '加载更多…' : 'Loading more…';
  String get noResults =>
      localizations?.no_result ?? (isChinese ? '暂无结果' : 'No results');
  String get noRecommendations =>
      isChinese ? '暂时没有推荐内容' : 'There are no recommendations yet';
  String get loadFailed =>
      isChinese ? '加载失败，请重试' : 'Could not load images. Try again.';
  String get loadMoreFailed =>
      isChinese ? '加载更多失败，请重试' : 'Could not load more images. Try again.';
  String get saveFailed => isChinese ? '保存失败' : 'Could not save the image';
  String get savedTo => isChinese ? '已保存到' : 'Saved to';
  String get pageCounter => isChinese ? '第' : 'Page';
  String get id => isChinese ? '编号' : 'ID';
  String get searchShortcut => isChinese ? '搜索（⌘/Ctrl+F）' : 'Search (⌘/Ctrl+F)';
  String get rightClickToSave => isChinese ? '右键保存' : 'Right-click to save';
  String get retry => localizations?.retry ?? (isChinese ? '重试' : 'Retry');
}
