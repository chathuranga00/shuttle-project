import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/pass_status_response.dart';
import '../../data/pass_repository.dart';

/// Current pass status — invalidate after purchase.
final passStatusProvider = FutureProvider<PassStatusResponse>((ref) {
  return ref.watch(passRepositoryProvider).getStatus();
});
