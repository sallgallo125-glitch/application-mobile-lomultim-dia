import 'dart:convert';

import 'package:http/http.dart' as http;

import '../utils/delivery.dart';
import '../utils/loyalty.dart';
import '../features/persistence.dart';
import 'data/home_mock_data.dart';
import 'data/laptop_options.dart';
import 'mock_member_backend.dart';
import 'data/products_mock_data.dart';

Map<String, dynamic> _orderItem(String productId) {
  final product = mockProducts.firstWhere((item) => item['id'] == productId);
  return {
    'productId': productId,
    'name': product['name'],
    'imageUrl': product['imageUrl'],
    'categoryId': product['categoryId'],
    'quantity': 1,
    'unitPriceXof': product['priceXof'],
  };
}

/// Mirrors ../mobile-app/src/mocks/mockFetch.ts — a deterministic mock
/// transport. In the RN app this is swapped in by monkey-patching
/// `globalThis.fetch`; here the idiomatic equivalent is handing a
/// [MockHttpClient] instance to [ApiClient] instead of a real http.Client
/// (see lib/features/home/home_providers.dart).
class MockHttpClient extends http.BaseClient {
  MockHttpClient({this.persistence});

  static const _simulatedLatency = Duration(milliseconds: 350);

  final LocalPersistence? persistence;

  /// LO+, gift cards, tracking and content routes.
  final MockMemberBackend member = MockMemberBackend();
  final List<Map<String, dynamic>> _cartItems = [];
  List<Map<String, dynamic>> _orders = [];
  Future<void>? _initialization;

  List<Map<String, dynamic>> _demoOrders() => [
        {
          'id': 'o-001',
          'number': 'LO-2026-00142',
          'createdAt': '24 septembre 2026',
          'status': 'En préparation',
          'totalXof': 482000,
          'pointsToEarn': 48,
          'deliveryInfo':
              'Livraison prévue entre le mercredi 14 octobre et le jeudi 15 octobre',
          'deliveryMethodCode': 'STANDARD',
          'paymentMethod': 'WAVE',
          'name': 'Aissatou Diop',
          'address': 'Sacré-Cœur 3, villa 112, Dakar',
          'events': [
            {'status': 'Reçue', 'at': '24 sept., 10:42'},
            {
              'status': 'Confirmée',
              'at': '24 sept., 11:05',
              'comment': 'Paiement Wave reçu'
            },
            {
              'status': 'En préparation',
              'at': '25 sept., 09:15',
              'comment': 'Showroom Sandaga'
            },
          ],
          'items': [
            _orderItem('p-001'),
            _orderItem('p-004'),
          ],
        },
        {
          'id': 'o-002',
          'number': 'LO-2026-00118',
          'createdAt': '12 septembre 2026',
          'status': 'Livrée',
          'totalXof': 145000,
          'deliveryInfo': 'Livré le 24-09',
          'deliveryMethodCode': 'PICKUP',
          'paymentMethod': 'CASH_ON_DELIVERY',
          'name': 'Aissatou Diop',
          'events': [
            {'status': 'Reçue', 'at': '12 sept., 16:20'},
            {'status': 'En préparation', 'at': '13 sept., 09:30'},
            {
              'status': 'Prête à retirer',
              'at': '13 sept., 14:10',
              'comment': 'Showroom Médina'
            },
            {
              'status': 'Livrée',
              'at': '14 sept., 11:45',
              'comment': 'Retirée et payée en showroom'
            },
          ],
          'items': [_orderItem('p-003')],
        },
      ];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    await Future<void>.delayed(_simulatedLatency);
    await _ensureInitialized();

    final path = request.url.path;

    final bodyText = request is http.Request ? request.body : '';
    final memberResult = member.handle(
        request.method,
        path,
        bodyText.isEmpty
            ? const {}
            : jsonDecode(bodyText) as Map<String, dynamic>);
    if (memberResult != null) {
      if (memberResult.status < 400) await _saveMemberState();
      return _json(request, memberResult.status, memberResult.body);
    }

