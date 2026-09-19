import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixez/fluent/navigation_framework.dart';

void main() {
  testWidgets('fallback navigation follows a rebuilt navigator', (
    tester,
  ) async {
    final harnessKey = GlobalKey<_NavigatorHarnessState>();

    await tester.pumpWidget(_NavigatorHarness(key: harnessKey));
    await tester.pumpAndSettle();
    expect(
      harnessKey.currentState!.fallbackState,
      same(harnessKey.currentState!.firstKey.currentState),
    );

    harnessKey.currentState!.showSecondNavigator();
    await tester.pumpAndSettle();
    expect(
      harnessKey.currentState!.fallbackState,
      same(harnessKey.currentState!.secondKey.currentState),
    );
  });
}

class _NavigatorHarness extends StatefulWidget {
  const _NavigatorHarness({super.key});

  @override
  State<_NavigatorHarness> createState() => _NavigatorHarnessState();
}

class _NavigatorHarnessState extends State<_NavigatorHarness> {
  final firstKey = GlobalKey<PixEzNavigatorState>();
  final secondKey = GlobalKey<PixEzNavigatorState>();
  PixEzNavigatorState? fallbackState;
  bool showSecond = false;

  void showSecondNavigator() => setState(() => showSecond = true);

  @override
  Widget build(BuildContext context) {
    return FluentApp(
      home: Column(
        children: [
          Expanded(
            child: PixEzNavigator(
              key: showSecond ? secondKey : firstKey,
              initIndex: 0,
              temporaryIndex: -1,
              onUpdate: () {},
              onGenerateRoute: (_) =>
                  FluentPageRoute(builder: (_) => const SizedBox.shrink()),
            ),
          ),
          _FallbackProbe(onState: (state) => fallbackState = state),
        ],
      ),
    );
  }
}

class _FallbackProbe extends StatelessWidget {
  const _FallbackProbe({required this.onState});

  final ValueChanged<PixEzNavigatorState> onState;

  @override
  Widget build(BuildContext context) {
    final state = PixEzNavigator.of(context);
    onState(state);
    return const SizedBox.shrink();
  }
}
