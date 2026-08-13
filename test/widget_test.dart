import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendify/features/shared/widgets/glass_card.dart';

void main() {
  testWidgets('GlassCard widget renders child content properly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GlassCard(
            child: Text('Attendify Glass Component'),
          ),
        ),
      ),
    );

    expect(find.text('Attendify Glass Component'), findsOneWidget);
    expect(find.byType(GlassCard), findsOneWidget);
  });
}
