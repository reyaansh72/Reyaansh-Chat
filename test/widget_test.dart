import 'package:flutter_test/flutter_test.dart';
import 'package:chat/main.dart';

void main() {
  testWidgets('app builds and shows the login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ReyaanshCoreApp());
    await tester.pumpAndSettle();

    expect(find.text('Reyaansh Chat'), findsWidgets);
    expect(find.text('Join Chat'), findsOneWidget);
  });
}
