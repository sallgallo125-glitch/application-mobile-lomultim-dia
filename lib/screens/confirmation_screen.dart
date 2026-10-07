import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../contracts/account.dart';
import '../theme/tokens.dart';
import '../utils/currency.dart';
import '../utils/delivery.dart';
import '../widgets/app_header.dart';
import '../widgets/confetti.dart';
import 'package:url_launcher/url_launcher.dart';

class ConfirmationScreen extends StatelessWidget {
  const ConfirmationScreen({super.key, required this.order});

  final OrderSummary? order;

  @override
  Widget build(BuildContext context) {
    final orderData = order;
    final firstName = orderData == null ? '' : _firstname(orderData);
    return Scaffold(
      backgroundColor: AppColors.background,
      // Celebrate the order with a one-shot confetti burst.
      body: ConfettiOverlay(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              AppHeader(
                title: 'Commande confirmée',
                onBack: () =>
                    context.canPop() ? context.pop() : context.go('/'),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: const BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check,
                              color: Colors.white, size: 32),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Merci $firstName\u{00A0}!',
                                style: const TextStyle(
                                  color: AppColors.text,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                orderData == null
                                    ? 'Votre commande est enregistrée.'
                                    : 'Votre commande ${orderData.number} est enregistrée. Un conseiller vous confirme la livraison par WhatsApp.',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          children: [
                            _summaryRow('Numéro', orderData?.number ?? '—'),
                            _summaryRow(
                                'Livraison',
                                orderData?.deliveryMethodCode == null
                                    ? '—'
                                    : DeliveryMethod.fromCode(
                                            orderData!.deliveryMethodCode)
                                        .label),
                            _summaryRow(
                                'Paiement',
                                PaymentMethod.fromCode(orderData?.paymentMethod)
                                        ?.label ??
                                    '—'),
                            // Guests have no LO+ account: no points.
                            if (orderData != null && !orderData.guest)
                              _summaryRow(
                                'Points LO+ crédités',
                                '+${orderData.pointsToEarn} pts',
                                accent: AppColors.success,
                              ),
                            const SizedBox(height: AppSpacing.xs),
                            const Divider(),
                            _summaryRow(
                                'Total',
                                orderData == null
                                    ? '—'
                                    : formatXof(orderData.totalXof),
                                bold: true),
                            if (orderData != null &&
                                orderData.pointsDiscountXof > 0)
                              _summaryRow('Payé en points',
                                  '−${formatXof(orderData.pointsDiscountXof)}',
                                  accent: AppColors.success),
                            if (orderData != null &&
                                orderData.giftCardAppliedXof > 0)
                              _summaryRow('Carte cadeau',
                                  '−${formatXof(orderData.giftCardAppliedXof)}',
                                  accent: AppColors.success),
                            if (orderData != null &&
                                (PaymentMethod.fromCode(orderData.paymentMethod)
                                        ?.isOnline ??
                                    false))
                              _summaryRow(
                                  'Payé par ${PaymentMethod.fromCode(orderData.paymentMethod)!.label}',
                                  formatXof(orderData.amountDueXof),
                                  bold: true,
                                  accent: AppColors.success)
                            else if (orderData != null &&
                                orderData.amountDueXof != orderData.totalXof)
                              _summaryRow('Reste à payer',
                                  formatXof(orderData.amountDueXof),
                                  bold: true),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Text(
                      'Suivi de la commande',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _TrackingTimeline(
                      steps: const [
                        _TrackingStep('Commande reçue', "Aujourd'hui", true),
                        _TrackingStep(
                            'Paiement confirmé', 'Sous 30 min', false),
                        _TrackingStep(
                            'Préparation en atelier', 'Sous 4 h', false),
                        _TrackingStep(
                            'En cours de livraison', 'Demain matin', false),
                        _TrackingStep('Livrée', '24 – 48 h', false),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (orderData != null && orderData.guest) ...[
                      _GuestAccountCard(order: orderData),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: orderData == null
                            ? null
                            : () => launchUrl(
                                Uri.parse(
                                    'https://wa.me/221779980404?text=${Uri.encodeComponent('Bonjour, je souhaite suivre ma commande ${orderData.number}.')}'),
                                mode: LaunchMode.externalApplication),
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: const Text('Suivre sur WhatsApp'),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      width: double.infinity,
                      // Guests track by order number + phone; members see
                      // their order history.
                      child: OutlinedButton(
                        onPressed: () => orderData != null && orderData.guest
                            ? context.push(
                                '/suivi?commande=${Uri.encodeComponent(orderData.number)}&tel=${Uri.encodeComponent(orderData.phone ?? '')}')
                            : context.push('/commandes'),
                        child: Text(orderData != null && orderData.guest
                            ? 'Suivre ma commande'
                            : 'Voir mes commandes'),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => context.go('/'),
                        child: const Text("Retour à l'accueil"),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _firstname(OrderSummary order) {
    final parts = order.number.split(' ');
    return parts.isNotEmpty ? parts.first : '';
  }

  Widget _summaryRow(String label, String value,
      {Color? accent, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 13))),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: accent ?? AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackingStep {
  const _TrackingStep(this.title, this.time, this.done);
  final String title;
  final String time;
  final bool done;
}

class _TrackingTimeline extends StatelessWidget {
  const _TrackingTimeline({required this.steps});

  final List<_TrackingStep> steps;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          _Tile(
              step: steps[i],
              index: i + 1,
              first: i == 0,
              last: i == steps.length - 1),
          if (i < steps.length - 1) const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(
      {required this.step,
      required this.index,
      required this.first,
      required this.last});

  final _TrackingStep step;
  final int index;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final color = step.done ? AppColors.success : AppColors.border;
    final circleColor = step.done ? AppColors.success : Colors.white;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: circleColor,
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
              ),
              child: Center(
                child: step.done
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : Text('$index',
                        style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w800)),
              ),
            ),
            if (!last)
              Container(
                width: 2,
                height: 36,
                color: step.done ? AppColors.success : AppColors.border,
              ),
          ],
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(step.title,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w700)),
                Text(step.time,
                    style: const TextStyle(
                        fontSize: 11.5, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Guest order: keep the number, and an invitation to create an account to
/// earn the LO+ points this order would have given.
class _GuestAccountCard extends StatelessWidget {
  const _GuestAccountCard({required this.order});
  final OrderSummary order;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.receipt_long_outlined,
                color: AppColors.primaryDark),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text('Notez votre numéro : ${order.number}',
                  style: const TextStyle(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w800)),
            ),
          ]),
          const SizedBox(height: AppSpacing.xs),
          const Text(
              'Avec ce numéro et votre téléphone, vous pouvez suivre votre '
              'commande à tout moment, sans compte.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          if (order.pointsIfMemberXof > 0) ...[
            const Divider(height: AppSpacing.xl),
            Text(
                'Avec un compte LO+, cette commande vous aurait rapporté '
                '${order.pointsIfMemberXof} points.',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.push('/inscription'),
                child: const Text('Créer mon compte gratuitement'),
              ),
            ),
          ],
        ]),
      );
}
