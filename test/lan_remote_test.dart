import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lazer_nextgen/state/app_state.dart';
import 'package:lazer_nextgen/state/ui_preferences.dart';
import 'package:lazer_nextgen/tv/lan_remote.dart';
import 'package:lazer_nextgen/tv/tv_mode.dart';

class _LoopbackHttp extends HttpOverrides {}

Future<void> _ready(LanRemoteController remote) async {
  if (remote.urls.isNotEmpty) return;
  final completer = Completer<void>();
  void changed() {
    if ((remote.urls.isNotEmpty || remote.error != null) &&
        !completer.isCompleted) {
      completer.complete();
    }
  }

  remote.addListener(changed);
  try {
    await completer.future.timeout(const Duration(seconds: 5));
  } finally {
    remote.removeListener(changed);
  }
  expect(remote.error, isNull);
}

/// Shared setup for the security-surface regressions below. Probes use an
/// unknown `action`, so `LanRemoteController.command` falls through its switch
/// without changing playback, volume or the focused input field.
class _RemoteFixture {
  _RemoteFixture(this.state, this.remote, this.client, this.uri);

  final AppState state;
  final LanRemoteController remote;
  final HttpClient client;
  final Uri uri;

  void close() {
    client.close(force: true);
    remote.dispose();
    state.dispose();
  }
}

