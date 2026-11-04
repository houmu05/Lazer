import 'package:flutter_test/flutter_test.dart';

import 'package:lazer_nextgen/gateway/gateway.dart';
import 'package:lazer_nextgen/gateway/transport.dart';

/// Serves one canned `/album/sublist` payload.
class _CannedTransport extends NeteaseTransport {
  _CannedTransport(this.body);
  final Map<String, dynamic> body;

  @override
  Future<Map<String, dynamic>> request(
    String alias,
    Map<String, String> parameters,
  ) async {
    if (alias != '/album/sublist') {
      throw ArgumentError.value(alias, 'alias', 'unexpected route');
    }
    return body;
  }
}

Map<String, dynamic> _album(int id, String name) => <String, dynamic>{
  'id': id,
  'name': name,
  'picUrl': 'https://example.test/$id.jpg',
  'size': 10,
  'artists': <Map<String, dynamic>>[
    <String, dynamic>{'id': 1, 'name': 'Artist $id'},
  ],
};

void main() {
  test('reads the live data/hasMore payload from /album/sublist', () async {
    final gateway = NeteaseGateway(
      transport: _CannedTransport(<String, dynamic>{
        'code': 200,
        'count': 31,
        'hasMore': true,
        'paidCount': 0,
        'data': <Map<String, dynamic>>[_album(1, 'One'), _album(2, 'Two')],
      }),
    );
    final GatewayAlbumPage page = await gateway.collectedAlbums(limit: 2);
    expect(page.albums.map((GatewayAlbum album) => album.id), <int>[1, 2]);
    expect(page.albums.first.title, 'One');
    expect(page.albums.first.artist, 'Artist 1');
    expect(page.albums.first.trackCount, 10);
    expect(page.more, isTrue);
    expect(page.count, 31);
  });

  test('still reads the older albums/more payload', () async {
    final gateway = NeteaseGateway(
      transport: _CannedTransport(<String, dynamic>{
        'code': 200,
        'count': 2,
        'more': false,
        'albums': <Map<String, dynamic>>[_album(3, 'Three'), _album(4, 'Four')],
      }),
    );
    final GatewayAlbumPage page = await gateway.collectedAlbums();
    expect(page.albums.map((GatewayAlbum album) => album.id), <int>[3, 4]);
    expect(page.more, isFalse);
  });

  test('an empty page with a count derives hasMore from the offset', () async {
    final gateway = NeteaseGateway(
      transport: _CannedTransport(<String, dynamic>{
        'code': 200,
        'count': 10,
        'data': <dynamic>[],
      }),
    );
    final GatewayAlbumPage page = await gateway.collectedAlbums(offset: 0);
    expect(page.albums, isEmpty);
    expect(page.more, isTrue, reason: '0 of 10 received');
  });

  test('rows without a usable id are dropped', () async {
    final gateway = NeteaseGateway(
      transport: _CannedTransport(<String, dynamic>{
        'code': 200,
        'count': 3,
        'hasMore': false,
        'data': <dynamic>[
          _album(5, 'Five'),
          <String, dynamic>{'id': 0, 'name': 'Broken'},
          <String, dynamic>{'name': 'No id'},
        ],
      }),
    );
    final GatewayAlbumPage page = await gateway.collectedAlbums();
    expect(page.albums.map((GatewayAlbum album) => album.id), <int>[5]);
  });
}
