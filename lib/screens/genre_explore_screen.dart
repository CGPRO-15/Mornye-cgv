import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'package:mornye/providers/genre_explore_provider.dart';
import 'package:mornye/providers/explore_provider.dart';
import 'package:mornye/l10n/l10n.dart';
import 'package:mornye/utils/adaptive_layout.dart';
import 'package:mornye/controllers/clickable_metadata.dart';
import 'package:mornye/models/track.dart';
import 'package:mornye/screens/extension_collection_screens.dart';
import 'package:mornye/widgets/cached_cover_image.dart';
import 'package:mornye/widgets/app_loading_indicator.dart';
import 'package:mornye/widgets/preview_button.dart';
import 'package:mornye/widgets/track_collection_quick_actions.dart';

class GenreExploreScreen extends ConsumerWidget {
  const GenreExploreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sections = ref.watch(genreExploreProvider);
    final inset = homeContentInset(context) + 16;
    return Scaffold(
      body: sections.when(
        loading: () => const Center(child: AppLoadingIndicator()),
        error: (error, _) => Center(
          child: Text(error.toString()),
        ),
        data: (genreSections) {
          if (genreSections.isEmpty) {
            return CustomScrollView(
              slivers: [
                SliverAppBar(
                  title: Text(context.l10n.navExplore),
                  floating: true,
                ),
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: inset),
                      child: Text(
                        context.l10n.genreExploreEmpty,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                title: Text(context.l10n.navExplore),
                floating: true,
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, sectionIndex) => _GenreSection(
                    section: genreSections[sectionIndex],
                    inset: inset,
                  ),
                  childCount: genreSections.length,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GenreSection extends StatelessWidget {
  const _GenreSection({
    required this.section,
    required this.inset,
  });

  final GenreExploreSection section;
  final double inset;

  void _open(BuildContext context, ExploreItem item) {
    final extensionId = item.providerId;
    if (extensionId == null || extensionId.isEmpty) return;
    switch (item.type) {
      case 'album':
        pushPage<void>(
          context,
          (_) => ExtensionAlbumScreen(
            extensionId: extensionId,
            albumId: item.id,
            albumName: item.name,
            coverUrl: item.coverUrl,
          ),
        );
        return;
      case 'playlist':
        pushPage<void>(
          context,
          (_) => ExtensionPlaylistScreen(
            extensionId: extensionId,
            playlistId: item.id,
            playlistName: item.name,
            coverUrl: item.coverUrl,
          ),
        );
        return;
      case 'artist':
        pushPage<void>(
          context,
          (_) => ExtensionArtistScreen(
            extensionId: extensionId,
            artistId: item.id,
            artistName: item.name,
            coverUrl: item.coverUrl,
          ),
        );
        return;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(item.name)),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final coverSize = 145.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(inset, 20, inset, 12),
          child: Text(
            section.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: coverSize + 112,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: inset - 6),
            itemCount: section.items.length,
            itemBuilder: (context, index) {
              final item = section.items[index];
              final track = item.type == 'track'
                  ? Track.fromBackendMap(
                      item.toJson(),
                      source: item.providerId,
                    )
                  : null;
              return SizedBox(
                width: coverSize,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: InkWell(
                    onTap: track == null ? () => _open(context, item) : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: item.coverUrl?.isNotEmpty == true
                              ? CachedCoverImage(
                                  imageUrl: item.coverUrl!,
                                  width: coverSize,
                                  height: coverSize,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  width: coverSize,
                                  height: coverSize,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                                  child: Icon(
                                    Icons.music_note,
                                    size: 48,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          item.artists,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (track != null)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              PreviewButton(track: track, dense: true),
                              TrackCollectionQuickActions(track: track),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
