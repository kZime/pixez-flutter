import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pixez/component/pixiv_image.dart';
import 'package:pixez/models/illust.dart';

import 'desktop_strings.dart';

/// Full-screen image surface used by the desktop preview page.
class DesktopImageViewer extends StatefulWidget {
  const DesktopImageViewer({
    super.key,
    required this.illust,
    required this.imageUrls,
    required this.initialIndex,
    required this.isSaving,
    required this.onSave,
    this.onContextMenu,
    required this.onClose,
  });

  final Illusts illust;
  final List<String> imageUrls;
  final int initialIndex;
  final bool isSaving;
  final Future<void> Function(int index) onSave;
  final Future<void> Function(int index, Offset position)? onContextMenu;
  final VoidCallback onClose;

  @override
  State<DesktopImageViewer> createState() => _DesktopImageViewerState();
}

class _DesktopImageViewerState extends State<DesktopImageViewer> {
  late final FocusNode _focusNode;
  late int _index;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'desktop-image-viewer');
    _index = _safeIndex(widget.initialIndex);
  }

  @override
  void didUpdateWidget(covariant DesktopImageViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.illust.id != widget.illust.id ||
        oldWidget.initialIndex != widget.initialIndex ||
        oldWidget.imageUrls.length != widget.imageUrls.length) {
      _index = _safeIndex(widget.initialIndex);
    }
  }

  int _safeIndex(int index) {
    if (widget.imageUrls.isEmpty) return 0;
    if (index < 0) return 0;
    if (index >= widget.imageUrls.length) return widget.imageUrls.length - 1;
    return index;
  }

  void _changePage(int delta) {
    if (widget.imageUrls.isEmpty) return;
    final next = _safeIndex(_index + delta);
    if (next != _index) setState(() => _index = next);
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      widget.onClose();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _changePage(-1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _changePage(1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final strings = DesktopStrings.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final url = widget.imageUrls.isEmpty ? null : widget.imageUrls[_index];
    return Material(
      color: Colors.black.withValues(alpha: .94),
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKey,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (url != null)
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(64, 72, 64, 92),
                  child: GestureDetector(
                    onSecondaryTapUp:
                        widget.isSaving || widget.onContextMenu == null
                        ? null
                        : (details) => widget.onContextMenu!(
                            _index,
                            details.globalPosition,
                          ),
                    child: InteractiveViewer(
                      minScale: 1,
                      maxScale: 6,
                      child: Image(
                        image: PixivProvider.url(url),
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: colorScheme.onSurfaceVariant,
                            size: 56,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              )
            else
              Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  color: colorScheme.onSurfaceVariant,
                  size: 56,
                ),
              ),
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: _viewerButton(
                    icon: Icons.close,
                    tooltip: strings.close,
                    onPressed: widget.onClose,
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(72, 18, 72, 0),
                  child: Text(
                    widget.illust.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: Colors.white),
                  ),
                ),
              ),
            ),
            if (_index > 0)
              _pageButton(
                alignment: Alignment.centerLeft,
                tooltip: strings.previous,
                icon: Icons.chevron_left,
                onPressed: () => _changePage(-1),
              ),
            if (_index < widget.imageUrls.length - 1)
              _pageButton(
                alignment: Alignment.centerRight,
                tooltip: strings.next,
                icon: Icons.chevron_right,
                onPressed: () => _changePage(1),
              ),
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_index + 1} / ${widget.imageUrls.length}',
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(width: 16),
                      FilledButton.icon(
                        onPressed: widget.isSaving || url == null
                            ? null
                            : () => widget.onSave(_index),
                        icon: widget.isSaving
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.download_outlined),
                        label: Text(strings.save),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pageButton({
    required Alignment alignment,
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: _viewerButton(
          icon: icon,
          tooltip: tooltip,
          onPressed: onPressed,
        ),
      ),
    );
  }

  Widget _viewerButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
        style: IconButton.styleFrom(
          backgroundColor: Colors.black54,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }
}
