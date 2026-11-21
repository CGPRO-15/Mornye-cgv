import 'package:flutter_test/flutter_test.dart';
import 'package:mornye/models/download_history.dart';
import 'package:mornye/providers/download_history_provider.dart';
import 'package:mornye/providers/explore_provider.dart';
import 'package:mornye/providers/genre_explore_provider.dart';

void main() {
  test(
    'genre Explore filters downloaded tracks but keeps new extension tracks',
    () {
      final downloaded = DownloadHistoryState(
        items: [
          DownloadHistoryItem(
            id: 'downloaded',
            trackName: 'Owned Song',
            artistName: 'Owned Artist',
            albumName: 'Album',
            filePath: '/music/owned.flac',
            service: 'example',
            downloadedAt: DateTime.utc(2026, 11, 1),
          ),
        ],
      );
      final items = [
        const ExploreItem(
          id: 'owned',
          uri: 'owned',
          type: 'track',
          name: 'Owned Song',
          artists: 'Owned Artist',
          providerId: 'extension',
        ),
        const ExploreItem(
          id: 'new',
          uri: 'new',
          type: 'track',
          name: 'New Song',
          artists: 'New Artist',
          providerId: 'extension',
        ),
      ];

      expect(
        filterDownloadedGenreItems(items, downloaded).map((item) => item.id),
        ['new'],
      );
    },
  );
}
