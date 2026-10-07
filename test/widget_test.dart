import 'package:flutter_test/flutter_test.dart';

import 'package:edupet/main.dart';

void main() {
  testWidgets('PetMath root widget builds', (WidgetTester tester) async {
    await tester.pumpWidget(const EduPetApp());
    await tester.pump();

    expect(find.byType(EduPetApp), findsOneWidget);
  });
}
