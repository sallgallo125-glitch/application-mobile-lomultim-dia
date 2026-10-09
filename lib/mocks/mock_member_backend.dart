import '../contracts/gift_card.dart';
import '../utils/loyalty.dart';
import 'data/content_mock_data.dart';

/// Result of a mock route: HTTP status + JSON body.
class MockResult {
  const MockResult(this.status, this.body);
  final int status;
  final Object body;
}

MockResult _ok(Object data, [int status = 200]) =>
    MockResult(status, {'data': data});
MockResult _fail(int status, String code, String message) =>
    MockResult(status, {'code': code, 'message': message});

/// Mock backend for LO+, gift cards, order tracking and content pages.
/// Data and rules mirror the site's fixtures (DevA -final/src/mocks):
/// loyalty.ts (catalogue, badges, challenges, rules), giftcard data.ts,
/// delivery.ts (tracking) and content.ts (FAQ, legal).
class MockMemberBackend {
  // ---- LO+ member state (the signed-in demo customer) ----
  int points = 68;
  final int pendingPoints = 12;
  final int spend12MonthsXof = 680000;
  int _voucherSeq = 1;
  bool _hasConverted = false;

  final List<Map<String, dynamic>> movements = [
    {
      'id': 'mv-4',
      'date': '24 septembre 2026',
      'label': 'Commande LO-2026-00142 (en attente de livraison)',
      'points': 12,
      'pending': true,
    },
    {
      'id': 'mv-3',
      'date': '12 septembre 2026',
      'label': 'Commande LO-2026-00118',
      'points': 14,
    },
    {
      'id': 'mv-2',
      'date': '2 août 2026',
      'label': 'Parrainage : Moussa N. (filleul actif)',
      'points': 50,
    },
    {
      'id': 'mv-1',
      'date': '15 juillet 2026',
      'label': 'Badge « Premier achat »',
      'points': 5,
    },
    {
      'id': 'mv-0',
      'date': '15 juillet 2026',
      'label': 'Échange : diagnostic SAV offert',
      'points': -1,
    },
  ];

  static const _catalogue = [
    {
      'id': 'CAT-001',
      'category': 'VOUCHER',
      'title': "Bon d'achat LO Multimédia",
      'description':
          'Valeur libre, valable 6 mois dans tous les points de vente et sur le site.',
      'points': 50,
      'stock': null,
      'freeValue': true,
    },
    {
      'id': 'CAT-002',
      'category': 'DELIVERY',
      'title': 'Livraison gratuite Dakar (zone 1)',
      'description': 'Une livraison à domicile offerte à Dakar (zone 1).',
      'points': 50,
      'stock': null,
    },
    {
      'id': 'CAT-003',
      'category': 'SAV',
      'title': 'Diagnostic SAV offert',
      'description': "Diagnostic d'un appareil au centre SAV, sans frais.",
      'points': 30,
      'stock': null,
    },
    {
      'id': 'CAT-004',
      'category': 'ACCESSORY',
      'title': 'Coque de protection smartphone',
      'description': 'Coque de protection renforcée, modèle au choix.',
      'points': 65,
      'stock': 40,
    },
    {
      'id': 'CAT-005',
      'category': 'ACCESSORY',
      'title': 'Chargeur rapide 25 W',
      'description': 'Chargeur USB-C rapide 25 W.',
      'points': 125,
      'stock': 25,
    },
    {
      'id': 'CAT-006',
      'category': 'ACCESSORY',
      'title': 'Écouteurs Bluetooth',
      'description': 'Écouteurs sans fil avec boîtier de charge.',
      'points': 180,
      'stock': 18,
    },
    {
      'id': 'CAT-007',
      'category': 'ACCESSORY',
      'title': 'Enceinte portable',
      'description': "Enceinte Bluetooth portable, 10 h d'autonomie.",
      'points': 350,
      'stock': 10,
    },
    {
      'id': 'CAT-008',
      'category': 'LMCARE',
      'title': 'LMCARE Essentiel 12 mois',
      'description':
          'Contrat de protection LMCARE, formule Essentiel, 12 mois.',
      'points': 350,
      'stock': null,
    },
    {
      'id': 'CAT-009',
      'category': 'LMCARE',
      'title': 'LMCARE Premium 12 mois',
      'description': 'Contrat de protection LMCARE, formule Premium, 12 mois.',
      'points': 650,
      'stock': null,
    },
    {
      'id': 'CAT-010',
      'category': 'WARRANTY',
      'title': 'Extension de garantie 1 an',
      'description':
          'Une année de garantie supplémentaire sur un produit acheté chez LO.',
      'points': 500,
      'stock': null,
    },
    {
      'id': 'CAT-011',
      'category': 'ACCESSORY',
      'title': 'Disque dur externe 1 To',
      'description': 'Disque dur externe USB 3.0, 1 To.',
      'points': 420,
      'stock': 6,
    },
    {
      'id': 'CAT-013',
      'category': 'ACCESSORY',
      'title': 'Casque gaming',
      'description': 'Casque audio avec micro pour consoles et PC.',
      'points': 300,
      'stock': 0,
    },
  ];

