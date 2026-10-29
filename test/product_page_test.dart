import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/main.dart';
import 'package:mobile_app/navigation/app_router.dart';

void main() {
  Future<void> open(WidgetTester tester, String route) async {
    appRouter.go(route);
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  testWidgets('remise, suggestions et consultés récemment', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
        const ProviderScope(child: LoMultimediaApp(useGoogleFonts: false)));

    // HP ProBook: 795 000 instead of 1 060 000 → −25 %.
    await open(tester, '/produit/p-001');
    expect(find.text('−25 %'), findsOneWidget);
    expect(find.text('HP · Informatique'), findsOneWidget);
    expect(find.bySemanticsLabel('Partager'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Vous aimerez aussi'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Consultés récemment'), findsNothing,
        reason: 'aucun autre produit consulté pour l’instant');

    // Second product: the first one shows up in "Consultés récemment".
    await open(tester, '/produit/p-008');
    await tester.scrollUntilVisible(find.text('Consultés récemment'), 300,
        scrollable: find.byType(Scrollable).first);
    // The rail's cards sit below the title: scroll down to them.
    await tester.scrollUntilVisible(
        find.textContaining('HP ProBook 450 G10'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('HP ProBook 450 G10'), findsWidgets);

    // Third product: both previous ones, most recent first.
    await open(tester, '/produit/p-009');
    await tester.scrollUntilVisible(find.text('Consultés récemment'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('Apple iPhone 15'), findsWidgets);

    // "Effacer" empties the list.
    await tester.ensureVisible(find.text('Effacer'));
    await tester.pump();
    await tester.tap(find.text('Effacer'));
    await tester.pump();
    expect(find.text('Consultés récemment'), findsNothing);
    appRouter.go('/');
    await tester.pump(const Duration(seconds: 1));
  });
}