    if (request.method == 'GET' && path == '/api/v1/home') {
      return _json(request, 200, {
        'data': {
          'banners': mockBanners,
          'categories': mockCategories,
          'flashProducts': mockProducts
              .where((product) => (product['badges'] as List).contains('promo'))
              .toList(),
          // 8 best-rated "top vente" products.
          'bestSellers': (mockProducts
                  .where(
                      (product) => (product['badges'] as List).contains('top'))
                  .toList()
                ..sort((a, b) => ((b['rating'] as num?) ?? 0)
                    .compareTo((a['rating'] as num?) ?? 0)))
              .take(8)
              .toList(),
          // Nouveautés: produits avec badge 'new'
          'newArrivals': mockProducts
              .where((product) => (product['badges'] as List).contains('new'))
              .toList(),
          // Recommandations personnalisées: mélange de top-rated produits
          'recommendedProducts': (mockProducts
                  .where((product) => ((product['rating'] as num?) ?? 0) >= 4.5)
                  .toList()
                ..sort((a, b) => ((b['rating'] as num?) ?? 0)
                    .compareTo((a['rating'] as num?) ?? 0)))
              .take(6)
              .toList(),
        },
      });
    }

    if (request.method == 'GET' && path == '/api/v1/products') {
      return _json(request, 200, {'data': mockProducts});
    }

    // Search by photo. SIMULATED: no image recognition here; the "detected"
    // department is derived from the picture's size so the same photo always
    // gives the same answer. The real API will analyse the image.
    if (request.method == 'POST' && path == '/api/v1/search/image') {
      final body = jsonDecode(bodyText.isEmpty ? '{}' : bodyText)
          as Map<String, dynamic>;
      final image = body['imageBase64'] as String? ?? '';
      if (image.isEmpty) {
        return _json(request, 422,
            {'code': 'IMAGE_REQUIRED', 'message': 'Aucune image reçue.'});
      }
      final category = mockCategories[image.length % mockCategories.length];
      final matches =
          mockProducts.where((p) => p['categoryId'] == category['id']).toList();
      return _json(request, 200, {
        'data': matches,
        'meta': {'detected': category['name'], 'simulated': true},
      });
    }

    if (request.method == 'GET' && path == '/api/v1/categories') {
      return _json(request, 200, {'data': mockCategories});
    }
    if (request.method == 'GET' && path == '/api/v1/account/summary')
      return _json(request, 200, {
        'data': {
          'name': 'Aissatou Diop',
          'phone': '76 621 11 11',
          'ordersCount': 3,
          'loyalty': {
            'tierCode': 'BLEU',
            'points': member.points,
            'spend12MonthsXof': member.spend12MonthsXof
          }
        }
      });
    if (request.method == 'GET' && path == '/api/v1/orders')
      return _json(request, 200, {'data': _orders});
    final orderRoute =
        RegExp(r'^/api/v1/orders/([^/]+)(/cancel)?$').firstMatch(path);
    if (orderRoute != null) {
      final number = Uri.decodeComponent(orderRoute.group(1)!);
      final order = _orders.where((o) => o['number'] == number).firstOrNull;
      if (order == null)
        return _json(request, 404,
            {'code': 'ORDER_NOT_FOUND', 'message': 'Commande introuvable.'});
      if (request.method == 'GET' && orderRoute.group(2) == null)
        return _json(request, 200, {'data': _orderDetail(order)});
      if (request.method == 'POST' && orderRoute.group(2) != null) {
        if (!_cancellable(order))
          return _json(request, 409, {
            'code': 'ORDER_NOT_CANCELLABLE',
            'message': 'Cette commande ne peut plus être annulée.'
          });
        order['status'] = 'Annulée';
        order['events'] = [
          ..._events(order),
          {'status': 'Annulée', 'at': _nowLabel(), 'comment': 'Par vous'},
        ];
        await _saveOrders();
        return _json(request, 200, {'data': _orderDetail(order)});
      }
    }

