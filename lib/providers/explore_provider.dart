import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/map_user_model.dart';
import '../data/services/map_style_service.dart';
import 'core_providers.dart';

final mapStyleServiceProvider =
Provider<MapStyleService>((ref) => MapStyleService());

/// The MapLibre style document. Not auto-disposed, so returning to the tab
/// does not hand the map a new style and force every tile to reload.
final exploreMapStyleProvider =
FutureProvider<String>((ref) => ref.watch(mapStyleServiceProvider).load());

/// People the user is vibing with (both sides have replied).
class ExploreNotifier extends AsyncNotifier<List<MapUser>> {
  @override
  Future<List<MapUser>> build() =>
      ref.watch(chatRepositoryProvider).mapPeople();

  Future<void> refresh() async {
    state = const AsyncLoading<List<MapUser>>().copyWithPrevious(state);
    state = await AsyncValue.guard(
          () => ref.read(chatRepositoryProvider).mapPeople(),
    );
  }
}

final exploreProvider =
AsyncNotifierProvider<ExploreNotifier, List<MapUser>>(ExploreNotifier.new);

/// Id of the person whose preview is open, or null.
final exploreSelectionProvider = StateProvider<String?>((ref) => null);

enum ExploreViewMode { flat, tilted }

final exploreViewModeProvider =
StateProvider<ExploreViewMode>((ref) => ExploreViewMode.tilted);

/// Camera settings shared by the map, the view toggle and the locate button.
class ExploreCamera {
  const ExploreCamera._();

  static const double defaultZoom = 13.5;

  /// Zoom after tapping a person or cluster. Above 14.5 the style shows 3D
  /// buildings.
  static const double focusZoom = 15.5;

  /// Zoom after tapping the locate button.
  static const double meZoom = 16.5;

  static const double minZoom = 3;
  static const double maxZoom = 19;

  static const double tiltedPitch = 42;
  static const double flatPitch = 0;

  static double pitchFor(ExploreViewMode mode) =>
      mode == ExploreViewMode.tilted ? tiltedPitch : flatPitch;

  static const Duration transition = Duration(milliseconds: 620);
}