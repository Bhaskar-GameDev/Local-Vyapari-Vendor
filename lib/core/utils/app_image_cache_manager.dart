import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Custom image cache with tighter limits than the flutter_cache_manager defaults
/// (200 MB / 30-day TTL). Without this, Cloudinary product images accumulate
/// and push app data well above 100 MB.
///
/// Limits chosen for a typical vendor app workload:
///   - 100 cached images × ~200 KB avg → ~20 MB disk usage
///   - 7-day TTL keeps images fresh without hoarding stale thumbnails
class AppImageCacheManager extends CacheManager with ImageCacheManager {
  static const String _key = 'localVyapariImages';

  AppImageCacheManager._()
      : super(Config(
          _key,
          stalePeriod: const Duration(days: 7),
          maxNrOfCacheObjects: 100,
        ));

  static final AppImageCacheManager instance = AppImageCacheManager._();
}
