import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Where an order stands on the 4-step tracking bar (Reçue, Préparée,
/// En route, Livrée). Accepts the app labels (« En préparation ») and the
/// ERP codes (EN_PREPARATION, EXPEDIEE…).
class OrderStage {
  const OrderStage(this.step, this.color, this.icon);

  /// 1 Reçue, 2 Préparée, 3 En route, 4 Livrée; 0 off the bar (cancelled).
  final int step;
  final Color color;
  final IconData icon;

  static const labels = ['Reçue', 'Préparée', 'En route', 'Livrée'];

  static const _pending = Color(0xFFB45309);

  bool get cancelled => step == 0;

  factory OrderStage.of(String status) {
    final s = status.toLowerCase();
    bool has(List<String> keys) => keys.any(s.contains);
    if (has(['annul', 'cancel', 'expir', 'échou'])) {
      return const OrderStage(0, AppColors.danger, Icons.cancel_outlined);
    }
    if (has(['livr', 'deliver'])) {
      return const OrderStage(4, AppColors.success, Icons.check_circle_outline);
    }
    if (has(['route', 'expedi', 'expédi', 'retrait', 'prete', 'prête'])) {
      return const OrderStage(
          3, AppColors.primary, Icons.local_shipping_outlined);
    }
    if (has(['prepa', 'prépa'])) {
      return const OrderStage(2, _pending, Icons.schedule);
    }
    return const OrderStage(1, _pending, Icons.schedule);
  }
}

/// ERP codes (EN_PREPARATION…) shown as text; app labels kept as they are.
String orderStatusLabel(String status) =>
    const {
      'EN_ATTENTE_PAIEMENT': 'En attente de paiement',
      'PAIEMENT_A_VERIFIER': 'Paiement en vérification',
      'EN_ATTENTE_CONFIRMATION': 'Reçue',
      'CONFIRMEE': 'Confirmée',
      'EN_PREPARATION': 'En préparation',
      'PRETE_POUR_RETRAIT': 'Prête à retirer',
      'EXPEDIEE': 'En route',
      'LIVREE': 'Livrée',
      'ANNULEE': 'Annulée',
      'EXPIREE': 'Expirée',
    }[status] ??
    status;
