import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oga_tailor/src/app.dart';

void main() {
  testWidgets('App boots and shows welcome/auth entry', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: OgaTailorApp()));
    await tester.pumpAndSettle();

    expect(find.textContaining('Oga Tailor'), findsWidgets);
  });
}
