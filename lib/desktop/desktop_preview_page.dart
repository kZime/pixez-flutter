import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pixez/component/pixiv_image.dart';
import 'package:pixez/desktop/desktop_browse_controller.dart';
import 'package:pixez/models/illust.dart';

import 'desktop_image_viewer.dart';
import 'desktop_strings.dart';

/// Opt-in desktop browsing surface. Data, authentication, and saving are
/// deliberately supplied by the caller so this page remains a presentation
/// layer and can be mounted beside the existing mobile routes.
class DesktopPreviewPage extends StatefulWidget {
  const DesktopPreviewPage({
    super.key,
    required this.controller,
    required this.isLoggedIn,
    required this.onLogin,
    required this.onSave,
  });

  final DesktopBrowseController controller;
  final bool isLoggedIn;
  final VoidCallback onLogin;
  final Future<String?> Function(Illusts, int) onSave;

  @override
  State<DesktopPreviewPage> createState() => _DesktopPreviewPageState();
}

enum _DesktopContextAction { details, save }

class _DesktopPreviewPageState extends State<DesktopPreviewPage> {
  static const _desktopMenu = MethodChannel('pixez/desktop_menu');

  static const _sidebarWidth = 188.0;
  static const _detailWidth = 360.0;
  static const _wideBreakpoint = 1040.0;

  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  late final FocusNode _pageFocusNode;

  int _detailPage = 0;
  int? _detailIllustId;
  int? _viewerPage;
  bool _isSaving = false;
  bool _loadMoreRequested = false;
  String? _actionError;
  String? _saveError;
  String? _savedPath;

