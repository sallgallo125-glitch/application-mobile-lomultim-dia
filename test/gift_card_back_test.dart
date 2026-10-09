import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/widgets/card_faces.dart';

/// Gift card back (barcode + number) and the tap-to-flip card.
void main() {
  setUp(() => cardFacesUseGoogleFonts = false);

  testWidgets('verso : numéro et conditions', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: GiftCardBack(amountXof: 50000, code: 'LOGC-4821-7730'))));
    expect(find.text('N°: LOGC-4821-7730'), findsOneWidget);
    expect(find.textContaining('CONDITIONS'), findsOneWidget);
  });

  testWidgets('la carte se retourne au toucher', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: Center(
                child: FlippableGiftCard(amountXof: 25000, code: 'E00004')))));
    expect(find.byType(GiftCardBack), findsNothing);
    await tester.tap(find.byType(FlippableGiftCard));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(GiftCardBack), findsOneWidget);
    // Tap again: back to the front.
    await tester.tap(find.byType(FlippableGiftCard));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(GiftCardBack), findsNothing);
  });

  testWidgets('carte LO+ : verso avec QR et numéro au toucher', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: Center(
                child: FlippableLoyaltyCard(
                    cardNumber: '2026 0417 3320',
                    memberName: 'Aissatou Diop',
                    points: 68,
                    tierCode: 'BLEU')))));
    expect(find.byType(LoyaltyCardBack), findsNothing);
    await tester.tap(find.byType(FlippableLoyaltyCard));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(LoyaltyCardBack), findsOneWidget);
    expect(find.text('2026 0417 3320'), findsOneWidget);
  });
}
