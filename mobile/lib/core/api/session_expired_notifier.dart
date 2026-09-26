import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Event bus for session expiry to decouple [dioClientProvider] from [authProvider].
class SessionExpiredNotifier extends StateNotifier<int> {
  SessionExpiredNotifier() : super(0);

  void trigger() {
    state++;
  }
}

final sessionExpiredNotifierProvider =
    StateNotifierProvider<SessionExpiredNotifier, int>((ref) {
  return SessionExpiredNotifier();
});
