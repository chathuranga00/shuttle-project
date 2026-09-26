import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../models/live_bus_location.dart';

class LiveMapService {
  final ApiClient _apiClient;

  LiveMapService(this._apiClient);

  Future<List<LiveBusLocation>> fetchAllActiveLocations() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.liveLocations);
      if (response.data is List) {
        return (response.data as List)
            .map((item) => LiveBusLocation.fromJson(item as Map<String, dynamic>))
            .where((loc) => !loc.cleared)
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('[AdminLiveMap] Failed to load locations: $e');
      return [];
    }
  }

  Stream<Map<int, LiveBusLocation>> streamAllLocations() {
    late StreamController<Map<int, LiveBusLocation>> controller;
    final Map<int, LiveBusLocation> currentLocations = {};
    WebSocketChannel? wsChannel;
    StreamSubscription? wsSubscription;
    Timer? pollingTimer;
    Timer? heartbeatTimer;
    bool isWsConnected = false;

    Future<void> fetchSnapshot() async {
      try {
        final list = await fetchAllActiveLocations();
        currentLocations.clear();
        for (final loc in list) {
          currentLocations[loc.busId] = loc;
        }
        if (!controller.isClosed) {
          controller.add(Map.unmodifiable(currentLocations));
        }
      } catch (e) {
        debugPrint('[AdminLiveMap] Error fetching snapshot: $e');
      }
    }

    void startPollingFallback() {
      if (pollingTimer != null && pollingTimer!.isActive) return;
      debugPrint('[AdminLiveMap] WS inactive, fallback to 8s polling');
      pollingTimer = Timer.periodic(const Duration(seconds: 8), (_) {
        fetchSnapshot();
      });
    }

    void stopPollingFallback() {
      pollingTimer?.cancel();
      pollingTimer = null;
    }

    void connectStompWebSocket() {
      try {
        final baseWs = ApiEndpoints.baseUrl
            .replaceFirst('http://', 'ws://')
            .replaceFirst('https://', 'wss://');
        final wsUrl = '$baseWs/ws';

        final uri = Uri.parse(wsUrl);
        wsChannel = WebSocketChannel.connect(uri);

        const connectFrame = 'CONNECT\naccept-version:1.1,1.2\nheart-beat:10000,10000\n\n\x00';
        wsChannel?.sink.add(connectFrame);

        wsSubscription = wsChannel?.stream.listen(
          (dynamic message) {
            final msg = message.toString();

            if (msg.startsWith('CONNECTED')) {
              isWsConnected = true;
              stopPollingFallback();
              debugPrint('[AdminLiveMap] STOMP connected. Subscribing to /topic/trips/locations');

              const subFrame = 'SUBSCRIBE\nid:sub-admin-locations\ndestination:/topic/trips/locations\n\n\x00';
              wsChannel?.sink.add(subFrame);

              heartbeatTimer = Timer.periodic(const Duration(seconds: 10), (_) {
                if (isWsConnected) {
                  wsChannel?.sink.add('\n');
                }
              });
            } else if (msg.startsWith('MESSAGE')) {
              final bodyIndex = msg.indexOf('\n\n');
              if (bodyIndex != -1) {
                var body = msg.substring(bodyIndex + 2);
                if (body.endsWith('\x00')) {
                  body = body.substring(0, body.length - 1);
                }
                body = body.trim();
                if (body.isNotEmpty) {
                  try {
                    final json = jsonDecode(body) as Map<String, dynamic>;
                    final loc = LiveBusLocation.fromJson(json);
                    if (loc.cleared) {
                      currentLocations.remove(loc.busId);
                    } else {
                      currentLocations[loc.busId] = loc;
                    }
                    if (!controller.isClosed) {
                      controller.add(Map.unmodifiable(currentLocations));
                    }
                  } catch (e) {
                    debugPrint('[AdminLiveMap] Failed to parse STOMP message: $e');
                  }
                }
              }
            }
          },
          onError: (e) {
            debugPrint('[AdminLiveMap] WS error: $e');
            isWsConnected = false;
            startPollingFallback();
          },
          onDone: () {
            debugPrint('[AdminLiveMap] WS closed');
            isWsConnected = false;
            startPollingFallback();
          },
        );
      } catch (e) {
        debugPrint('[AdminLiveMap] WS init failed: $e');
        isWsConnected = false;
        startPollingFallback();
      }
    }

    controller = StreamController<Map<int, LiveBusLocation>>(
      onListen: () {
        fetchSnapshot();
        connectStompWebSocket();

        Future.delayed(const Duration(seconds: 3), () {
          if (!isWsConnected && !controller.isClosed) {
            startPollingFallback();
          }
        });
      },
      onCancel: () {
        isWsConnected = false;
        heartbeatTimer?.cancel();
        stopPollingFallback();
        wsSubscription?.cancel();
        wsChannel?.sink.close();
      },
    );

    return controller.stream;
  }
}

final liveMapServiceProvider = Provider<LiveMapService>((ref) {
  final api = ref.watch(apiClientProvider);
  return LiveMapService(api);
});

final liveMapLocationsStreamProvider =
    StreamProvider.autoDispose<Map<int, LiveBusLocation>>((ref) {
  final service = ref.watch(liveMapServiceProvider);
  return service.streamAllLocations();
});