  static const _badges = [
    [
      'PREMIER_ACHAT',
      'Premier achat',
      'Première transaction après inscription',
      5,
      true
    ],
    [
      'PROMO_SILVER',
      'Promotion Bleu → Silver',
      'Passage au palier Silver',
      10,
      false
    ],
    [
      'PROMO_GOLD',
      'Promotion Silver → Gold',
      'Passage au palier Gold',
      25,
      false
    ],
    [
      'PROMO_PLATINUM',
      'Promotion Gold → Platinium',
      'Passage au palier Platinium',
      50,
      false
    ],
    ['PARRAIN_5', 'Parrain de 5', '5 filleuls inscrits', 20, false],
    ['PARRAIN_10', 'Parrain de 10', '10 filleuls inscrits', 50, false],
    ['STREAK_3', 'Streak 3 mois', 'Achat 3 mois consécutifs', 15, false],
    ['STREAK_6', 'Streak 6 mois', 'Achat 6 mois consécutifs', 30, false],
    ['STREAK_12', 'Streak 12 mois', 'Achat 12 mois consécutifs', 100, false],
    ['AVIS_5', 'Avis certifié ×5', '5 avis produits rédigés', 15, false],
    ['LMCARE', 'Protégé LMCARE', 'Premier contrat LMCARE souscrit', 25, false],
    [
      'ANNIVERSAIRE',
      'Joyeux anniversaire',
      "Achat le jour de son anniversaire (×5 sur cette transaction)",
      0,
      false
    ],
  ];

  List<Map<String, dynamic>> _challenges() => [
        {
          'code': 'CATS3',
          'label': 'Achetez 3 catégories différentes',
          'reward': '+15 points',
          'frequency': 'MONTHLY',
          'progress': 2,
          'target': 3,
          'unit': 'catégories',
        },
        {
          'code': 'FILLEUL1',
          'label': 'Parrainez 1 nouveau filleul',
          'reward': '+50 points',
          'frequency': 'MONTHLY',
          'progress': 0,
          'target': 1,
          'unit': 'filleul',
        },
        {
          'code': 'CONV1',
          'label': 'Convertissez vos points pour la 1ère fois',
          'reward': '+10 points',
          'frequency': 'ONCE',
          'progress': _hasConverted ? 1 : 0,
          'target': 1,
          'unit': 'conversion',
        },
        {
          'code': 'LMCARE',
          'label': 'Souscrivez un contrat LMCARE',
          'reward': '×2 points sur ce contrat',
          'frequency': 'ONCE',
          'progress': 0,
          'target': 1,
          'unit': 'contrat',
        },
        {
          'code': 'DEP500',
          'label': 'Dépensez 500 000 FCFA en un mois',
          'reward': '+30 points',
          'frequency': 'MONTHLY',
          'progress': 142000,
          'target': 500000,
          'unit': 'FCFA',
        },
      ];

  // ---- Gift cards ----
  int _giftSeq = 3;
  final List<Map<String, dynamic>> giftCards = [
    {
      'id': 'gc-1',
      'code': 'LOGC-4821-7730',
      'initialXof': 50000,
      'balanceXof': 32000,
      'status': 'ACTIVE',
      'expiresAt': '12 mars 2027',
      'recipientName': 'Aissatou Diop',
      'mine': true,
    },
    {
      'id': 'gc-2',
      'code': 'LOGC-1190-5504',
      'initialXof': 100000,
      'balanceXof': 100000,
      'status': 'ACTIVE',
      'expiresAt': '2 juin 2027',
      'recipientName': 'Fatou Sow',
      'mine': true,
    },
  ];

  Map<String, dynamic>? _card(String code) {
    final c = code.trim().toUpperCase();
    for (final card in giftCards) {
      if ((card['code'] as String).toUpperCase() == c) return card;
    }
    return null;
  }

