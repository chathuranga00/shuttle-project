import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../offline/offline_sync_service.dart';
import '../providers/connectivity_provider.dart';

/// Wraps a [child] and shows an offline network status banner at the top when
/// disconnected, or a sync banner when synchronizing queued offline actions.
class ConnectivityBanner extends ConsumerWidget {
  const ConnectivityBanner({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);
    final syncState = ref.watch(offlineSyncServiceProvider);

    final showOffline = !isOnline;
    final showSyncing = isOnline && syncState.status == SyncStatus.syncing;
    final showBanner = showOffline || showSyncing;

    Color bannerColor = Colors.red.shade700;
    Widget bannerContent = const SizedBox.shrink();

    if (showOffline) {
      bannerColor = Colors.red.shade800;
      bannerContent = const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off_rounded, color: Colors.white, size: 16),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              'Offline Mode: Cached data only. Payments & boarding require live server.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    } else if (showSyncing) {
      bannerColor = Colors.blue.shade700;
      bannerContent = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            syncState.message ?? 'Syncing offline actions...',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: showBanner ? 38 : 0,
          color: bannerColor,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: showBanner ? bannerContent : const SizedBox.shrink(),
        ),
        Expanded(child: child),
      ],
    );
  }
}