  DesktopBrowseController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: _controller.query);
    _searchFocusNode = FocusNode(debugLabel: 'desktop-search');
    _pageFocusNode = FocusNode(debugLabel: 'desktop-preview');
    _detailIllustId = _controller.selected?.id;
    _controller.addListener(_onControllerChanged);
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      _desktopMenu.setMethodCallHandler((call) async {
        if (call.method == 'search' && mounted) _focusSearch();
      });
      unawaited(_desktopMenu.invokeMethod<void>('enable'));
    }
  }

  @override
  void didUpdateWidget(covariant DesktopPreviewPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
      _detailIllustId = widget.controller.selected?.id;
      _detailPage = 0;
      _viewerPage = null;
      if (!_searchFocusNode.hasFocus) {
        _searchController.text = widget.controller.query;
      }
    }
  }

  void _onControllerChanged() {
    if (!mounted) return;
    final selectedId = _controller.selected?.id;
    if (selectedId != _detailIllustId) {
      _detailIllustId = selectedId;
      _detailPage = 0;
      _viewerPage = null;
      _saveError = null;
      _savedPath = null;
    }
    if (!_searchFocusNode.hasFocus &&
        _searchController.text != _controller.query) {
      _searchController.text = _controller.query;
      _searchController.selection = TextSelection.collapsed(
        offset: _searchController.text.length,
      );
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final strings = DesktopStrings.of(context);
    return Focus(
      focusNode: _pageFocusNode,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= _wideBreakpoint;
          final selected = _controller.selected;
          return Material(
            color: Theme.of(context).colorScheme.surface,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: _sidebarWidth,
                      child: _buildSidebar(context, strings),
                    ),
                    Expanded(child: _buildCenter(context, strings, isWide)),
                    if (isWide && selected != null)
                      SizedBox(
                        width: _detailWidth,
                        child: _buildDetailPanel(context, strings, selected),
                      ),
                  ],
                ),
                if (_viewerPage != null && selected != null)
                  Positioned.fill(
                    child: DesktopImageViewer(
                      illust: selected,
                      imageUrls: _imageUrls(selected),
                      initialIndex: _viewerPage!,
                      isSaving: _isSaving,
                      onSave: (index) => _save(selected, index),
                      onContextMenu: (index, position) =>
                          _showContextMenu(context, selected, index, position),
                      onClose: _closeViewer,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final isFind =
        event.logicalKey == LogicalKeyboardKey.keyF &&
        (HardwareKeyboard.instance.isMetaPressed ||
            HardwareKeyboard.instance.isControlPressed);
    if (isFind) {
      _focusSearch();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (_searchFocusNode.hasFocus) {
        _searchFocusNode.unfocus();
        _pageFocusNode.requestFocus();
        return KeyEventResult.handled;
      }
      if (_viewerPage != null) {
        _closeViewer();
        return KeyEventResult.handled;
      }
      if (_controller.selected != null) {
        _controller.closeDetail();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  Widget _buildSidebar(BuildContext context, DesktopStrings strings) {
    final scheme = Theme.of(context).colorScheme;
    final recommendationsSelected = _controller.query.trim().isEmpty;
    return Material(
      color: scheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 18, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 8, 22),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_awesome_mosaic_outlined,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 9),
                  Text(
                    'PixEz',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            _sidebarItem(
              context,
              icon: Icons.auto_awesome_outlined,
              label: strings.recommendations,
              selected: recommendationsSelected,
              onTap: _showRecommendations,
            ),
            const SizedBox(height: 4),
            _sidebarItem(
              context,
              icon: Icons.search,
              label: strings.search,
              selected: !recommendationsSelected,
              onTap: _focusSearch,
            ),
            const Spacer(),
            if (!widget.isLoggedIn)
              Card(
                margin: EdgeInsets.zero,
                color: scheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(Icons.lock_outline, color: scheme.primary),
                      const SizedBox(height: 8),
                      Text(
                        strings.loginRequired,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: widget.onLogin,
                        icon: const Icon(Icons.login, size: 18),
                        label: Text(strings.login),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _sidebarItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      selected: selected,
      selectedTileColor: scheme.secondaryContainer,
      selectedColor: scheme.onSecondaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      leading: Icon(icon),
      title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
      visualDensity: VisualDensity.compact,
      onTap: onTap,
    );
  }

  Widget _buildCenter(
    BuildContext context,
    DesktopStrings strings,
    bool isWide,
  ) {
    final selected = _controller.selected;
    return Stack(
      fit: StackFit.expand,
      children: [
        Column(
          children: [
            _buildToolbar(context, strings),
            Expanded(child: _buildResults(context, strings)),
          ],
        ),
        if (!isWide && selected != null)
          Positioned.fill(
            child: _buildNarrowDetail(context, strings, selected),
          ),
      ],
    );
  }

  Widget _buildToolbar(BuildContext context, DesktopStrings strings) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _submitSearch(),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: strings.searchHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                        tooltip: strings.close,
                        icon: const Icon(Icons.clear),
                      ),
                filled: true,
                fillColor: scheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                  borderSide: BorderSide(color: scheme.primary, width: 1.2),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: strings.search,
            child: IconButton.filledTonal(
              onPressed: _submitSearch,
              icon: const Icon(Icons.arrow_forward),
            ),
          ),
          const SizedBox(width: 4),
          Tooltip(
            message: strings.refresh,
            child: IconButton(
              onPressed: _controller.isLoading ? null : _refresh,
              icon: const Icon(Icons.refresh),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(BuildContext context, DesktopStrings strings) {
    final items = _controller.items;
    final hasLoadError = _controller.error == 'load_failed';
    final hasLoadMoreError = _controller.error == 'load_more_failed';
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: CustomScrollView(
        key: const PageStorageKey<String>('desktop-preview-results'),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      _controller.query.trim().isEmpty
                          ? strings.recommendations
                          : '${strings.search}: ${_controller.query}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (items.isNotEmpty)
                    Text(
                      '${items.length}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (_controller.isLoading)
            const SliverToBoxAdapter(
              child: LinearProgressIndicator(minHeight: 2),
            ),
          if (_actionError != null)
            SliverToBoxAdapter(
              child: _errorBanner(context, _actionError!, null),
            ),
          if (hasLoadError && items.isNotEmpty)
            SliverToBoxAdapter(
              child: _errorBanner(context, strings.loadFailed, _refresh),
            ),
          if (_saveError != null || _savedPath != null)
            SliverToBoxAdapter(child: _saveFeedback(context, strings)),
          if ((hasLoadError || hasLoadMoreError) && items.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _errorState(
                context,
                hasLoadMoreError ? strings.loadMoreFailed : strings.loadFailed,
                hasLoadMoreError ? _loadMore : _refresh,
                strings,
              ),
            )
          else if (_controller.isLoading && items.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _loadingState(context, strings.loading),
            )
          else if (items.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _emptyState(context, strings),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 250,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: .74,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildIllustCard(
                    context,
                    strings,
                    items[index],
                    items[index].id == _controller.selected?.id,
                  ),
                  childCount: items.length,
                ),
              ),
            ),
          if (items.isNotEmpty &&
              (hasLoadMoreError || _controller.isLoadingMore))
            SliverToBoxAdapter(
              child: _buildLoadMoreFooter(context, strings, hasLoadMoreError),
            ),
        ],
      ),
    );
  }

  Widget _buildIllustCard(
    BuildContext context,
    DesktopStrings strings,
    Illusts illust,
    bool selected,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final title = illust.title.trim().isEmpty ? strings.title : illust.title;
    return Tooltip(
      message: strings.rightClickToSave,
      waitDuration: const Duration(milliseconds: 600),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        color: selected
            ? scheme.secondaryContainer
            : scheme.surfaceContainerLow,
        child: InkWell(
          onTap: () => _select(illust),
          onSecondaryTapUp: (details) =>
              _showContextMenu(context, illust, 0, details.globalPosition),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _networkImage(_thumbnailUrl(illust), BoxFit.cover),
                    if (illust.pageCount > 1)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: .65),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 4,
                            ),
                            child: Text(
                              '${illust.pageCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(11, 9, 11, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      illust.user.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNarrowDetail(
    BuildContext context,
    DesktopStrings strings,
    Illusts illust,
  ) {
    final width = MediaQuery.sizeOf(context).width;
    final panelWidth = math.min(
      430.0,
      math.max(300.0, width - _sidebarWidth - 12),
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        ModalBarrier(
          color: Colors.black.withValues(alpha: .28),
          dismissible: true,
          onDismiss: _closeDetail,
          semanticsLabel: strings.close,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: panelWidth,
            height: double.infinity,
            child: _buildDetailPanel(context, strings, illust),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailPanel(
    BuildContext context,
    DesktopStrings strings,
    Illusts illust,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final urls = _imageUrls(illust);
    final index = _safeIndex(_detailPage, urls.length);
    final currentUrl = urls.isEmpty ? null : urls[index];
    return Material(
      color: scheme.surface,
      elevation: 8,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      strings.detail,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: strings.close,
                    onPressed: _closeDetail,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
                children: [
                  AspectRatio(
                    aspectRatio: 1.08,
                    child: Card(
                      margin: EdgeInsets.zero,
                      clipBehavior: Clip.antiAlias,
                      color: scheme.surfaceContainerHighest,
                      child: InkWell(
                        onTap: currentUrl == null
                            ? null
                            : () => _openViewer(illust, index),
                        onSecondaryTapUp: currentUrl == null
                            ? null
                            : (details) => _showContextMenu(
                                context,
                                illust,
                                index,
                                details.globalPosition,
                              ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (currentUrl != null)
                              _networkImage(currentUrl, BoxFit.contain)
                            else
                              Icon(
                                Icons.broken_image_outlined,
                                color: scheme.onSurfaceVariant,
                                size: 48,
                              ),
                            Positioned(
                              left: 10,
                              bottom: 10,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: .62),
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 5,
                                  ),
                                  child: Text(
                                    strings.openImage,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (urls.length > 1) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          tooltip: strings.previous,
                          onPressed: index == 0
                              ? null
                              : () => setState(() => _detailPage = index - 1),
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Text(
                          '${strings.pageCounter} ${index + 1} / ${urls.length}',
                        ),
                        IconButton(
                          tooltip: strings.next,
                          onPressed: index == urls.length - 1
                              ? null
                              : () => setState(() => _detailPage = index + 1),
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),
                  Text(
                    illust.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _detailInfoRow(
                    context,
                    Icons.person_outline,
                    strings.author,
                    illust.user.name,
                  ),
                  const SizedBox(height: 7),
                  _detailInfoRow(
                    context,
                    Icons.photo_size_select_large_outlined,
                    strings.dimensions,
                    '${illust.width} × ${illust.height}',
                  ),
                  const SizedBox(height: 7),
                  _detailInfoRow(
                    context,
                    Icons.layers_outlined,
                    strings.pages,
                    '${illust.pageCount}',
                  ),
                  const SizedBox(height: 7),
                  _detailInfoRow(
                    context,
                    Icons.tag,
                    strings.id,
                    '${illust.id}',
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isSaving || currentUrl == null
                          ? null
                          : () => _save(illust, index),
                      icon: _isSaving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download_outlined),
                      label: Text(strings.save),
                    ),
                  ),
                  if (_saveError != null) ...[
                    const SizedBox(height: 10),
                    Text(_saveError!, style: TextStyle(color: scheme.error)),
                  ],
                  if (_savedPath != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      '${strings.savedTo}: $_savedPath',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: scheme.primary),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: scheme.onSurfaceVariant),
        const SizedBox(width: 9),
        Text(
          '$label: ',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        Expanded(
          child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  Widget _networkImage(String url, BoxFit fit) {
    if (url.isEmpty) {
      return const ColoredBox(
        color: Colors.transparent,
        child: Center(child: Icon(Icons.broken_image_outlined)),
      );
    }
    return Image(
      image: PixivProvider.url(url),
      fit: fit,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) return child;
        return Stack(
          fit: StackFit.expand,
          children: [
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            child,
          ],
        );
      },
      errorBuilder: (context, error, stackTrace) =>
          const Center(child: Icon(Icons.broken_image_outlined, size: 42)),
    );
  }

  Widget _loadingState(BuildContext context, String label) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 14),
          Text(label),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context, DesktopStrings strings) {
    final label = _controller.query.trim().isEmpty
        ? strings.noRecommendations
        : strings.noResults;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text(label),
          if (_controller.hasMore) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _controller.isLoadingMore ? null : _loadMore,
              icon: _controller.isLoadingMore
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.expand_more),
              label: Text(strings.loadingMore),
            ),
          ],
        ],
      ),
    );
  }

  Widget _errorState(
    BuildContext context,
    String message,
    VoidCallback onRetry,
    DesktopStrings strings,
  ) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: 46,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 12),
          Text(message),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(strings.retry),
          ),
        ],
      ),
    );
  }

  Widget _errorBanner(
    BuildContext context,
    String message,
    VoidCallback? onRetry,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: scheme.onErrorContainer, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                child: Text(DesktopStrings.of(context).retry),
              ),
          ],
        ),
      ),
    );
  }

  Widget _saveFeedback(BuildContext context, DesktopStrings strings) {
    final scheme = Theme.of(context).colorScheme;
    final isError = _saveError != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: isError ? scheme.errorContainer : scheme.primaryContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              size: 18,
              color: isError
                  ? scheme.onErrorContainer
                  : scheme.onPrimaryContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isError ? _saveError! : '${strings.savedTo}: $_savedPath',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isError
                      ? scheme.onErrorContainer
                      : scheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadMoreFooter(
    BuildContext context,
    DesktopStrings strings,
    bool failed,
  ) {
    if (!failed) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 9),
              Text(strings.loadingMore),
            ],
          ),
        ),
      );
    }
    return _errorBanner(context, strings.loadMoreFailed, _loadMore);
  }

  bool _onScroll(ScrollNotification notification) {
    if (_controller.error == null &&
        notification.metrics.extentAfter < 520 &&
        _controller.hasMore &&
        !_controller.isLoading &&
        !_controller.isLoadingMore &&
        !_loadMoreRequested) {
      _loadMore();
    }
    return false;
  }

  Future<void> _loadMore() async {
    if (_loadMoreRequested) return;
    _loadMoreRequested = true;
    try {
      await _controller.loadMore();
    } catch (_) {
      if (mounted) {
        setState(
          () => _actionError = DesktopStrings.of(context).loadMoreFailed,
        );
      }
    } finally {
      _loadMoreRequested = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _refresh() async {
    _clearFeedback();
    try {
      await _controller.refresh();
    } catch (_) {
      if (mounted) {
        setState(() => _actionError = DesktopStrings.of(context).loadFailed);
      }
    }
  }

  Future<void> _submitSearch() async {
    final query = _searchController.text.trim();
    _pageFocusNode.requestFocus();
    _clearFeedback();
    try {
      if (query.isEmpty) {
        await _controller.showRecommendations();
      } else {
        await _controller.search(query);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _actionError = DesktopStrings.of(context).loadFailed);
      }
    }
  }

  Future<void> _showRecommendations() async {
    _searchController.clear();
    _pageFocusNode.requestFocus();
    _clearFeedback();
    try {
      await _controller.showRecommendations();
    } catch (_) {
      if (mounted) {
        setState(() => _actionError = DesktopStrings.of(context).loadFailed);
      }
    }
  }

  void _focusSearch() {
    if (_viewerPage != null) setState(() => _viewerPage = null);
    _searchFocusNode.requestFocus();
    _searchController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _searchController.text.length,
    );
  }

  void _select(Illusts illust) {
    _pageFocusNode.requestFocus();
    _detailPage = 0;
    _controller.select(illust);
  }

  void _closeDetail() => _controller.closeDetail();

  void _openViewer(Illusts illust, int index) {
    final urls = _imageUrls(illust);
    if (urls.isEmpty) return;
    setState(() => _viewerPage = _safeIndex(index, urls.length));
  }

  void _closeViewer() {
    if (mounted) {
      setState(() => _viewerPage = null);
      _pageFocusNode.requestFocus();
    }
  }

  Future<void> _showContextMenu(
    BuildContext context,
    Illusts illust,
    int index,
    Offset globalPosition,
  ) async {
    final renderObject = Overlay.of(context).context.findRenderObject();
    if (renderObject is! RenderBox) return;
    final local = renderObject.globalToLocal(globalPosition);
    final action = await showMenu<_DesktopContextAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        local.dx,
        local.dy,
        renderObject.size.width - local.dx,
        renderObject.size.height - local.dy,
      ),
      items: [
        PopupMenuItem(
          value: _DesktopContextAction.details,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.open_in_new, size: 19),
              const SizedBox(width: 10),
              Text(DesktopStrings.of(context).viewDetails),
            ],
          ),
        ),
        PopupMenuItem(
          value: _DesktopContextAction.save,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.download_outlined, size: 19),
              const SizedBox(width: 10),
              Text(DesktopStrings.of(context).save),
            ],
          ),
        ),
      ],
    );
    if (!mounted) return;
    _pageFocusNode.requestFocus();
    if (action == null) return;
    if (action == _DesktopContextAction.details) {
      _select(illust);
    } else {
      _save(illust, index);
    }
  }

  Future<void> _save(Illusts illust, int index) async {
    if (_isSaving) return;
    if (!widget.isLoggedIn) {
      widget.onLogin();
      return;
    }
    final urls = _imageUrls(illust);
    if (urls.isEmpty) return;
    final safeIndex = _safeIndex(index, urls.length);
    _clearFeedback();
    setState(() => _isSaving = true);
    try {
      final path = await widget.onSave(illust, safeIndex);
      if (mounted && path != null) setState(() => _savedPath = path);
    } catch (error) {
      if (mounted) {
        setState(() => _saveError = _friendlySaveError(error));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _friendlySaveError(Object error) =>
      DesktopStrings.of(context).saveFailed;

  void _clearFeedback() {
    if (!mounted) return;
    setState(() {
      _actionError = null;
      _saveError = null;
      _savedPath = null;
    });
  }

  int _safeIndex(int index, int length) {
    if (length <= 0) return 0;
    return index < 0 ? 0 : (index >= length ? length - 1 : index);
  }

  String _thumbnailUrl(Illusts illust) {
    if (illust.imageUrls.squareMedium.isNotEmpty) {
      return illust.imageUrls.squareMedium;
    }
    if (illust.imageUrls.medium.isNotEmpty) return illust.imageUrls.medium;
    return illust.imageUrls.large;
  }

  List<String> _imageUrls(Illusts illust) {
    final pages = illust.metaPages
        .map((page) {
          final urls = page.imageUrls;
          if (urls == null) return '';
          if (urls.original.isNotEmpty) return urls.original;
          if (urls.large.isNotEmpty) return urls.large;
          return urls.medium;
        })
        .where((url) => url.isNotEmpty)
        .toList();
    if (pages.isNotEmpty) return pages;
    final single = illust.metaSinglePage?.originalImageUrl;
    if (single != null && single.isNotEmpty) return [single];
    if (illust.imageUrls.large.isNotEmpty) return [illust.imageUrls.large];
    if (illust.imageUrls.medium.isNotEmpty) return [illust.imageUrls.medium];
    return const [];
  }

  @override
  void dispose() {
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      _desktopMenu.setMethodCallHandler(null);
      unawaited(_desktopMenu.invokeMethod<void>('disable'));
    }
    _controller.removeListener(_onControllerChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _pageFocusNode.dispose();
    super.dispose();
  }
}