  /// Checks a gift card for payment; returns an error result or null if OK.
  MockResult? checkGiftCard(String code, String? otp) {
    final card = _card(code);
    if (card == null) {
      return _fail(
          404, 'NOT_FOUND', 'Aucune carte cadeau ne correspond à ce code.');
    }
    if (card['status'] != 'ACTIVE') {
      return _fail(
          422, 'GIFT_CARD_INACTIVE', "Cette carte cadeau n'est pas active.");
    }
    if (otp != giftCardDemoOtp) {
      return _fail(422, 'OTP_INVALID', 'Code de confirmation incorrect.');
    }
    return null;
  }

  int giftCardBalance(String code) => (_card(code)?['balanceXof'] as int?) ?? 0;

  void debitGiftCard(String code, int amountXof, String orderNumber) {
    final card = _card(code)!;
    card['balanceXof'] = (card['balanceXof'] as int) - amountXof;
  }

  void spendPoints(int used, String orderNumber) {
    if (used <= 0) return;
    points -= used;
    movements.insert(0, {
      'id': 'mv-${DateTime.now().microsecondsSinceEpoch}',
      'date': "Aujourd'hui",
      'label': 'Paiement en points · $orderNumber',
      'points': -used,
    });
  }

  void creditPendingPoints(int earned, String orderNumber) {
    if (earned <= 0) return;
    movements.insert(0, {
      'id': 'mv-${DateTime.now().microsecondsSinceEpoch}-e',
      'date': "Aujourd'hui",
      'label': 'Commande $orderNumber (en attente de livraison)',
      'points': earned,
      'pending': true,
    });
  }

  // ---- Order tracking (site: delivery.ts trackingFixture) ----
  static const _trackingSteps = [
    ['CONFIRMED', 'Commande confirmée'],
    ['PREPARED', 'Colis préparé en entrepôt'],
    ['SHIPPED', 'En cours de livraison'],
    ['DELIVERED', 'Livré'],
  ];
  final List<Map<String, Object>> _tracking = [
    {
      'orderNumber': 'LM-2614',
      'phone': '771234567',
      'reached': 'SHIPPED',
      'at': ['Il y a 5 h 30', 'Il y a 3 h 10', 'Il y a 45 min'],
      'details': {
        'CONFIRMED': 'Paiement Wave validé',
        'PREPARED': 'Showroom Médina, Dakar',
        'SHIPPED': 'Livreur Ibrahima · +221 77 xxx xx xx',
        'DELIVERED': "Estimé aujourd'hui avant 18 h · Almadies, Dakar",
      },
    },
    {
      'orderNumber': 'LM-2598',
      'phone': '781112233',
      'reached': 'DELIVERED',
      'at': ['Il y a 2 jours', 'Il y a 2 jours', 'Hier', 'Hier'],
      'details': {
        'CONFIRMED': 'Paiement Orange Money validé',
        'PREPARED': 'Showroom Sandaga, Dakar',
        'SHIPPED': 'Livreur Moussa · +221 78 xxx xx xx',
        'DELIVERED': 'Remis en main propre · Thiès',
      },
    },
    {
      'orderNumber': 'LM-2631',
      'phone': '701234567',
      'reached': 'CONFIRMED',
      'at': ['Il y a 20 min'],
      'details': {
        'CONFIRMED': 'Paiement carte bancaire validé',
        'PREPARED': 'Préparation prévue sous 2 h',
        'SHIPPED': 'Départ prévu demain matin',
        'DELIVERED': 'Estimé demain · Saint-Louis',
      },
    },
  ];