    if (request.method == 'GET' && path == '/api/v1/cart')
      return _json(request, 200, {'data': _cart()});
    if (request.method == 'POST' && path == '/api/v1/checkout') {
      if (_cartItems.isEmpty)
        return _json(
            request, 422, {'code': 'empty_cart', 'message': 'Cart is empty'});
      final body =
          jsonDecode((request as http.Request).body) as Map<String, dynamic>;
      final method =
          DeliveryMethod.fromCode(body['deliveryMethodCode'] as String?);
      final zoneId = body['zoneId'] as String? ?? defaultZoneId;
      final payment = PaymentMethod.fromCode(body['paymentMethod'] as String?);
      if (payment == null || !payment.available)
        return _json(request, 422, {
          'code': 'payment_unavailable',
          'message': 'Payment method not available yet'
        });
      final subtotal = _cart()['subtotalXof'] as int;
      final totals = calculateCheckoutTotals(
          subtotal, method, zoneId, body['promoCode'] as String? ?? '');

      // LO+ points first (1 point = 100 FCFA), then the gift card, like the
      // site; whatever is left is paid with [payment].
      final guest = body['customerType'] == 'GUEST';
      final requestedPoints = (body['pointsToUse'] as num?)?.toInt() ?? 0;
      if (guest && requestedPoints > 0)
        return _json(request, 422, {
          'code': 'ACCOUNT_REQUIRED',
          'message': 'Les points LO+ nécessitent un compte.'
        });
      if (requestedPoints < 0 || requestedPoints > member.points)
        return _json(request, 422, {
          'code': 'INSUFFICIENT_POINTS',
          'message': 'Solde de points insuffisant.'
        });
      // Up to the whole order, at least 10 points (CFG.ptsPaiementMin).
      final pointsUsed = requestedPoints
          .clamp(0, redeemablePoints(member.points, totals.totalXof))
          .toInt();
      final pointsDiscount = pointsUsed * loyaltyPointValueXof;
      final giftCode = (body['giftCardCode'] as String? ?? '').trim();
      var giftApplied = 0;
      if (giftCode.isNotEmpty) {
        final error =
            member.checkGiftCard(giftCode, body['giftCardOtp'] as String?);
        if (error != null) return _json(request, error.status, error.body);
        final remaining = totals.totalXof - pointsDiscount;
        final balance = member.giftCardBalance(giftCode);
        giftApplied = balance < remaining ? balance : remaining;
      }
      final orderNumber =
          'LO-2026-${(143 + _orders.length).toString().padLeft(5, '0')}';
      final pointsToEarn = loyaltyPointsFor(
          totals.subtotalXof - totals.promoDiscountXof - pointsDiscount,
          'BLEU');
      if (!guest) member.spendPoints(pointsUsed, orderNumber);
      if (giftApplied > 0)
        member.debitGiftCard(giftCode, giftApplied, orderNumber);
      // Guests earn nothing (no LO+ account to credit).
      if (!guest) member.creditPendingPoints(pointsToEarn, orderNumber);
      // Trackable right away with its number + the checkout phone.
      member.registerTracking(orderNumber, body['phone'] as String? ?? '',
          payment.label, method.label);
      final order = {
        'id': 'o-${DateTime.now().millisecondsSinceEpoch}',
        'number': orderNumber,
        'createdAt': '25 septembre 2026',
        'status': 'Confirmée',
        'totalXof': totals.totalXof,
        'customerType': guest ? 'GUEST' : 'MEMBER',
        'pointsToEarn': guest ? 0 : pointsToEarn,
        if (guest) 'pointsIfMember': pointsToEarn,
        'pointsUsed': pointsUsed,
        'pointsDiscountXof': pointsDiscount,
        'giftCardAppliedXof': giftApplied,
        'amountDueXof': totals.totalXof - pointsDiscount - giftApplied,
        'deliveryMethodCode': method.code,
        'deliveryInfo': method == DeliveryMethod.pickup
            ? 'Retrait en showroom · ${method.hint}'
            : 'Livraison prévue · ${method.hint}',
        'items': [
          for (final item in _cartItems)
            {
              'productId': item['productId'],
              'name': item['name'],
              'imageUrl': item['imageUrl'],
              'categoryId': item['categoryId'],
              'quantity': item['quantity'],
              'unitPriceXof': item['unitPriceXof'],
            }
        ],
        'events': [
          {'status': 'Confirmée', 'at': _nowLabel()},
        ],
        'zoneId': zoneId,
        'paymentMethod': payment.code,
        'promoDiscountXof': totals.promoDiscountXof,
        'deliveryFeeXof': totals.deliveryFeeXof,
        'name': body['name'] as String? ?? '',
        'phone': body['phone'] as String? ?? '',
        if ((body['address'] as String? ?? '').trim().isNotEmpty)
          'address': (body['address'] as String).trim(),
      };
      // "Mes commandes" lists the member's orders only.
      if (!guest) {
        _orders.insert(0, order);
        await _saveOrders();
      }
      _cartItems.clear();
      await _saveCart();
      await _saveMemberState();
      return _json(request, 201, {'data': order});
    }
    if (request.method == 'POST' && path == '/api/v1/cart/items') {
      final body =
          jsonDecode((request as http.Request).body) as Map<String, dynamic>;
      final product = mockProducts
          .cast<Map<String, dynamic>>()
          .firstWhere((item) => item['id'] == body['productId']);
      final productId = product['id'] as String;
      final quantity = (body['quantity'] as num?)?.toInt() ?? 1;
      if (quantity < 1 || quantity > 99)
        return _json(request, 422,
            {'code': 'INVALID_QUANTITY', 'message': 'Quantité invalide.'});
      final addonIds = ((body['addonIds'] as List<dynamic>?) ?? const [])
          .cast<String>()
          .toList()
        ..sort();
      final addons =
          accessoriesFor(productId).where((a) => addonIds.contains(a['id']));
      // Chosen option per group; missing groups use the default choice.
      final requested = (body['options'] as Map<String, dynamic>? ?? const {})
          .cast<String, String>();
      final chosen = <Map<String, dynamic>>[];
      for (final group in optionGroupsFor(productId)) {
        final choiceId = requested[group['id']] ?? group['defaultChoiceId'];
        final choice = (group['choices'] as List)
            .cast<Map<String, dynamic>>()
            .where((c) => c['id'] == choiceId)
            .firstOrNull;
        if (choice == null)
          return _json(request, 422,
              {'code': 'INVALID_OPTION', 'message': 'Option indisponible.'});
        chosen.add(choice);
      }
      final unitPrice = (product['priceXof'] as int) +
          chosen.fold<int>(0, (sum, c) => sum + (c['priceDeltaXof'] as int)) +
          addons.fold<int>(0, (sum, a) => sum + (a['priceXof'] as int));
      final lineId = [
        'cart-$productId',
        // Same configuration = same cart line, whether chosen or default.
        ...chosen.map((c) => c['id'] as String),
        ...addonIds,
      ].join('_');
      final existing =
          _cartItems.where((item) => item['id'] == lineId).toList();
      if (existing.isEmpty)
        _cartItems.add({
          'id': lineId,
          'productId': productId,
          // "HP ProBook 450 G10 — Intel Core i5 · 32 Go · 1 To SSD · Souris"
          'name': [
            product['name'],
            ...chosen.map((c) => c['label']),
            ...addons.map((a) => a['name']),
          ].join(' · '),
          'quantity': quantity,
          'unitPriceXof': unitPrice,
          'imageUrl': product['imageUrl'],
          'categoryId': product['categoryId'],
          if (body['variantId'] != null) 'variantId': body['variantId'],
          'addonIds': addonIds,
          'options': requested,
        });
      else
        existing.first['quantity'] =
            (existing.first['quantity'] as int) + quantity;
      await _saveCart();
      return _json(request, 200, {'data': _cart()});
    }
    if (path.startsWith('/api/v1/cart/items/')) {
      final id = path.substring('/api/v1/cart/items/'.length);
      final item = _cartItems.where((value) => value['id'] == id).toList();
      if (item.isEmpty)
        return _json(request, 404,
            {'code': 'not_found', 'message': 'Cart item not found'});
      if (request.method == 'DELETE') _cartItems.remove(item.first);
      if (request.method == 'PATCH') {
        final body =
            jsonDecode((request as http.Request).body) as Map<String, dynamic>;
        final quantity = body['quantity'] as int;
        if (quantity < 1)
          _cartItems.remove(item.first);
        else
          item.first['quantity'] = quantity;
      }
      await _saveCart();
      return _json(request, 200, {'data': _cart()});
    }

