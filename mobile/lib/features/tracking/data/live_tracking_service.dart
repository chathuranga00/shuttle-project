import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../../core/api/dio_client.dart';
import '../../../core/config/app_config.dart';
import 'models/active_trip.dart';
import 'models/live_bus_location.dart';

class LiveTrackingService {
  LiveTrackingService(this._dio);

  final Dio _dio;

  /// GET /api/trips/active
  /// Returns all currently active trips.
  Future<List<ActiveTrip>> getActiveTrips() async {
    try {
      final response = await _dio.get('/api/trips/active');
      if (response.data is List) {
        return (response.data as List)
            .map((item) => ActiveTrip.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Failed to load active trips: $e');
      return [];
    }
  }

  /// GET /api/trips/{tripId}/location
  /// Returns the latest bus location or null if 404/not available.
  Future<LiveBusLocation?> getTripLocation(int tripId) async {
    try {
      final response = await _dio.get('/api/trips/$tripId/location');
      if (response.data == null) return null;
      return LiveBusLocation.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }

  /// GET /api/admin/trips/locations
  /// Returns all currently active bus locations for the admin live map.
  Future<List<LiveBusLocation>> getAllActiveLocations() async {
    try {
      final response = await _dio.get('/api/admin/trips/locations');
      if (response.data is List) {
        return (response.data as List)
            .map((item) => LiveBusLocation.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Failed to load active bus locations: $e');
      return [];
    }
  }

  /// Returns a stream that pushes real-time location updates via STOMP WebSocket,
  /// with automatic fallback to polling GET /api/trips/{tripId}/location every 8 seconds.
  Stream<LiveBusLocation?> streamTripLocation(int tripId) {
    late StreamController<LiveBusLocation?> controller;
    WebSocketChannel? wsChannel;
    StreamSubscription? wsSubscription;
    Timer? pollingTimer;
    Timer? pingTimer;
    bool isWsConnected = false;

    Future<void> fetchLocationViaHttp() async {
      try {
        final loc = await getTripLocation(tripId);
        if (!controller.isClosed) {
          controller.add(loc);
        }
      } catch (e) {
        // Suppress transient network errors during background polling
      }
    }

    void startPollingFallback() {
      if (pollingTimer != null && pollingTimer!.isActive) return;
      debugPrint('[LiveTracking] WebSocket inactive, starting 8s polling fallback for trip $tripId');
      pollingTimer = Timer.periodic(const Duration(seconds: 8), (_) {
        fetchLocationViaHttp();
      });
    }

    void stopPollingFallback() {
      pollingTimer?.cancel();
      pollingTimer = null;
    }

    void connectStompWebSocket() {
      try {
        final baseWs = AppConfig.baseUrl
            .replaceFirst('http://', 'ws://')
            .replaceFirst('https://', 'wss://');
        final wsUrl = '$baseWs/ws';

        final uri = Uri.parse(wsUrl);
        wsChannel = WebSocketChannel.connect(uri);

        // STOMP CONNECT frame
        const connectFrame = 'CONNECT\naccept-version:1.1,1.2\nheart-beat:10000,10000\n\n\x00';
        wsChannel?.sink.add(connectFrame);

        wsSubscription = wsChannel?.stream.listen(
          (dynamic message) {
            final msg = message.toString();

            if (msg.startsWith('CONNECTED')) {
              isWsConnected = true;
              stopPollingFallback();
              debugPrint('[LiveTracking] STOMP connected to $wsUrl. Subscribing to trip $tripId');

              // STOMP SUBSCRIBE frame
              final subFrame = 'SUBSCRIBE\nid:sub-$tripId\ndestination:/topic/trips/$tripId/location\n\n\x00';
              wsChannel?.sink.add(subFrame);

              // Periodic STOMP heartbeat
              pingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
                if (isWsConnected) {
                  wsChannel?.sink.add('\n');
                }
              });
            } else if (msg.startsWith('MESSAGE')) {
              // Extract message body after blank line
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
                    if (!controller.isClosed) {
                      controller.add(loc.cleared ? null : loc);
                    }
                  } catch (e) {
                    debugPrint('[LiveTracking] Failed to parse STOMP message: $e');
                  }
                }
              }
            }
          },
          onError: (e) {
            debugPrint('[LiveTracking] WebSocket error: $e');
            isWsConnected = false;
            startPollingFallback();
          },
          onDone: () {
            debugPrint('[LiveTracking] WebSocket connection closed');
            isWsConnected = false;
            startPollingFallback();
          },
        );
      } catch (e) {
        debugPrint('[LiveTracking] Failed to initialize WebSocket: $e');
        isWsConnected = false;
        startPollingFallback();
      }
    }

    controller = StreamController<LiveBusLocation?>(
      onListen: () {
        // 1. Fetch initial location immediately via HTTP
        fetchLocationViaHttp();

        // 2. Connect to STOMP WebSocket
        connectStompWebSocket();

        // 3. Fallback watchdog: if WS doesn't connect within 3 seconds, poll HTTP
        Future.delayed(const Duration(seconds: 3), () {
          if (!isWsConnected && !controller.isClosed) {
            startPollingFallback();
          }
        });
      },
      onCancel: () {
        isWsConnected = false;
        pingTimer?.cancel();
        stopPollingFallback();
        wsSubscription?.cancel();
        wsChannel?.sink.close();
      },
    );

    return controller.stream;
  }
}

final liveTrackingServiceProvider = Provider<LiveTrackingService>((ref) {
  final dio = ref.watch(dioClientProvider);
  return LiveTrackingService(dio);
});

final liveBusLocationStreamProvider =
    StreamProvider.autoDispose.family<LiveBusLocation?, int>((ref, tripId) {
  final service = ref.watch(liveTrackingServiceProvider);
  return service.streamTripLocation(tripId);
});

final activeTripsProvider =
    FutureProvider.autoDispose<List<ActiveTrip>>((ref) {
  final service = ref.watch(liveTrackingServiceProvider);
  return service.getActiveTrips();
});
