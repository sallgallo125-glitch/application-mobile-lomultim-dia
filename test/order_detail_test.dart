import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/api/api_client.dart';
import 'package:mobile_app/api/errors.dart';
import 'package:mobile_app/api/repositories/account_repository.dart';
import 'package:mobile_app/mocks/mock_http_client.dart';
import 'package:mobile_app/screens/order_detail_screen.dart';

void main() {
  late AccountRepository repo;
  setUp(() => repo = AccountRepository(ApiClient(client: MockHttpClient())));

  test('détail : lignes, historique des statuts et montants', () async {
    final order = await repo.getOrder('LO-2026-00142');
    expect(order.summary.items, hasLength(2));
    expect(order.summary.items.first.unitPriceXof, isNotNull);
    expect(order.events.map((e) => e.status),
        ['Reçue', 'Confirmée', 'En préparation']);
    expect(order.paymentLabel, 'Wave');
    expect(order.cancellable, isTrue);
  });

  test('annuler une commande en préparation', () async {
    final order = await repo.cancelOrder('LO-2026-00142');
    expect(order.summary.status, 'Annulée');
    expect(order.cancellable, isFalse);
    expect(order.events.last.status, 'Annulée');
  });

  test('une commande livrée ne peut plus être annulée', () async {
    expect(() => repo.cancelOrder('LO-2026-00118'),
        throwsA(isA<ApiHttpError>().having((e) => e.status, 'status', 409)));
  });

  testWidgets('la page détail affiche le suivi et le bouton Annuler',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(
        child: MaterialApp(home: OrderDetailScreen(number: 'LO-2026-00142'))));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(find.text('Suivi'), findsOneWidget);
    expect(find.text('En préparation'), findsWidgets);
    expect(find.textContaining('25 sept., 09:15'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Annuler la commande'), 200,
        scrollable: find.byType(Scrollable).last);
    expect(find.text('Annuler la commande'), findsOneWidget);
  });

  testWidgets('une commande livrée propose Racheter, pas Annuler',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(
        child: MaterialApp(home: OrderDetailScreen(number: 'LO-2026-00118'))));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    await tester.scrollUntilVisible(find.text('Racheter'), 200,
        scrollable: find.byType(Scrollable).last);
    expect(find.text('Racheter'), findsOneWidget);
    expect(find.text('Annuler la commande'), findsNothing);
  });

  test('les lignes de commande gardent le produit pour racheter', () async {
    final order = await repo.getOrder('LO-2026-00118');
    expect(order.summary.items.single.productId, 'p-003');
  });
}