    if (request.method == 'GET' && path.startsWith('/api/v1/products/')) {
      final id = path.substring('/api/v1/products/'.length);
      final matches = mockProducts.where((product) => product['id'] == id);
      if (matches.isEmpty)
        return _json(request, 404,
            {'code': 'not_found', 'message': 'Product not found'});
      final product = matches.first;
      return _json(request, 200, {
        'data': {
          ...product,
          'description':
              'Produit original sélectionné par LO Multimédia, avec garantie constructeur et facture.',
          'images': product['images'] ??
              [if (product['imageUrl'] != null) product['imageUrl']],
          'specifications': {
            'Marque': product['brand'] as String,
            'Disponibilité':
                product['inStock'] == true ? 'En stock' : 'Rupture de stock',
            'Garantie': '12 mois'
          },
          'optionGroups': optionGroupsFor(id),
          'addons': accessoriesFor(id),
          'reviews': [
            {
              'id': '${id}-review-1',
              'author': 'Aissatou D.',
              'rating': 5,
              'comment': 'Très bon produit et livraison rapide.',
              'verified': true
            },
            {
              'id': '${id}-review-2',
              'author': 'Moussa N.',
              'rating': 4,
              'comment': 'Conforme à la description, bon rapport qualité-prix.',
              'verified': true
            },
            {
              'id': '${id}-review-3',
              'author': 'Fatou S.',
              'rating': 5,
              'comment':
                  'Retrait en showroom rapide, équipe très professionnelle.',
              'verified': false
            }
          ],
        }
      });
    }