Future<_RemoteFixture> _startLoopbackRemote() async {
  HttpOverrides.global = null;
  final state = AppState()..surface = AppSurface.tv;
  final remote = LanRemoteController(
    state,
    bindAddress: InternetAddress.loopbackIPv4,
  );
  final client = HttpClient();
  await remote.initialize();
  await remote.setEnabled(true);
  await _ready(remote);
  return _RemoteFixture(state, remote, client, Uri.parse(remote.urls.single));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'remote is opt-in, authenticates commands and stops outside TV',
    () async {
      // This integration test talks only to its own loopback HTTP server.
      HttpOverrides.global = null;
      final state = AppState()..surface = AppSurface.tv;
      final remote = LanRemoteController(
        state,
        bindAddress: InternetAddress.loopbackIPv4,
      );
      final client = HttpClient();
      addTearDown(() {
        client.close(force: true);
        remote.dispose();
        state.dispose();
      });
      await remote.initialize();
      expect(remote.running, isFalse);
      await remote.setEnabled(true);
      await _ready(remote);
      final uri = Uri.parse(remote.urls.single);

      final forbidden = await (await client.getUrl(
        uri.replace(path: '/state', query: ''),
      )).close();
      expect(forbidden.statusCode, HttpStatus.forbidden);
      await forbidden.drain<void>();

      final request = await client.postUrl(uri.replace(path: '/command'));
      request.headers.set('origin', uri.origin);
      request.write(jsonEncode({'action': 'volume', 'value': .32}));
      final response = await request.close();
      expect(response.statusCode, HttpStatus.ok);
      expect(
        (jsonDecode(await utf8.decoder.bind(response).join()) as Map)['volume'],
        .32,
      );
      expect(state.volume, .32);

      final crossSite = await client.postUrl(uri.replace(path: '/command'));
      crossSite.headers.set('origin', 'http://unrelated.example');
      crossSite.write(jsonEncode({'action': 'volume', 'value': .9}));
      final rejected = await crossSite.close();
      expect(rejected.statusCode, HttpStatus.forbidden);
      await rejected.drain<void>();
      expect(state.volume, .32);

      await state.setSurface(AppSurface.standard);
      expect(remote.running, isFalse);
      expect(remote.urls, isEmpty);
    },
  );

  test(
    'documents that /command accepts a request without an Origin header',
    () async {
      final f = await _startLoopbackRemote();
      addTearDown(f.close);
      final double volumeBefore = f.state.volume;
      // A missing Origin is still allowed: non-browser clients legitimately
      // omit it, and the token is what authenticates. Origin is a browser-CSRF
      // mitigation, now applied to every endpoint, with expected values built
      // from the server's own bound port rather than the Host header.
      final request = await f.client.postUrl(f.uri.replace(path: '/command'));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(<String, Object?>{'action': '__probe_noop__'}));
      final response = await request.close();
      expect(response.statusCode, HttpStatus.ok);
      await response.drain<void>();
      expect(
        f.state.volume,
        volumeBefore,
        reason: 'an unknown action must not mutate playback state',
      );
    },
  );

  test('rejects a cross-site Origin on every endpoint', () async {
    final f = await _startLoopbackRemote();
    addTearDown(f.close);
    for (final String path in <String>['/', '/state', '/command']) {
      final bool isPost = path == '/command';
      final HttpClientRequest request = await (isPost
          ? f.client.postUrl(f.uri.replace(path: path))
          : f.client.getUrl(f.uri.replace(path: path)));
      request.headers.set('origin', 'http://unrelated.example');
      if (isPost) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(<String, Object?>{'action': '__probe_noop__'}));
      }
      final HttpClientResponse response = await request.close();
      expect(
        response.statusCode,
        HttpStatus.forbidden,
        reason: '$path must not answer a foreign Origin',
      );
      await response.drain<void>();
    }
  });

  test('accepts the pairing token in an Authorization header', () async {
    final f = await _startLoopbackRemote();
    addTearDown(f.close);
    final String token = f.uri.queryParameters['token']!;
    final HttpClientRequest request = await f.client.postUrl(
      f.uri.replace(path: '/command', query: ''),
    );
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    request.headers.set('origin', f.uri.origin);
    request.write(jsonEncode(<String, Object?>{'action': '__probe_noop__'}));
    final HttpClientResponse response = await request.close();
    expect(
      response.statusCode,
      HttpStatus.ok,
      reason: 'the browser page no longer puts the token in polling URLs',
    );
    await response.drain<void>();
  });

  test('rejects a forged Host that matches a cross-site Origin', () async {
    final f = await _startLoopbackRemote();
    addTearDown(f.close);
    final HttpClientRequest request = await f.client.postUrl(
      f.uri.replace(path: '/command'),
    );
    request.headers.contentType = ContentType.json;
    // The old check compared Origin against "http://" + the client-supplied
    // Host header. Spoofing both made a foreign page look same-origin.
    request.headers.set('origin', 'http://unrelated.example');
    request.headers.set(HttpHeaders.hostHeader, 'unrelated.example');
    request.write(jsonEncode(<String, Object?>{'action': '__probe_noop__'}));
    final HttpClientResponse response = await request.close();
    expect(response.statusCode, HttpStatus.forbidden);
    await response.drain<void>();
  });

  test('only LAN peers may reach the remote', () {
    bool allowed(String value) =>
        LanRemoteController.isAllowedPeer(InternetAddress(value));
    expect(allowed('127.0.0.1'), isTrue);
    expect(allowed('10.1.2.3'), isTrue);
    expect(allowed('172.16.0.1'), isTrue);
    expect(allowed('172.31.255.254'), isTrue);
    expect(allowed('192.168.1.7'), isTrue);
    expect(allowed('169.254.3.4'), isTrue);
    expect(allowed('fc00::1'), isTrue);
    expect(allowed('fe80::1'), isTrue);
    expect(allowed('8.8.8.8'), isFalse);
    expect(allowed('172.32.0.1'), isFalse);
    expect(allowed('203.0.113.1'), isFalse);
    expect(allowed('2001:4860:4860::8888'), isFalse);
  });

  test('sets the documented security response headers', () async {
    final f = await _startLoopbackRemote();
    addTearDown(f.close);
    final response = await (await f.client.getUrl(f.uri)).close();
    expect(response.statusCode, HttpStatus.ok);
    expect(response.headers.value('cache-control'), 'no-store');
    expect(response.headers.value('x-content-type-options'), 'nosniff');
    expect(response.headers.value('referrer-policy'), 'no-referrer');
    final String? csp = response.headers.value('content-security-policy');
    expect(csp, isNotNull);
    expect(csp, contains("frame-ancestors 'none'"));
    expect(csp, contains("default-src 'self'"));
    await response.drain<void>();
  });

  test('restarts after TV mode changes during address discovery', () async {
    HttpOverrides.global = null;
    final state = AppState()..surface = AppSurface.tv;
    final discovering = Completer<void>();
    final continueDiscovery = Completer<void>();
    var discoveries = 0;
    final remote = LanRemoteController(
      state,
      interfaceAddresses: () async {
        if (discoveries++ == 0) {
          discovering.complete();
          await continueDiscovery.future;
        }
        return [InternetAddress.loopbackIPv4];
      },
    );
    final client = HttpClient();
    addTearDown(() {
      if (!continueDiscovery.isCompleted) continueDiscovery.complete();
      client.close(force: true);
      remote.dispose();
      state.dispose();
    });
    await remote.initialize();
    await remote.setEnabled(true);
    await discovering.future.timeout(const Duration(seconds: 5));
    expect(remote.running, isTrue);
    expect(remote.urls, isEmpty);

    await state.setSurface(AppSurface.standard);
    await state.setSurface(AppSurface.tv);
    continueDiscovery.complete();
    await _ready(remote);
    expect(discoveries, 2);
    final response = await (await client.getUrl(
      Uri.parse(remote.urls.single).replace(path: '/state'),
    )).close();
    expect(response.statusCode, HttpStatus.ok);
    await response.drain<void>();
  });

  testWidgets('browser requests update and submit the focused field', (
    tester,
  ) async {
    final state = AppState()..surface = AppSurface.tv;
    final remote = LanRemoteController(
      state,
      bindAddress: InternetAddress.loopbackIPv4,
    );
    final controller = TextEditingController();
    final focus = FocusNode();
    String? submitted;
    addTearDown(() {
      remote.dispose();
      state.dispose();
      controller.dispose();
      focus.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TextField(
            focusNode: focus,
            controller: controller,
            textInputAction: TextInputAction.search,
            onSubmitted: (text) => submitted = text,
          ),
        ),
      ),
    );
    focus.requestFocus();
    await tester.pump();
    await tester.runAsync(() async {
      await HttpOverrides.runWithHttpOverrides(() async {
        final client = HttpClient();
        try {
          await remote.initialize();
          await remote.setEnabled(true);
          await _ready(remote);
          final uri = Uri.parse(remote.urls.single);
          final page = await (await client.getUrl(uri)).close();
          expect(page.statusCode, HttpStatus.ok);
          expect(await utf8.decoder.bind(page).join(), contains('Lazer 遥控器'));
          for (final action in [
            {'action': 'text', 'text': '手机输入 中文 / OTF'},
            {'action': 'submit', 'text': '确认时直接发送的新文字'},
          ]) {
            final request = await client.postUrl(uri.replace(path: '/command'));
            request.headers.contentType = ContentType.json;
            request.headers.set('origin', uri.origin);
            request.write(jsonEncode(action));
            final response = await request.close();
            expect(response.statusCode, HttpStatus.ok);
            await response.drain<void>();
          }
        } finally {
          client.close(force: true);
        }
      }, _LoopbackHttp());
    });
    await tester.pump();
    expect(controller.text, '确认时直接发送的新文字');
    expect(submitted, controller.text);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'remote navigates controls, edits and submits the focused input',
    (tester) async {
      final state = AppState();
      final remote = LanRemoteController(state);
      final controller = TextEditingController();
      final input = FocusNode();
      final button = FocusNode();
      var submissions = 0, taps = 0;
      addTearDown(() {
        remote.dispose();
        state.dispose();
        controller.dispose();
        input.dispose();
        button.dispose();
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TvScope(
              active: true,
              child: Column(
                children: [
                  TextField(
                    controller: controller,
                    focusNode: input,
                    onSubmitted: (_) => submissions++,
                  ),
                  TextButton(
                    focusNode: button,
                    onPressed: () => taps++,
                    child: const Text('button'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      input.requestFocus();
      await tester.pump();
      expect(remote.snapshot['input'], isTrue);
      await remote.command({'action': 'text', 'text': '测试 input'});
      await tester.pump();
      expect(controller.text, '测试 input');
      await remote.command({'action': 'submit'});
      expect(submissions, 1);
      button.requestFocus();
      await tester.pump();
      await remote.command({'action': 'key', 'key': 'select'});
      await tester.pump();
      expect(taps, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
