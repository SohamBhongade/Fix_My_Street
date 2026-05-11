import 'package:flutter_test/flutter_test.dart';

import 'package:fix_my_street/main.dart';

void main() {
  testWidgets('App boots and shows home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const FixMyStreetApp());
    await tester.pump();

    expect(find.text('FixMyStreet AI'), findsOneWidget);
    expect(find.text('Report an Issue'), findsOneWidget);
    expect(find.text('Volunteer Console'), findsOneWidget);
  });
}
