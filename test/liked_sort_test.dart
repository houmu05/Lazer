import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lazer_nextgen/data/catalog.dart';
import 'package:lazer_nextgen/data/models.dart';
import 'package:lazer_nextgen/gateway/gateway.dart';
import 'package:lazer_nextgen/state/app_state.dart';
import 'package:lazer_nextgen/theme/apple_design.dart';
import 'package:lazer_nextgen/ui/playlist_page.dart';
import 'package:lazer_nextgen/ui/widgets.dart';

const GatewayUserProfile _profile = GatewayUserProfile(
  userId: 7,
  nickname: 'tester',
);

const Playlist _liked = Playlist(
  id: 'liked',
  name: '我喜欢的音乐',
  trackIds: <String>[],
  coverSeed: 1,
  trackCount: 3,
);

Track _track(String id, String title, String artist) => Track(
  id: id,
  title: title,
  artist: artist,
  album: 'Album',
  duration: const Duration(seconds: 3),
  coverSeed: 1,
);

/// Service order: newest liked first.
final List<Track> _serviceOrder = <Track>[
  _track('1', 'Bravo', 'Zed'),
  _track('2', 'alpha', 'Amy'),
  _track('3', 'Charlie', 'Bob'),
];

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
      const UserCollections(liked: _liked);

  @override
  Future<HomeFeed?> loadHome({int? userId}) async => null;

  @override
  Future<void> invalidateCollections(int uid) async {}

  @override
  Future<void> invalidatePlaylist(String id) async {}

  @override
  Future<List<Track>> playlistTracks(String playlistId) async => _serviceOrder;
}

Future<AppState> _signedIn(WidgetTester tester) async {
  tester.view.physicalSize = const Size(430, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final AppState state = AppState(catalog: _Catalog());
  addTearDown(state.dispose);
  await state.signInWithCookie('MUSIC_U=fixture');
  await tester.pump();
  await tester.pump();
  return state;
}

Widget _likes(AppState state) => MaterialApp(
  theme: buildAppleTheme(brightness: Brightness.dark),
  home: Scaffold(
    body: AnimatedBuilder(
      animation: state,
      builder: (BuildContext context, _) => AppLikesPage(state: state),
    ),
  ),
);

List<String> _rowOrder(WidgetTester tester) {
  final List<String> titles = <String>['Bravo', 'alpha', 'Charlie'];
  titles.sort(
    (String a, String b) => tester
        .getTopLeft(find.text(a))
        .dy
        .compareTo(tester.getTopLeft(find.text(b)).dy),
  );
  return titles;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the liked page keeps the service order by default', (
    tester,
  ) async {
    final AppState state = await _signedIn(tester);
    await tester.pumpWidget(_likes(state));
    await tester.pumpAndSettle();
    expect(find.text('Bravo'), findsOneWidget);
    expect(_rowOrder(tester), <String>['Bravo', 'alpha', 'Charlie']);
  });

  testWidgets('sorting by title or artist re-orders the rows and the queue', (
    tester,
  ) async {
    final AppState state = await _signedIn(tester);
    await tester.pumpWidget(_likes(state));
    await tester.pumpAndSettle();

    await state.setLikedSort(LikedSortOrder.title);
    await tester.pumpAndSettle();
    expect(_rowOrder(tester), <String>['alpha', 'Bravo', 'Charlie']);
    expect(
      (await SharedPreferences.getInstance()).getString('lazer_liked_sort'),
      'title',
    );

    // The rows themselves are the sorted list, so a tap builds the queue from
    // this order.
    expect(
      tester
          .widgetList<AppTrackRow>(find.byType(AppTrackRow))
          .map((AppTrackRow row) => row.track.title)
          .toList(),
      <String>['alpha', 'Bravo', 'Charlie'],
    );

    await state.setLikedSort(LikedSortOrder.artist);
    await tester.pumpAndSettle();
    expect(_rowOrder(tester), <String>['alpha', 'Charlie', 'Bravo']);

    await state.setLikedSort(LikedSortOrder.recent);
    await tester.pumpAndSettle();
    expect(_rowOrder(tester), <String>['Bravo', 'alpha', 'Charlie']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the sort control is only on the liked page', (tester) async {
    final AppState state = await _signedIn(tester);
    await tester.pumpWidget(_likes(state));
    await tester.pumpAndSettle();
    expect(find.byTooltip('排序方式'), findsOneWidget);
  });

  test('the liked sort survives a restart', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'flutter.lazer_liked_sort': 'artist',
    });
    final AppState state = AppState(catalog: _Catalog());
    addTearDown(state.dispose);
    await state.bootstrap();
    expect(state.likedSort, LikedSortOrder.artist);
  });
  test('sortLikedTracks keeps the service order for equal keys', () {
    final List<Track> ties = <Track>[
      _track('1', 'Same', 'Band'),
      _track('2', 'same', 'Band'),
      _track('3', 'SAME', 'Band'),
    ];
    expect(
      sortLikedTracks(ties, LikedSortOrder.title).map((Track t) => t.id),
      <String>['1', '2', '3'],
      reason: 'a title tie falls back to the service order',
    );
    expect(
      sortLikedTracks(ties, LikedSortOrder.artist).map((Track t) => t.id),
      <String>['1', '2', '3'],
    );
  });
  testWidgets('the liked collection sorted from any entry point', (
    tester,
  ) async {
    final AppState state = await _signedIn(tester);
    // The sidebar opens the liked playlist through the plain playlist page,
    // without the sortable flag the 我喜欢 section passes.
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppleTheme(brightness: Brightness.dark),
        home: Scaffold(
          body: AnimatedBuilder(
            animation: state,
            builder: (BuildContext context, _) =>
                AppPlaylistPage(state: state, playlist: _liked),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('排序方式'), findsOneWidget);
    await state.setLikedSort(LikedSortOrder.title);
    await tester.pumpAndSettle();
    expect(_rowOrder(tester), <String>['alpha', 'Bravo', 'Charlie']);
  });

  testWidgets('the header count follows the loaded rows', (tester) async {
    final AppState state = await _signedIn(tester);
    // A stale account summary says 99 songs; three rows is the truth.
    const Playlist stale = Playlist(
      id: 'liked',
      name: '我喜欢的音乐',
      trackIds: <String>[],
      coverSeed: 1,
      trackCount: 99,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppleTheme(brightness: Brightness.dark),
        home: Scaffold(
          body: AnimatedBuilder(
            animation: state,
            builder: (BuildContext context, _) =>
                AppPlaylistPage(state: state, playlist: stale, sortable: true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('3 首歌曲'), findsOneWidget);
    expect(find.text('99 首歌曲'), findsNothing);
  });
}
