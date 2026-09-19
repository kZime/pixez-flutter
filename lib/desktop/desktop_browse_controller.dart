import 'package:flutter/foundation.dart';
import 'package:pixez/models/illust.dart';
import 'package:pixez/models/recommend.dart';

/// State for the desktop browse surface. Network clients remain shared.
class DesktopBrowseController extends ChangeNotifier {
  DesktopBrowseController({
    required this.loadRecommendations,
    required this.searchIllustrations,
    required this.loadNextPage,
  });

  final Future<Recommend> Function() loadRecommendations;
  final Future<Recommend> Function(String query) searchIllustrations;
  final Future<Recommend> Function(String url) loadNextPage;

  List<Illusts> items = [];
  Illusts? selected;
  String query = '';
  bool isLoading = false;
  bool isLoadingMore = false;
  String? error;
  String? _nextUrl;
  int _generation = 0;
  bool _disposed = false;

  bool get hasMore => _nextUrl != null;

  Future<void> showRecommendations() => search('');

  Future<void> search(String value) async {
    query = value.trim();
    selected = null;
    items = [];
    _nextUrl = null;
    await refresh();
  }

  Future<void> refresh() async {
    final generation = ++_generation;
    final requestedQuery = query;
    isLoading = true;
    isLoadingMore = false;
    error = null;
    _nextUrl = null;
    notifyListeners();
    try {
      final page = requestedQuery.isEmpty
          ? await loadRecommendations()
          : await searchIllustrations(requestedQuery);
      if (!_isCurrent(generation)) return;
      items = _unique(page.illusts);
      _nextUrl = _cursor(page.nextUrl);
      if (selected != null && !items.any((item) => item.id == selected!.id)) {
        selected = null;
      }
    } catch (_) {
      if (!_isCurrent(generation)) return;
      // The UI supplies localized copy. Never surface raw authenticated requests.
      error = 'load_failed';
    } finally {
      if (_isCurrent(generation)) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMore() async {
    final cursor = _nextUrl;
    if (isLoading || isLoadingMore || cursor == null || _disposed) return;
    final generation = _generation;
    isLoadingMore = true;
    error = null;
    notifyListeners();
    try {
      final page = await loadNextPage(cursor);
      if (!_isCurrent(generation)) return;
      items = _unique([...items, ...page.illusts]);
      final next = _cursor(page.nextUrl);
      // A repeated cursor must not cause an endless request loop.
      _nextUrl = next == cursor ? null : next;
    } catch (_) {
      if (!_isCurrent(generation)) return;
      error = 'load_more_failed';
    } finally {
      if (_isCurrent(generation)) {
        isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  void select(Illusts item) {
    selected = item;
    notifyListeners();
  }

  void closeDetail() {
    selected = null;
    notifyListeners();
  }

  static List<Illusts> _unique(List<Illusts> source) {
    final ids = <int>{};
    return source.where((item) => ids.add(item.id)).toList();
  }

  static String? _cursor(String? value) =>
      value == null || value.isEmpty ? null : value;

  bool _isCurrent(int generation) => !_disposed && generation == _generation;

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
