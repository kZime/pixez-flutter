import 'package:flutter_test/flutter_test.dart';
import 'package:pixez/single_instance_plugin.dart';

void main() {
  tearDown(() => SingleInstancePlugin.uriHandler = null);

  test('a startup URI waits for the desktop handler and is delivered once', () {
    SingleInstancePlugin.uriHandler = null;
    SingleInstancePlugin.argsParser(['pixiv://illusts/123']);
    final received = <Uri>[];
    SingleInstancePlugin.uriHandler = received.add;
    expect(received.map((uri) => uri.path), ['/123']);
    SingleInstancePlugin.uriHandler = received.add;
    expect(received.length, 1);
  });

  test('subsequent instance URIs use the active handler', () {
    final received = <Uri>[];
    SingleInstancePlugin.uriHandler = received.add;
    SingleInstancePlugin.argsParser([]);
    SingleInstancePlugin.argsParser(['pixiv://illusts/456']);
    expect(received.map((uri) => uri.path), ['/456']);
  });
}
