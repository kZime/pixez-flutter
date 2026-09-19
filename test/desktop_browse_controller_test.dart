import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pixez/desktop/desktop_browse_controller.dart';
import 'package:pixez/models/illust.dart';
import 'package:pixez/models/recommend.dart';

class _Illustration extends Fake implements Illusts {
  _Illustration(this.id);
  @override
  final int id;
}

Recommend _page(List<int> ids, {String? next}) =>
    Recommend(illusts: ids.map(_Illustration.new).toList(), nextUrl: next);

void main() {
  test('an older search cannot overwrite the most recent query', () async {
    final first = Completer<Recommend>();
    final second = Completer<Recommend>();
    final controller = DesktopBrowseController(
      loadRecommendations: () async => _page([]),
      searchIllustrations: (query) =>
          query == 'first' ? first.future : second.future,
      loadNextPage: (_) async => _page([]),
    );
    addTearDown(controller.dispose);
    final firstRequest = controller.search('first');
    final secondRequest = controller.search(' second ');
    second.complete(_page([2]));
    await secondRequest;
    first.complete(_page([1]));
    await firstRequest;
    expect(controller.query, 'second');
    expect(controller.items.map((item) => item.id), [2]);
    expect(controller.isLoading, isFalse);
  });

  test('pagination coalesces requests and removes overlapping items', () async {
    final more = Completer<Recommend>();
    var requests = 0;
    final controller = DesktopBrowseController(
      loadRecommendations: () async => _page([1, 2], next: 'page2'),
      searchIllustrations: (_) async => _page([]),
      loadNextPage: (_) {
        requests++;
        return more.future;
      },
    );
    addTearDown(controller.dispose);
    await controller.refresh();
    final pending = controller.loadMore();
    await controller.loadMore();
    expect(requests, 1);
    more.complete(_page([2, 3], next: 'page2'));
    await pending;
    expect(controller.items.map((item) => item.id), [1, 2, 3]);
    expect(controller.hasMore, isFalse);
  });

  test('changing the query discards old pagination results', () async {
    final more = Completer<Recommend>();
    final controller = DesktopBrowseController(
      loadRecommendations: () async => _page([1], next: 'page2'),
      searchIllustrations: (_) async => _page([9]),
      loadNextPage: (_) => more.future,
    );
    addTearDown(controller.dispose);
    await controller.refresh();
    final oldPagination = controller.loadMore();
    await controller.search('new');
    more.complete(_page([2], next: 'page3'));
    await oldPagination;
    expect(controller.items.single.id, 9);
    expect(controller.hasMore, isFalse);
  });

  test(
    'failed pagination can be retried without losing existing items',
    () async {
      var attempts = 0;
      final controller = DesktopBrowseController(
        loadRecommendations: () async => _page([1], next: 'page2'),
        searchIllustrations: (_) async => _page([]),
        loadNextPage: (_) async {
          if (++attempts == 1) throw StateError('network failure');
          return _page([2]);
        },
      );
      addTearDown(controller.dispose);
      await controller.refresh();
      await controller.loadMore();
      expect(controller.error, 'load_more_failed');
      expect(controller.items.single.id, 1);
      expect(controller.hasMore, isTrue);
      await controller.loadMore();
      expect(controller.error, isNull);
      expect(controller.items.map((item) => item.id), [1, 2]);
    },
  );

  test(
    'closing details preserves loaded items and the pagination cursor',
    () async {
      final controller = DesktopBrowseController(
        loadRecommendations: () async => _page([1], next: 'page2'),
        searchIllustrations: (_) async => _page([]),
        loadNextPage: (_) async => _page([]),
      );
      addTearDown(controller.dispose);
      await controller.refresh();
      controller.select(controller.items.single);
      controller.closeDetail();
      expect(controller.selected, isNull);
      expect(controller.items.single.id, 1);
      expect(controller.hasMore, isTrue);
    },
  );

  test('a completed request cannot notify a disposed surface', () async {
    final response = Completer<Recommend>();
    final controller = DesktopBrowseController(
      loadRecommendations: () => response.future,
      searchIllustrations: (_) async => _page([]),
      loadNextPage: (_) async => _page([]),
    );
    final pending = controller.refresh();
    controller.dispose();
    response.complete(_page([1]));
    await expectLater(pending, completes);
  });
}
