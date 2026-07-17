import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mkg_tax_mobile/features/documents/presentation/smart_document_intake_screen.dart';

void main() {
  testWidgets('verification skeleton avoids technical implementation text', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ExtractionVerificationSkeletonScreen()),
    );
    expect(find.textContaining('Review extracted information'), findsWidgets);
    expect(find.textContaining('Adobe'), findsNothing);
    expect(find.textContaining('Sanctum'), findsNothing);
    expect(find.textContaining('Neon'), findsNothing);
    expect(find.textContaining('SSN'), findsOneWidget); // policy reminder only
  });
}
