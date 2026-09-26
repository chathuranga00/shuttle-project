import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/boarding_repository.dart';
import '../../data/models/boarding_history_item.dart';

/// Boarding history — invalidate after a successful boarding to refresh.
final boardingHistoryProvider =
    FutureProvider<List<BoardingHistoryItem>>((ref) {
  return ref.watch(boardingRepositoryProvider).getHistory();
});
