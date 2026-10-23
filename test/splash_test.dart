import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/widgets/splash_overlay.dart';

void main() {
  testWidgets('splash plays then calls onDone', (tester) async {
    var done = false;
    await tester.pumpWidget(MaterialApp(
        home: SplashOverlay(onDone: () => done = true)));

    expect(find.byType(SplashOverlay), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 800));
    expect(done, isFalse);

    await tester.pump(const Duration(milliseconds: 1050));
    expect(done, isTrue);
  });

  testWidgets('reduce motion: short fade only', (tester) async {
    var done = false;
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: MaterialApp(home: SplashOverlay(onDone: () => done = true)),
    ));

    await tester.pump(const Duration(milliseconds: 950));
    expect(done, isTrue);
  });
}
