import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/student_card.dart';
import '../../data/models/student_profile.dart';
import '../../data/student_repository.dart';

// ── Card provider ─────────────────────────────────────────────────────────────
/// Fetches the student's virtual bus card, including a fresh 60-second QR token.
/// Invalidate this provider to trigger a refresh (done every 45 s on the card screen).
final studentCardProvider = FutureProvider<StudentCard>((ref) {
  return ref.watch(studentRepositoryProvider).getMyCard();
});

// ── Profile provider ──────────────────────────────────────────────────────────
/// Fetches the student's profile. Cached for the session; rarely changes.
final studentProfileProvider = FutureProvider<StudentProfile>((ref) {
  return ref.watch(studentRepositoryProvider).getMyProfile();
});