    return _json(request, 404, {
      'code': 'not_found',
      'message': 'No mock route for ${request.method} $path',
    });
  }

  Future<void> _ensureInitialized() {
    if (_initialization != null) return _initialization!;
    if (persistence == null) {
      _orders = _demoOrders();
      return _initialization = Future<void>.value();
    }
    return _initialization = _loadPersistedData();
  }

  Future<void> _loadPersistedData() async {
    final savedMember = persistence?.read('mock_member_state');
    if (savedMember != null) {
      final decoded = jsonDecode(savedMember);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException(
            'Stored mock member data must be an object.');
      }
      member.restoreState(decoded);
    }

    final savedOrders = persistence?.read('mock_member_orders');
    if (savedOrders == null) {
      _orders = _demoOrders();
      await _saveOrders();
    } else {
      _orders = _decodeRows(savedOrders, 'mock_member_orders');
    }

    final savedCart = persistence?.read('mock_cart_items');
    if (savedCart != null) {
      _cartItems.addAll(_decodeRows(savedCart, 'mock_cart_items'));
    }
  }

  List<Map<String, dynamic>> _decodeRows(String json, String key) {
    final decoded = jsonDecode(json);
    if (decoded is! List<dynamic>) {
      throw FormatException('Stored "$key" must be a JSON list.');
    }
    return [
      for (final row in decoded)
        if (row is Map<String, dynamic>)
          row
        else
          throw FormatException('Stored "$key" contains an invalid row.')
    ];
  }

  Future<void> _saveOrders() =>
      persistence?.write('mock_member_orders', jsonEncode(_orders)) ??
      Future<void>.value();

  Future<void> _saveCart() =>
      persistence?.write('mock_cart_items', jsonEncode(_cartItems)) ??
      Future<void>.value();

  Future<void> _saveMemberState() =>
      persistence?.write(
        'mock_member_state',
        jsonEncode(member.exportState()),
      ) ??
      Future<void>.value();

  /// Mirrors the ERP's « annulable »: until the order leaves for delivery.
  bool _cancellable(Map<String, dynamic> order) {
    final status = (order['status'] as String).toLowerCase();
    return !['annul', 'route', 'expédi', 'prête', 'livr'].any(status.contains);
  }

  /// Status history; orders saved before it existed get a single entry.
  List<Map<String, dynamic>> _events(Map<String, dynamic> order) =>
      (order['events'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
      [
        {'status': order['status'], 'at': order['createdAt']}
      ];

  static const _months = [
    'janv.',
    'févr.',
    'mars',
    'avr.',
    'mai',
    'juin',
    'juil.',
    'août',
    'sept.',
    'oct.',
    'nov.',
    'déc.'
  ];

  static String _nowLabel() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${now.day} ${_months[now.month - 1]}, '
        '${two(now.hour)}:${two(now.minute)}';
  }

  Map<String, dynamic> _orderDetail(Map<String, dynamic> order) {
    final items = [
      for (final item in (order['items'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>())
        {
          ...item,
          // Orders saved before lines kept their product: found by name
          // (the cart name starts with the product name).
          'productId': item['productId'] ??
              mockProducts
                  .where((p) =>
                      (item['name'] as String).startsWith(p['name'] as String))
                  .firstOrNull?['id'],
        }
    ];
    final fee = (order['deliveryFeeXof'] as num?)?.toInt() ?? 0;
    final linesTotal = items.fold<int>(
        0,
        (sum, i) =>
            sum +
            ((i['unitPriceXof'] as num?)?.toInt() ?? 0) *
                ((i['quantity'] as num?)?.toInt() ?? 1));
    final method =
        DeliveryMethod.fromCode(order['deliveryMethodCode'] as String?);
    final payment = PaymentMethod.fromCode(order['paymentMethod'] as String?) ??
        PaymentMethod.cashOnDelivery;
    final status = (order['status'] as String).toLowerCase();
    return {
      ...order,
      'items': items,
      'events': _events(order),
      'subtotalXof':
          linesTotal > 0 ? linesTotal : (order['totalXof'] as int) - fee,
      'deliveryFeeXof': fee,
      'deliveryLabel': method.label,
      if (method == DeliveryMethod.pickup && order['address'] == null)
        'address': 'Showroom Sandaga, avenue Lamine Guèye',
      'paymentLabel': payment.label,
      'paid': payment.isOnline || status.contains('livr'),
      'cancellable': _cancellable(order),
    };
  }

  Map<String, dynamic> _cart() {
    final subtotal = _cartItems.fold<int>(
        0,
        (sum, item) =>
            sum + (item['unitPriceXof'] as int) * (item['quantity'] as int));
    // GET /cart quotes standard delivery to Dakar Centre, like the site's
    // checkout default; checkout recomputes with the customer's choices.
    final deliveryFee = subtotal == 0
        ? 0
        : deliveryFeeXof(DeliveryMethod.standard, defaultZoneId, subtotal);
    return {
      'items': _cartItems,
      'subtotalXof': subtotal,
      'deliveryFeeXof': deliveryFee,
      'totalXof': subtotal + deliveryFee
    };
  }

  http.StreamedResponse _json(
      http.BaseRequest request, int status, Object body) {
    final bytes = utf8.encode(jsonEncode(body));
    return http.StreamedResponse(
      Stream<List<int>>.value(bytes),
      status,
      request: request,
      headers: const {'content-type': 'application/json'},
    );
  }
}
