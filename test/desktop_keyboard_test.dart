import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixez/desktop/desktop_browse_controller.dart';
import 'package:pixez/desktop/desktop_preview_page.dart';
import 'package:pixez/models/recommend.dart';

void main() {
  testWidgets('desktop find shortcut focuses search and Enter submits it', (
    tester,
  ) async {
    String? submitted;
    final controller = DesktopBrowseController(
      loadRecommendations: () async => Recommend(illusts: []),
      searchIllustrations: (query) async {
        submitted = query;
        return Recommend(illusts: []);
      },
      loadNextPage: (_) async => Recommend(illusts: []),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DesktopPreviewPage(
            controller: controller,
            isLoggedIn: true,
            onLogin: () {},
            onSave: (_, _) async => null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.focusNode!.hasFocus, isTrue);
    await tester.enterText(find.byType(TextField), '  landscape  ');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(submitted, 'landscape');
    expect(field.focusNode!.hasFocus, isFalse);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(field.focusNode!.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(field.focusNode!.hasFocus, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('macOS native Find menu focuses the desktop search field', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    const channel = MethodChannel('pixez/desktop_menu');
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call.method);
      return null;
    });
    final controller = DesktopBrowseController(
      loadRecommendations: () async => Recommend(illusts: []),
      searchIllustrations: (_) async => Recommend(illusts: []),
      loadNextPage: (_) async => Recommend(illusts: []),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DesktopPreviewPage(
            controller: controller,
            isLoggedIn: true,
            onLogin: () {},
            onSave: (_, _) async => null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(calls, ['enable']);
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'pixez/desktop_menu',
      const StandardMethodCodec().encodeMethodCall(const MethodCall('search')),
      (_) {},
    );
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
      isTrue,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    expect(calls, ['enable', 'disable']);
    controller.dispose();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      null,
    );
    debugDefaultTargetPlatformOverride = null;
  });
}