  /// Handles the routes this backend owns; null if [path] isn't one of them.
  MockResult? handle(String method, String path, Map<String, dynamic> body) {
    // LO+
    if (method == 'GET' && path == '/api/v1/loyalty/me') {
      return _ok({
        'cardNumber': '2026 0417 3320',
        'holderName': 'Aissatou Diop',
        'tierCode': 'BLEU',
        'points': points,
        'pendingPoints': pendingPoints,
        'spend12MonthsXof': spend12MonthsXof,
      });
    }
    if (method == 'POST' && path == '/api/v1/loyalty/me/qr') {
      final expires = DateTime.now().add(const Duration(minutes: 5));
      return _ok({
        'token': 'LOPLUS-20260417-3321-${expires.millisecondsSinceEpoch}',
        'expiresAt': expires.toIso8601String(),
      });
    }
    if (method == 'GET' && path == '/api/v1/loyalty/me/movements') {
      return _ok(movements);
    }
    if (method == 'GET' && path == '/api/v1/loyalty/me/exchange') {
      return _ok(_catalogue);
    }
    if (method == 'POST' && path == '/api/v1/loyalty/me/conversions') {
      return _convert(body);
    }
    if (method == 'GET' && path == '/api/v1/loyalty/me/referrals') {
      return _ok({
        'code': 'AISSA-LO26',
        'referrerPoints': 50,
        'refereePoints': 20,
        'minPurchaseXof': 100000,
        'referrals': [
          {'name': 'Moussa N.', 'status': 'ACTIVE', 'points': 50},
          {'name': 'Khady F.', 'status': 'PENDING', 'points': 0},
        ],
      });
    }
    if (method == 'GET' && path == '/api/v1/loyalty/me/challenges') {
      return _ok({
        'challenges': _challenges(),
        'badges': [
          for (final b in _badges)
            {
              'code': b[0],
              'label': b[1],
              'condition': b[2],
              'points': b[3],
              'earned': b[4],
            }
        ],
      });
    }

    // Gift cards
    if (method == 'GET' && path == '/api/v1/gift-cards/mine') {
      return _ok(giftCards.where((c) => c['mine'] == true).toList());
    }
    if (method == 'POST' && path == '/api/v1/gift-cards') {
      return _buyGiftCard(body);
    }
    final suspend =
        RegExp(r'^/api/v1/gift-cards/mine/([^/]+)/(suspension|reactivation)$')
            .firstMatch(path);
    if (method == 'POST' && suspend != null) {
      final card =
          giftCards.where((c) => c['id'] == suspend.group(1)).firstOrNull;
      if (card == null) return _fail(404, 'NOT_FOUND', 'Carte introuvable.');
      card['status'] =
          suspend.group(2) == 'suspension' ? 'SUSPENDED' : 'ACTIVE';
      return _ok(card);
    }
    final balance =
        RegExp(r'^/api/v1/gift-cards/([^/]+)/balance$').firstMatch(path);
    if (method == 'GET' && balance != null) {
      final card = _card(Uri.decodeComponent(balance.group(1)!));
      if (card == null) {
        return _fail(
            404, 'NOT_FOUND', 'Aucune carte cadeau ne correspond à ce code.');
      }
      return _ok({
        'code': card['code'],
        'balanceXof': card['balanceXof'],
        'status': card['status'],
        'expiresAt': card['expiresAt'],
      });
    }

    // Order tracking
    if (method == 'POST' && path == '/api/v1/delivery/tracking') {
      return _track(body);
    }

    // Content
    if (method == 'GET' && path == '/api/v1/content/faq') return _ok(mockFaqs);
    if (method == 'GET' && path == '/api/v1/content/legal') {
      return _ok([
        for (final d in mockLegalDocuments)
          {'slug': d['slug'], 'title': d['title'], 'updatedAt': d['updatedAt']}
      ]);
    }
    final legal = RegExp(r'^/api/v1/content/legal/([^/]+)$').firstMatch(path);
    if (method == 'GET' && legal != null) {
      final doc = mockLegalDocuments
          .where((d) => d['slug'] == legal.group(1))
          .firstOrNull;
      return doc == null
          ? _fail(404, 'NOT_FOUND', 'Page introuvable.')
          : _ok(doc);
    }
    return null;
  }

  MockResult _convert(Map<String, dynamic> body) {
    final reward =
        _catalogue.where((r) => r['id'] == body['rewardId']).firstOrNull;
    if (reward == null)
      return _fail(404, 'NOT_FOUND', 'Récompense introuvable.');
    if (reward['stock'] == 0) {
      return _fail(422, 'OUT_OF_STOCK', 'Cette récompense est épuisée.');
    }
    final freeValue = reward['freeValue'] == true;
    final cost = freeValue
        ? (body['points'] as num?)?.toInt() ?? (reward['points'] as int)
        : reward['points'] as int;
    if (cost < (reward['points'] as int)) {
      return _fail(422, 'BELOW_MINIMUM', 'Minimum ${reward['points']} points.');
    }
    if (cost > points) {
      return _fail(422, 'INSUFFICIENT_POINTS', 'Solde de points insuffisant.');
    }
    points -= cost;
    final code = 'BON-${(1000 + _voucherSeq++).toString()}';
    movements.insert(0, {
      'id': 'mv-${DateTime.now().microsecondsSinceEpoch}',
      'date': "Aujourd'hui",
      'label': 'Échange : ${reward['title']}',
      'points': -cost,
    });
    if (!_hasConverted) {
      _hasConverted = true;
      points += 10; // CONV1 challenge reward
      movements.insert(0, {
        'id': 'mv-${DateTime.now().microsecondsSinceEpoch}-c',
        'date': "Aujourd'hui",
        'label': 'Défi : première conversion de points',
        'points': 10,
      });
    }
    return _ok({
      'code': code,
      'title': reward['title'],
      'pointsSpent': cost,
      if (freeValue) 'valueXof': cost * loyaltyPointValueXof,
      'validUntil': 'Valable 6 mois',
    }, 201);
  }

