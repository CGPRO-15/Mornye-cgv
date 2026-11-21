import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mornye/models/download_history.dart';
import 'package:mornye/providers/download_history_provider.dart';
import 'package:mornye/providers/explore_provider.dart';
import 'package:mornye/providers/extension_provider.dart';
import 'package:mornye/services/history_database.dart';
import 'package:mornye/services/platform_bridge.dart';
import 'package:mornye/utils/logger.dart';

const _genreCacheKey = 'private_genre_explore_v1';

class GenreExploreSection {
  const GenreExploreSection({
    required this.genre,
    required this.title,
    required this.items,
  });

  final String genre;
  final String title;
  final List<ExploreItem> items;
}

final _log = AppLogger('GenreExplore');

bool genreExploreItemIsDownloaded(
  ExploreItem item,
  DownloadHistoryState downloads,
) {
  if (item.name.trim().isEmpty) return false;
  if (downloads.isDownloaded(item.id)) {
    return true;
  }
  if (item.artists.trim().isNotEmpty) {
    final key = DownloadHistoryState.trackArtistKey(item.name, item.artists);
    if (downloads.lookupItems.any(
      (track) =>
          DownloadHistoryState.trackArtistKey(
            track.trackName,
            track.artistName,
          ) ==
          key,
    )) {
      return true;
    }
  }
  return false;
}

List<ExploreItem> filterDownloadedGenreItems(
  Iterable<ExploreItem> items,
  DownloadHistoryState downloads,
) => [
  for (final item in items)
    if (!genreExploreItemIsDownloaded(item, downloads)) item,
];

/// Builds private genre shelves entirely from extension content.
///
/// The downloaded and local libraries are read only for exclusion; they never
/// seed recommendations or influence ranking.
final genreExploreProvider =
    FutureProvider.autoDispose<List<GenreExploreSection>>((ref) async {
      final explore = ref.watch(exploreProvider);
      final downloads = ref.watch(downloadHistoryProvider);
      ref.watch(
        downloadHistoryProvider.select((state) => state.loadedIndexVersion),
      );
      final extensionState = ref.watch(extensionProvider);

      if (!explore.hasContent && !explore.isLoading) {
        await ref.read(exploreProvider.notifier).fetchHomeFeed();
      }

      final feed = ref.read(exploreProvider);
      if (feed.sections.isEmpty) return const [];

      final relatedExtension = extensionState.extensions
          .where(
            (extension) =>
                extension.id == feed.providerId &&
                extension.enabled &&
                extension.hasRelatedTracks,
          )
          .firstOrNull;

      final sections = <GenreExploreSection>[];
      for (final feedSection in feed.sections) {
        var items = filterDownloadedGenreItems(feedSection.items, downloads);

        // Related tracks are a second extension-only source. The seeds come
        // only from the extension's current section, never from downloaded
        // songs or the user's play history.
        if (items.isNotEmpty && relatedExtension != null) {
          final seed = items.where((item) => item.type == 'track').take(3);
          if (seed.isNotEmpty) {
            final raw = await PlatformBridge.getExtensionRelatedTracks(
              relatedExtension.id,
              [
                for (final item in seed)
                  {
                    'id': item.id,
                    'name': item.name,
                    'artists': item.artists,
                    'album_name': item.albumName ?? '',
                    'provider_id': item.providerId ?? relatedExtension.id,
                    'duration_ms': item.durationMs,
                  },
              ],
              limit: 20,
            );
            final relatedItems = <ExploreItem>[
              for (final map in raw)
                ExploreItem.fromJson({
                  ...map,
                  'provider_id':
                      map['provider_id']?.toString().trim().isNotEmpty == true
                      ? map['provider_id']
                      : relatedExtension.id,
                }),
            ];
            items = filterDownloadedGenreItems([
              ...relatedItems,
              ...items,
            ], downloads);
          }
        }

        final trackItems = items.where((item) => item.type == 'track');
        HistoryLookupRequest lookup(ExploreItem item) => HistoryLookupRequest(
          spotifyId: item.id,
          isrc: item.isrc,
          trackName: item.name,
          artistName: item.artists,
        );
        final lookups = [for (final item in trackItems) lookup(item)];
        if (lookups.isNotEmpty) {
          final existing = await ref.read(
            downloadHistoryBatchExistsProvider(
              HistoryBatchLookupRequest.snapshot(lookups),
            ).future,
          );
          items = [
            for (final item in items)
              if (item.type != 'track' ||
                  !existing.contains(lookup(item).lookupKey))
                item,
          ];
        }

        if (items.isEmpty) continue;
        sections.add(
          GenreExploreSection(
            genre: feedSection.uri,
            title: feedSection.title,
            items: items.take(24).toList(growable: false),
          ),
        );
      }

      // Private cache only. It is not written to Library or collection tables.
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          _genreCacheKey,
          jsonEncode({
            'sections': [
              for (final section in sections)
                {
                  'genre': section.genre,
                  'title': section.title,
                  'items': [for (final item in section.items) item.toJson()],
                },
            ],
          }),
        );
      } catch (error) {
        _log.w('Could not cache private genre Explore data: $error');
      }
      return sections;
    });
