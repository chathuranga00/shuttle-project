import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shuttle/main.dart';

void main() {
  testWidgets('App smoke test — renders without crashing', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: ShuttleApp()),
    );
    expect(find.text('University Shuttle'), findsOneWidget);
  });
}
