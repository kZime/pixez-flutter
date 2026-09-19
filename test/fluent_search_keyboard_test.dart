import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixez/constants.dart';
import 'package:pixez/fluent/component/search_box/pixez_search_box.dart';
import 'package:pixez/fluent/navigation_framework.dart';
import 'package:pixez/src/generated/i18n/app_localizations.dart';

void main() {
  testWidgets('macOS Fluent Find opens and focuses search in compact mode', (
    tester,
  ) async {
    const channel = MethodChannel('pixez/desktop_menu');
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call.method);
      return null;
    });
    final searchFocusNode = FocusNode(debugLabel: 'test-fluent-search');

    addTearDown(() async {
      searchFocusNode.dispose();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      );
    });

    await tester.pumpWidget(
      FluentApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: AppLocalizations.supportedLocales,
        home: SizedBox(
          width: 760,
          height: 600,
          child: NavigationFramework(
            searchFocusNode: searchFocusNode,
            autoSuggestBox: PixEzSearchBox(focusNode: searchFocusNode),
            items: [
              PaneItem(
                icon: const Icon(FluentIcons.home),
                title: const Text('Home'),
                body: const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(calls, ['enable']);

    final navigationView = tester.state<NavigationViewState>(
      find.byType(NavigationView),
    );
    expect(navigationView.displayMode, PaneDisplayMode.compact);
    expect(navigationView.compactOverlayOpen, isFalse);

    await _sendSearch(tester);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(navigationView.compactOverlayOpen, isTrue);
    expect(find.byType(TextBox), findsOneWidget);
    expect(searchFocusNode.hasFocus, isTrue);

    navigationView.toggleCompactOpenMode();
    searchFocusNode.unfocus();
    await tester.pump();
    expect(navigationView.compactOverlayOpen, isFalse);

    await _sendSearch(tester);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(navigationView.compactOverlayOpen, isTrue);
    expect(searchFocusNode.hasFocus, isTrue);

    final navigator = tester.state<PixEzNavigatorState>(
      find.byType(PixEzNavigator),
    );
    navigator.push<void>(
      icon: const Icon(FluentIcons.picture),
      title: const Text('Detail'),
      builder: (_) => const Text('Detail body'),
    );
    await tester.pumpAndSettle();
    expect(navigator.canGoBack, isTrue);
    await _sendSearch(tester);
    await tester.pumpAndSettle();
    await _sendMenu(tester, 'back');
    await tester.pumpAndSettle();
    expect(
      navigator.canGoBack,
      isTrue,
      reason: 'Do not navigate while editing',
    );
    searchFocusNode.unfocus();
    await tester.pump();
    await _sendMenu(tester, 'back');
    await tester.pumpAndSettle();
    expect(navigator.canGoBack, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(calls, ['enable', 'disable']);
  }, skip: !Constants.macosFluentPreview);
}

Future<void> _sendSearch(WidgetTester tester) async {
  await _sendMenu(tester, 'search');
}

Future<void> _sendMenu(WidgetTester tester, String method) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'pixez/desktop_menu',
    const StandardMethodCodec().encodeMethodCall(MethodCall(method)),
    (_) {},
  );
}
