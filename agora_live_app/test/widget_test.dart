import 'package:agora_live_app/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows live home actions', (tester) async {
    await tester.pumpWidget(const AgoraLiveApp());

    expect(find.text('LikeeHit Live'), findsOneWidget);
    expect(find.text('Start Live'), findsOneWidget);
    expect(find.text('Join Live'), findsOneWidget);
  });
}
