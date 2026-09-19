import 'package:flutter_test/flutter_test.dart';
import 'package:pixez/constants.dart';

void main() {
  test('Fluent remains the default Windows entry point', () {
    expect(
      Constants.shouldUseFluent(
        isWindows: true,
        macosFluentPreview: false,
        desktopPreview: false,
      ),
      isTrue,
    );
  });

  test('macOS Fluent is opt in and the Material preview keeps precedence', () {
    expect(
      Constants.shouldUseFluent(
        isWindows: false,
        macosFluentPreview: false,
        desktopPreview: false,
      ),
      isFalse,
    );
    expect(
      Constants.shouldUseFluent(
        isWindows: false,
        macosFluentPreview: true,
        desktopPreview: false,
      ),
      isTrue,
    );
    expect(
      Constants.shouldUseFluent(
        isWindows: false,
        macosFluentPreview: true,
        desktopPreview: true,
      ),
      isFalse,
    );
  });
}