  MockResult _buyGiftCard(Map<String, dynamic> body) {
    final amount = (body['amountXof'] as num?)?.toInt() ?? 0;
    if (amount < giftCardMinXof ||
        amount > giftCardMaxXof ||
        amount % giftCardStepXof != 0) {
      return _fail(422, 'INVALID_AMOUNT',
          'Montant entre 5 000 et 1 000 000 FCFA, par multiples de 1 000.');
    }
    final recipient = (body['recipientName'] as String? ?? '').trim();
    if (recipient.length < 2) {
      return _fail(422, 'VALIDATION_ERROR', 'Indiquez le nom du bénéficiaire.');
    }
    final guest = body.containsKey('buyerName');
    if (guest) {
      final buyer = (body['buyerName'] as String? ?? '').trim();
      final phone =
          (body['buyerPhone'] as String? ?? '').replaceAll(RegExp(r'\D'), '');
      if (buyer.length < 2 || phone.length < 9) {
        return _fail(422, 'BUYER_REQUIRED',
            'Indiquez votre nom et votre téléphone (acheteur).');
      }
    }
    _giftSeq++;
    final card = {
      'id': 'gc-$_giftSeq',
      'code':
          'LOGC-${(3000 + _giftSeq * 137) % 9000 + 1000}-${(5000 + _giftSeq * 911) % 9000 + 1000}',
      'initialXof': amount,
      'balanceXof': amount,
      'status': 'ACTIVE',
      'expiresAt': 'Dans 12 mois',
      'recipientName': recipient,
      // Guest cards are not attached to the demo member's account.
      'mine': !guest,
    };
    giftCards.add(card);
    return _ok(card, 201);
  }

  /// Makes a new order trackable (number + last 9 digits of the phone).
  void registerTracking(
      String orderNumber, String phone, String payment, String delivery) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    _tracking.add({
      'orderNumber': orderNumber.toUpperCase(),
      'phone': digits.length > 9 ? digits.substring(digits.length - 9) : digits,
      'reached': 'CONFIRMED',
      'at': ['À l’instant'],
      'details': {
        'CONFIRMED': 'Commande reçue · $payment',
        'PREPARED': 'Préparation prévue sous 4 h',
        'SHIPPED': delivery,
        'DELIVERED': 'Estimé sous 24 à 48 h',
      },
    });
  }

  MockResult _track(Map<String, dynamic> body) {
    final number = (body['orderNumber'] as String? ?? '').trim().toUpperCase();
    final digits =
        (body['phone'] as String? ?? '').replaceAll(RegExp(r'\D'), '');
    final phone =
        digits.length > 9 ? digits.substring(digits.length - 9) : digits;
    if (number.isEmpty || phone.length != 9) {
      return _fail(
          422, 'VALIDATION_ERROR', 'Numéro de commande et téléphone requis.');
    }
    final order = _tracking
        .where((o) => o['orderNumber'] == number && o['phone'] == phone)
        .firstOrNull;
    if (order == null) {
      return _fail(404, 'NOT_FOUND',
          'Aucune commande ne correspond à ce numéro et ce téléphone.');
    }
    final reachedIndex =
        _trackingSteps.indexWhere((s) => s[0] == order['reached']);
    final at = (order['at'] as List).cast<String>();
    final details = (order['details'] as Map).cast<String, String>();
    return _ok({
      'orderNumber': order['orderNumber'],
      'status': order['reached'],
      'steps': [
        for (var i = 0; i < _trackingSteps.length; i++)
          {
            'code': _trackingSteps[i][0],
            'label': _trackingSteps[i][1],
            'detail': details[_trackingSteps[i][0]],
            'reached': i <= reachedIndex,
            if (i <= reachedIndex && i < at.length) 'at': at[i],
          }
      ],
    });
  }
}
