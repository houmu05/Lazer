import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lazer_nextgen/data/catalog.dart';
import 'package:lazer_nextgen/data/catalog_details.dart';
import 'package:lazer_nextgen/data/models.dart';
import 'package:lazer_nextgen/gateway/gateway.dart';
import 'package:lazer_nextgen/state/app_state.dart';
import 'package:lazer_nextgen/theme/apple_design.dart';
import 'package:lazer_nextgen/ui/library_page.dart';

const GatewayUserProfile _profile = GatewayUserProfile(
  userId: 7,
  nickname: 'tester',
);

Album _album(String id, String title) => Album(
  id: id,
  title: title,
  artist: '$title artist',
  year: '2026',
  coverSeed: 1,
  note: '',
);

class _Gateway extends NeteaseGateway {
  @override
  Future<GatewayLoginStatus> loginWithCookie(String cookie) async {
    sessionCookie = 'MUSIC_U=fixture';
    return const GatewayLoginStatus(profile: _profile);
  }

  @override
  Future<Set<int>> likedSongIds(int uid) async => <int>{};
}

class _Catalog extends Catalog {
  _Catalog() : super(gateway: _Gateway());

  @override
  Future<UserCollections?> cachedUserCollections(int uid) async => null;

  @override
  Future<UserCollections> userCollections(int uid) async =>
      UserCollections.empty;

  @override
  Future<HomeFeed?> loadHome({int? userId}) async => null;

  @override
  Future<void> invalidateCollections(int uid) async {}

  @override
  Future<void> invalidatePlaylist(String id) async {}

  @override
  Future<UserAlbumPage> userAlbums(
    int uid, {
    int limit = 30,
    int offset = 0,
    bool force = false,
  }) async => UserAlbumPage(
    albums: <Album>[
      _album('a', 'Alpha'),
      _album('b', 'Bravo'),
      _album('c', 'Charlie'),
    ],
    more: false,
    receivedCount: 3,
  );
}

Future<AppState> _signedIn(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1280, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final AppState state = AppState(catalog: _Catalog());
  addTearDown(state.dispose);
  await state.signInWithCookie('MUSIC_U=fixture');
  await tester.pump();
  await tester.pump();
  return state;
}

Widget _library(AppState state) => MaterialApp(
  theme: buildAppleTheme(brightness: Brightness.dark),
  home: Scaffold(
    body: AnimatedBuilder(
      animation: state,
      builder: (BuildContext context, _) => AppLibraryPage(
        state: state,
        onOpenPlaylist: (Playlist playlist) {},
        onOpenLocalMusic: () {},
      ),
    ),
  ),
);

double _left(WidgetTester tester, String title) =>
    tester.getTopLeft(find.text(title)).dx;

/// Runs the frames the album release animation needs.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    if (find.byKey(const ValueKey('album-drag-preview')).evaluate().isEmpty) {
      return;
    }
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('dragging an album writes and persists the order', (
    tester,
  ) async {
    final AppState state = await _signedIn(tester);
    await tester.pumpWidget(_library(state));
    await tester.pumpAndSettle();
    expect(find.text('Alpha'), findsOneWidget);

    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(find.text('Alpha')),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump(const Duration(milliseconds: 24));
    await gesture.moveTo(tester.getCenter(find.text('Bravo')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('album-drag-preview')),
      findsOneWidget,
      reason: 'the album card lifts like a playlist card',
    );
    await gesture.up();
    await tester.pump();
    await _settle(tester);

    expect(state.albumOrder, <String>['b', 'a', 'c']);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('lazer_album_order'), 'b\na\nc');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a saved album order applies, unlisted ids stay behind', (
    tester,
  ) async {
    final AppState state = await _signedIn(tester);
    await state.setAlbumOrder(<String>['c']);
    await tester.pumpWidget(_library(state));
    await tester.pumpAndSettle();

    // Charlie was arranged first; Alpha and Bravo keep their catalogue order
    // after it, so the three cards read Charlie, Alpha, Bravo from the left.
    expect(_left(tester, 'Charlie'), lessThan(_left(tester, 'Alpha')));
    expect(_left(tester, 'Alpha'), lessThan(_left(tester, 'Bravo')));
  });

  test('the album order survives a restart', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'flutter.lazer_album_order': 'c\nb\na',
    });
    final AppState state = AppState(catalog: _Catalog());
    addTearDown(state.dispose);
    await state.bootstrap();
    expect(state.albumOrder, <String>['c', 'b', 'a']);
  });
}
