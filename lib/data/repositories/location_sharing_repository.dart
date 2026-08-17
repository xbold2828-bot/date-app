import '../../core/constants/api_constants.dart';
import '../models/location_sharing_model.dart';
import '../services/api_service.dart';

/// The "who can see me on the map" setting.
///
/// Its own repository rather than a pair of methods on the onboarding one,
/// which owns `PATCH /location` — the coordinates. Those are two different
/// questions (*where am I* versus *who may know*), and only one of them is a
/// step in a funnel.
class LocationSharingRepository {
  LocationSharingRepository(this._api);

  final ApiClient _api;

  LocationSharing _parse(dynamic data) =>
      LocationSharing.fromJson(Map<String, dynamic>.from(data as Map));

  /// `GET /location/sharing` — the current setting, uncached.
  Future<LocationSharing> get() async =>
      _parse(await _api.get(ApiConstants.locationSharing));

  /// `PATCH /location/sharing` — a partial edit; returns the whole setting.
  ///
  /// Every argument is optional and only what is passed gets written, so the
  /// master toggle can be flipped without restating an audience it is not
  /// touching — and, more to the point, without a race where two screens
  /// overwrite each other's field.
  Future<LocationSharing> update({
    bool? enabled,
    LocationAudience? audience,
    List<String>? allowedUserIds,
  }) async {
    final body = <String, dynamic>{
      if (enabled != null) 'enabled': enabled,
      if (audience != null) 'audience': audience.wire,
      if (allowedUserIds != null) 'allowedUserIds': allowedUserIds,
    };
    return _parse(
      await _api.patch(ApiConstants.locationSharing, body: body),
    );
  }
}
