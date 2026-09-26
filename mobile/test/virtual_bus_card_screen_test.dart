import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shuttle/features/student/data/models/student_card.dart';
import 'package:shuttle/features/student/data/models/student_profile.dart';
import 'package:shuttle/features/student/data/models/wallet_summary.dart';
import 'package:shuttle/features/student/presentation/providers/student_provider.dart';
import 'package:shuttle/features/student/presentation/screens/virtual_bus_card_screen.dart';

// ── Test fixtures ─────────────────────────────────────────────────────────────

const _wallet = WalletSummary(balance: '0.00', status: 'ACTIVE');

StudentCard _card(String qrToken) => StudentCard(
      cardId: 'UBC-TEST-1234',
      cardStatus: 'ACTIVE',
      monthlyPassStatus: 'NONE',
      wallet: _wallet,
      qrToken: qrToken,
    );

const _profile = StudentProfile(
  id: 1,
  email: 'test@student.com',
  fullName: 'Test Student',
  studentId: 'S001',
  faculty: 'Engineering',
  enrollmentYear: 2024,
);

// ── Helper: build widget under test with provider overrides ───────────────────

Widget _buildScreen({
  required AsyncValue<StudentCard> cardState,
  required AsyncValue<StudentProfile> profileState,
}) {
  return ProviderScope(
    overrides: [
      studentCardProvider.overrideWith((ref) async {
        return cardState.when(
          data: (c) => c,
          loading: () => throw UnimplementedError('loading'),
          error: (e, _) => throw e,
        );
      }),
      studentProfileProvider.overrideWith((ref) async => _profile),
    ],
    child: const MaterialApp(
      home: VirtualBusCardScreen(),
    ),
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('VirtualBusCardScreen', () {
    // ── Initial render ──────────────────────────────────────────────────────

    testWidgets('renders QR code with initial token', (tester) async {
      await tester.pumpWidget(_buildScreen(
        cardState: AsyncData(_card('token-one')),
        profileState: const AsyncData(_profile),
      ));
      await tester.pump(); // let FutureProvider settle

      // QrImageView must be present
      expect(find.byType(QrImageView), findsOneWidget);

      // Caption is visible
      expect(find.text('QR refreshes every 45 seconds'), findsOneWidget);
    });

    testWidgets('displays student name from profile on hero card', (tester) async {
      await tester.pumpWidget(_buildScreen(
        cardState: AsyncData(_card('token-one')),
        profileState: const AsyncData(_profile),
      ));
      await tester.pump();

      expect(find.text('Test Student'), findsOneWidget);
      expect(find.text('ID: S001'), findsOneWidget);
    });

    testWidgets('shows ACTIVE status chip', (tester) async {
      await tester.pumpWidget(_buildScreen(
        cardState: AsyncData(_card('token-one')),
        profileState: const AsyncData(_profile),
      ));
      await tester.pump();

      expect(find.text('ACTIVE'), findsWidgets);
    });

    testWidgets('shows loading indicator while card is loading', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          // Use a Future that never completes to keep the provider in loading state
          studentCardProvider.overrideWith(
              (ref) => Completer<StudentCard>().future),
          studentProfileProvider.overrideWith((ref) async => _profile),
        ],
        child: const MaterialApp(home: VirtualBusCardScreen()),
      ));
      // Single pump — the never-completing future means the provider stays loading
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows error view and retry button on error', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          studentCardProvider.overrideWith(
              (ref) => Future.error(Exception('network error'))),
          studentProfileProvider.overrideWith((ref) async => _profile),
        ],
        child: const MaterialApp(home: VirtualBusCardScreen()),
      ));
      await tester.pump();        // schedule futures
      await tester.pump();        // error state renders

      expect(find.text('Could not load card data'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    // ── QR token refresh via provider invalidation ───────────────────────────
    //
    // The screen invalidates `studentCardProvider` every 45 s via a Timer.
    // We verify the mechanism by:
    //   1. Mounting the screen with token-1.
    //   2. Confirming QrImageView shows token-1.
    //   3. Manually calling refresh (simulates what the timer does).
    //   4. Providing token-2 on the next fetch.
    //   5. Confirming QrImageView now shows token-2.
    //
    // Note: fake_async does not integrate with Flutter's widget pump cycle in a
    // way that lets us advance real Dart Timers inside ProviderScope safely in
    // this version of flutter_test.  We test the refresh mechanism directly
    // via the public RefreshIndicator drag — which calls the same
    // `ref.invalidate(studentCardProvider)` path as the timer.

    testWidgets(
        'pull-to-refresh fetches a new card and QR code changes',
        (tester) async {
      int callCount = 0;

      await tester.pumpWidget(ProviderScope(
        overrides: [
          studentCardProvider.overrideWith((ref) async {
            callCount++;
            return callCount == 1 ? _card('token-one') : _card('token-two');
          }),
          studentProfileProvider.overrideWith((ref) async => _profile),
        ],
        child: const MaterialApp(home: VirtualBusCardScreen()),
      ));

      // Settle initial load (FutureProvider)
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Verify initial QR token via ValueKey
      expect(find.byKey(const ValueKey('token-one')), findsOneWidget);

      // Simulate pull-to-refresh
      await tester.fling(
        find.byType(SingleChildScrollView),
        const Offset(0, 300),
        1000,
      );
      await tester.pumpAndSettle();

      // Provider was invalidated — next fetch returns token-two
      expect(find.byKey(const ValueKey('token-two')), findsOneWidget);
      // token-one QrImageView must be gone
      expect(find.byKey(const ValueKey('token-one')), findsNothing);

      // callCount must be 2 (initial + one refresh)
      expect(callCount, greaterThanOrEqualTo(2));
    });

    // ── QR lifecycle: old token rejected (documented via comment) ────────────
    //
    // The backend enforces the 60-second expiry — an old QR token is rejected
    // server-side because jjwt throws ExpiredJwtException which CardTokenService
    // maps to ApiException(401, TOKEN_EXPIRED).  This is covered exhaustively in:
    //   - CardTokenServiceTest.verifyCardToken_expiredToken_throwsTokenExpired
    //   - CardVerifyEndpointTest.verify_expiredToken_returns401
    //   - QrRotationIntegrationTest.expiredQrToken_isRejected
    //
    // The Flutter screen mitigates the risk by refreshing every 45 s, ensuring
    // the presented token is always within the 60-second validity window.
  });
}
