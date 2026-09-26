import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/driver_repository.dart';
import '../../data/models/card_verification_result.dart';
import '../../data/models/driver_assignment.dart';
import '../../data/models/driver_trip.dart';
import '../../data/models/driver_trip_history_item.dart';
import '../../data/models/emergency_report.dart';
import '../../data/models/trip_summary.dart';

/// Driver's assigned trip for today (active or next scheduled).
final currentTripProvider = FutureProvider.autoDispose<DriverTrip?>((ref) async {
  return ref.watch(driverRepositoryProvider).getCurrentTrip();
});

/// Live trip summary (passenger count, split, recent boardings).
/// Auto-refreshes every 10 seconds while observed per spec section 18.
final liveTripSummaryProvider =
    StreamProvider.autoDispose.family<TripSummary, int>((ref, tripId) async* {
  final repo = ref.watch(driverRepositoryProvider);
  yield await repo.getTripSummary(tripId);

  final periodic = Stream.periodic(const Duration(seconds: 10));
  await for (final _ in periodic) {
    try {
      yield await repo.getTripSummary(tripId);
    } catch (e) {
      // In case of transient network issue during auto-refresh, keep stream active
    }
  }
});

/// Driver's currently assigned bus and route with stops.
final driverAssignmentProvider =
    FutureProvider.autoDispose<DriverAssignment>((ref) async {
  return ref.watch(driverRepositoryProvider).getAssignment();
});

/// Driver's past completed trip history.
final driverTripHistoryProvider =
    FutureProvider.autoDispose<List<DriverTripHistoryItem>>((ref) async {
  return ref.watch(driverRepositoryProvider).getTripHistory();
});

/// Controller handling driver actions: starting trip, ending trip, reporting emergency, and card verification.
class DriverActionNotifier extends StateNotifier<AsyncValue<void>> {
  DriverActionNotifier(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  DriverRepository get _repository => _ref.read(driverRepositoryProvider);

  Future<bool> startTrip(int tripId) async {
    state = const AsyncValue.loading();
    try {
      await _repository.startTrip(tripId);
      _ref.invalidate(currentTripProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> endTrip(int tripId) async {
    state = const AsyncValue.loading();
    try {
      await _repository.endTrip(tripId);
      _ref.invalidate(currentTripProvider);
      _ref.invalidate(driverTripHistoryProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<EmergencyReport?> reportEmergency({
    required String type,
    required String description,
    String? location,
    int? tripId,
  }) async {
    state = const AsyncValue.loading();
    try {
      final report = await _repository.reportEmergency(
        type: type,
        description: description,
        location: location,
        tripId: tripId,
      );
      state = const AsyncValue.data(null);
      return report;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<CardVerificationResult?> verifyCard(String qrToken) async {
    state = const AsyncValue.loading();
    try {
      final result = await _repository.verifyCard(qrToken);
      state = const AsyncValue.data(null);
      return result;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }
}

final driverActionControllerProvider =
    StateNotifierProvider.autoDispose<DriverActionNotifier, AsyncValue<void>>(
        (ref) {
  return DriverActionNotifier(ref);
});
