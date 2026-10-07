import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_app/api/api_client.dart';
import 'package:mobile_app/api/errors.dart';
import 'package:mobile_app/api/repositories/catalog_repository.dart';
import 'package:mobile_app/main.dart';
import 'package:mobile_app/mocks/mock_http_client.dart';
import 'package:mobile_app/navigation/app_router.dart';

/// Search by photo (simulated recognition in the mock API).
void main() {
  // A few bytes are enough: the mock does not decode the picture.
  final photoBytes = Uint8List.fromList(List.generate(300, (i) => i % 256));

  test('API : rayon détecté et produits de ce rayon', () async {
    final repo = CatalogRepository(ApiClient(client: MockHttpClient()));
    final result = await repo.searchByImage(base64Encode(photoBytes));
    expect(result.detected, isNotEmpty);
    expect(result.products, isNotEmpty);
    // Same photo → same answer.
    final again = await repo.searchByImage(base64Encode(photoBytes));
    expect(again.detected, result.detected);
    expect(() => repo.searchByImage(''), throwsA(isA<ApiHttpError>()));
  });

  testWidgets('écran : analyse puis produits similaires', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
        const ProviderScope(child: LoMultimediaApp(useGoogleFonts: false)));
    appRouter.push('/recherche/photo',
        extra: XFile.fromData(photoBytes, name: 'photo.jpg'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Analyse de l’image…'), findsOneWidget);

    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
    expect(find.text('Produits similaires'), findsOneWidget);
    expect(find.textContaining('Rayon détecté'), findsOneWidget);
    expect(find.text('+ Ajouter'), findsWidgets);

    appRouter.go('/');
    await tester.pump(const Duration(seconds: 1));
  });
}
