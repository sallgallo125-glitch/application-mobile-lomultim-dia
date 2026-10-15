import 'dart:ui' show Size;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/main.dart';

void main() {
  testWidgets('Accueil shows loading, then home content from the mock API', (tester) async {
    // Phone-sized screen, as on a real device.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ProviderScope(child: LoMultimediaApp()));
    await tester.pump();

    expect(find.text('LO Multimédia'), findsOneWidget);
    expect(find.bySemanticsLabel("Chargement de l'accueil…"), findsOneWidget);

    // MockHttpClient simulates 350 ms of latency.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(find.text('Nos rayons'), findsOneWidget);
  });
}
