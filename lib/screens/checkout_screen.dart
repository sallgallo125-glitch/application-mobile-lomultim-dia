import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../contracts/cart.dart';
import '../features/account/account_providers.dart';
import '../features/cart/cart_providers.dart';
import '../features/checkout/checkout_providers.dart';
import '../features/member/member_providers.dart';
import '../contracts/gift_card.dart';
import '../theme/tokens.dart';
import '../utils/currency.dart';
import '../utils/delivery.dart';
import '../utils/loyalty.dart';
import '../widgets/app_header.dart';
import '../widgets/commerce/product_image.dart';
import '../widgets/error_state.dart';
import '../widgets/loading_state.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});
  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  DeliveryMethod delivery = DeliveryMethod.standard;
  String zoneId = defaultZoneId;
  PaymentMethod payment = PaymentMethod.cashOnDelivery;
  final address = TextEditingController();
  final name = TextEditingController();
  final phone = TextEditingController();
  // Pre-filled with the code entered in the cart.
  // Touched in initState: otherwise this lazy field is first built in
  // dispose() when the promo section was never opened, reading `ref` too late.
  late final TextEditingController promo =
      TextEditingController(text: ref.read(cartPromoCodeProvider));

  /// Promo code the customer applied (checked by [calculateCheckoutTotals]).
  late String appliedPromo = ref.read(cartPromoCodeProvider);

  /// LO+ points the customer chose to spend (1 point = 100 FCFA, 10 minimum).
  int pointsToUse = 0;

  // Amounts of the last build, for the payment dialog: total, then what the
  // points and the gift card cover, and the rest paid with [payment].
  int _totalXof = 0;
  int _usedPoints = 0;
  int _pointsDiscountXof = 0;
  int _giftAppliedXof = 0;
  int _amountDueXof = 0;

  /// Gift card applied after a successful balance check.
  final giftCode = TextEditingController();
  final giftOtp = TextEditingController();
  String? appliedGiftCode;
  int giftBalanceXof = 0;
  String? giftError;
  String? error;
  bool sending = false;

  /// Field errors are shown once the customer tried to continue.
  bool _showFieldErrors = false;

  /// "Vous avez un code promo ou une carte cadeau ?" opened.
  bool _showCodes = false;

  /// 0 = Livraison, 1 = Paiement, 2 = Récapitulatif (same steps as the site).
  int step = 0;

  static const _stepLabels = ['Livraison', 'Paiement', 'Récapitulatif'];

  String? get _nameError =>
      name.text.trim().length < 2 ? 'Indiquez votre nom complet.' : null;
  String? get _phoneError => phone.text.replaceAll(RegExp(r'\D'), '').length < 9
      ? 'Numéro WhatsApp incomplet (9 chiffres).'
      : null;
  String? get _addressError => _needsAddress && address.text.trim().length < 5
      ? 'Indiquez votre adresse de livraison.'
      : null;

  /// Checks the delivery step; returns the first error or null.
  String? _deliveryError() => _nameError ?? _phoneError ?? _addressError;

  void _next() {
    if (step == 0 && _deliveryError() != null) {
      // Errors appear under the fields concerned.
      setState(() => _showFieldErrors = true);
      return;
    }
    setState(() {
      error = null;
      step++;
    });
  }

  void _back() {
    if (step > 0) {
      setState(() {
        error = null;
        step--;
      });
    } else {
      context.pop();
    }
  }

  @override
  void initState() {
    super.initState();
    promo; // Builds the controller while `ref` is still usable.
    final user = ref.read(sessionUserProvider);
    if (user != null) {
      name.text = user.name;
      phone.text = user.phone;
      // Address and zone of this account's last order.
      final last = ref.read(lastDeliveryProvider(user.phone));
      if (last != null) {
        address.text = last.address;
        // Only a zone that still exists (else the dropdown would throw).
        if (deliveryZones.any((z) => z.id == last.zoneId)) {
          zoneId = last.zoneId;
        }
      }
    } else {
      // Guest: details of their previous order, if any.
      final guest = ref.read(guestContactProvider);
      if (guest != null) {
        name.text = guest.name;
        phone.text = guest.phone;
        address.text = guest.address ?? '';
      }
    }
    // "Utiliser mes points" chosen in the cart: start with the maximum
    // (clamped to the balance and the order total below).
    if (ref.read(usePointsFromCartProvider)) pointsToUse = 1 << 30;
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    address.dispose();
    promo.dispose();
    giftCode.dispose();
    giftOtp.dispose();
    super.dispose();
  }

  bool get _needsAddress => delivery != DeliveryMethod.pickup;

  Future<bool> _confirmOnlinePayment() async {
    final number = phone.text.trim();
    final (title, body, asset, icon) = switch (payment) {
      PaymentMethod.wave => (
          'Paiement Wave',
          'Une demande de paiement va être envoyée au $number. Ouvrez Wave '
              'et validez-la pour confirmer votre commande.',
          'assets/paiement/wave.png',
          Icons.waves,
        ),
      PaymentMethod.orangeMoney => (
          'Paiement Orange Money',
          'Vous allez recevoir une demande sur le $number. Validez-la avec '
              'votre code secret Orange Money (ou composez #144#).',
          'assets/paiement/orange-money.png',
          Icons.phone_android,
        ),
      PaymentMethod.freeMoney => (
          'Paiement Free Money',
          'Vous allez recevoir une demande sur le $number. Validez-la avec '
              'votre code secret Free Money (ou composez #150#).',
          'assets/paiement/free-money.png',
          Icons.phone_android,
        ),
      _ => (
          'Paiement par carte',
          'Vous allez être redirigé vers la page de paiement sécurisée de la '
              'banque (Visa, Mastercard).',
          'assets/paiement/Icône_de_carte_bancaire_moderne-removebg-preview.png',
          Icons.credit_card,
        ),
    };
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: asset != null
            ? Center(
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                    child: Image.asset(asset,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover),
                  ),
                ),
              )
            : Icon(icon, color: AppColors.primary, size: 36),
        title: Text(title),
        content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Montant à payer avec ${payment.label} : '
                  '${formatXof(_amountDueXof)}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800)),
              // What the points / gift card already cover.
              if (_pointsDiscountXof > 0 || _giftAppliedXof > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                      '(Total ${formatXof(_totalXof)}'
                      '${_pointsDiscountXof > 0 ? ' − $_usedPoints points LO+ (${formatXof(_pointsDiscountXof)})' : ''}'
                      '${_giftAppliedXof > 0 ? ' − carte cadeau ${formatXof(_giftAppliedXof)}' : ''})',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
                ),
              const SizedBox(height: AppSpacing.md),
              Text('$body\n\nMode démonstration : aucun montant n’est '
                  'réellement débité.'),
            ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Payer ${formatXof(_amountDueXof)}')),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> submit() async {
    final invalid = _deliveryError();
    if (invalid != null) {
      setState(() {
        _showFieldErrors = true;
        step = 0;
      });
      return;
    }
    // Wave / Orange Money / card: the customer confirms the payment first
    // (simulated until the operators' real APIs are connected).
    // Nothing left to pay (points / gift card cover it all): no dialog.
    if (payment.isOnline &&
        _amountDueXof > 0 &&
        !await _confirmOnlinePayment()) {
      return;
    }
    setState(() {
      sending = true;
      error = null;
    });
    try {
      final order = await ref.read(checkoutActionsProvider).create(
          deliveryMethod: delivery.code,
          zoneId: zoneId,
          payment: payment.code,
          promoCode: appliedPromo,
          // The points actually used (clamped to the balance and the
          // total), not the "maximum" placeholder from the cart.
          pointsToUse: _usedPoints,
          giftCardCode: appliedGiftCode,
          giftCardOtp: appliedGiftCode == null ? null : giftOtp.text.trim(),
          name: name.text.trim(),
          phone: phone.text.trim(),
          address: _needsAddress ? address.text.trim() : null);
      if (mounted) context.go('/commande/confirmation', extra: order);
    } catch (e) {
      if (mounted)
        setState(() => error =
            errorMessage(e, 'Impossible de confirmer la commande. Réessayez.'));
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> _applyGiftCard() async {
    final code = giftCode.text.trim();
    if (code.isEmpty) return;
    if (giftOtp.text.trim().length != 6) {
      setState(
          () => giftError = 'Saisissez le code à 6 chiffres reçu par SMS.');
      return;
    }
    setState(() => giftError = null);
    try {
      final b = await ref.read(giftCardRepositoryProvider).checkBalance(code);
      if (!mounted) return;
      if (b.status != 'ACTIVE') {
        setState(() => giftError = "Cette carte cadeau n'est pas active.");
        return;
      }
      setState(() {
        appliedGiftCode = b.code;
        giftBalanceXof = b.balanceXof;
      });
    } catch (e) {
      if (mounted) {
        setState(
            () => giftError = errorMessage(e, 'Carte cadeau introuvable.'));
      }
    }
  }

  static const _sectionTitle =
      TextStyle(fontSize: 15, fontWeight: FontWeight.w800);

  Widget _buildCartContent(Cart value) {
    if (value.items.isEmpty) {
      return const Center(child: Text('Votre panier est vide.'));
    }
    final totals = calculateCheckoutTotals(
        value.subtotalXof, delivery, zoneId, appliedPromo);
    final zone = deliveryZones.firstWhere((z) => z.id == zoneId);
    // Same order as the server: points first, then the gift card.
    final availablePoints = ref.watch(loyaltyMemberProvider).value?.points ?? 0;
    final maxPoints = redeemablePoints(availablePoints, totals.totalXof);
    final usedPoints = pointsToUse.clamp(0, maxPoints).toInt();
    final pointsDiscount = usedPoints * loyaltyPointValueXof;
    final afterPoints = totals.totalXof - pointsDiscount;
    final giftApplied = appliedGiftCode == null
        ? 0
        : (giftBalanceXof < afterPoints ? giftBalanceXof : afterPoints);
    final amountDue = afterPoints - giftApplied;
    _totalXof = totals.totalXof;
    _usedPoints = usedPoints;
    _pointsDiscountXof = pointsDiscount;
    _giftAppliedXof = giftApplied;
    _amountDueXof = amountDue;
    // Price of each delivery mode for this cart and zone.
    String feeLabel(DeliveryMethod m) {
      if (m == DeliveryMethod.pickup) return 'Gratuit';
      final fee = calculateCheckoutTotals(value.subtotalXof, m, zoneId, '')
          .deliveryFeeXof;
      return fee == 0 ? 'Offerte' : formatXof(fee);
    }

    InputDecoration field(String label, IconData icon,
            {String? hint, String? prefix, String? error}) =>
        InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, size: 20, color: AppColors.primaryDark),
          prefixText: prefix,
          errorText: _showFieldErrors ? error : null,
          border: const OutlineInputBorder(),
        );

    final deliveryStep = <Widget>[
      const Text('Vos coordonnées', style: _sectionTitle),
      const SizedBox(height: AppSpacing.sm),
      TextField(
          controller: name,
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => _showFieldErrors ? setState(() {}) : null,
          decoration:
              field('Nom complet', Icons.person_outline, error: _nameError)),
      const SizedBox(height: AppSpacing.md),
      TextField(
          controller: phone,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          onChanged: (_) => _showFieldErrors ? setState(() {}) : null,
          decoration: field('Téléphone WhatsApp', Icons.phone_outlined,
              prefix: '+221 ', hint: '77 123 45 67', error: _phoneError)),
      const SizedBox(height: AppSpacing.md),
      if (_needsAddress) ...[
        TextField(
            controller: address,
            maxLines: 2,
            onChanged: (_) => _showFieldErrors ? setState(() {}) : null,
            decoration: field('Adresse de livraison', Icons.place_outlined,
                hint: 'Quartier, rue, point de repère', error: _addressError)),
        const SizedBox(height: AppSpacing.md),
      ],
      const SizedBox(height: AppSpacing.sm),
      const Text('Mode de livraison', style: _sectionTitle),
      const SizedBox(height: AppSpacing.sm),
      for (final method in DeliveryMethod.values) ...[
        _RadioOption<DeliveryMethod>(
          value: method,
          group: delivery,
          onChanged: (v) => setState(() => delivery = v),
          title: method.label,
          subtitle: method == DeliveryMethod.standard
              ? (value.subtotalXof >= freeDeliveryThresholdXof
                  ? zone.label
                  : '${zone.label} · offerte dès ${formatXof(freeDeliveryThresholdXof)}')
              : method == DeliveryMethod.pickup
                  ? 'Showroom Médina ou Sandaga'
                  : zone.label,
          badge: switch (method) {
            DeliveryMethod.standard => '24 – 72 h',
            DeliveryMethod.express => 'Sous 4 h',
            DeliveryMethod.pickup => 'Prêt en 2 h',
          },
          trailing: feeLabel(method),
          icon: switch (method) {
            DeliveryMethod.standard => Icons.local_shipping_outlined,
            DeliveryMethod.express => Icons.bolt,
            DeliveryMethod.pickup => Icons.storefront_outlined,
          },
          selected: delivery == method,
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
      if (_needsAddress) ...[
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<String>(
            initialValue: zoneId,
            isExpanded: true,
            decoration: const InputDecoration(
                labelText: 'Zone de livraison',
                prefixIcon: Icon(Icons.map_outlined,
                    size: 20, color: AppColors.primaryDark),
                border: OutlineInputBorder()),
            items: [
              for (final z in deliveryZones)
                DropdownMenuItem(
                    value: z.id,
                    child: Text('${z.label} · ${formatXof(z.standardFeeXof)}',
                        overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) {
              if (v != null) setState(() => zoneId = v);
            }),
      ],
    ];
    final hasCodes =
        totals.promoStatus == PromoStatus.applied || appliedGiftCode != null;
    Widget groupTitle(String text) => Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: 6),
          child: Text(text.toUpperCase(),
              style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .6)),
        );
    final mobileMoney = PaymentMethod.values
        .where((m) => m.isOnline && m != PaymentMethod.card)
        .toList();
    final paymentStep = <Widget>[
      const Text('Moyen de paiement', style: _sectionTitle),
      groupTitle('Mobile money'),
      // Mobile money as logo tiles: customers recognise the brand first.
      Row(children: [
        for (var i = 0; i < mobileMoney.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _PayTile(
              label: mobileMoney[i].label,
              asset: _paymentAsset(mobileMoney[i])!,
              selected: payment == mobileMoney[i],
              enabled: mobileMoney[i].available,
              onTap: () => setState(() => payment = mobileMoney[i]),
            ),
          ),
        ],
      ]),
      if (mobileMoney.contains(payment))
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: Row(children: [
            const Icon(Icons.info_outline, size: 16, color: AppColors.primary),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
                child: Text(payment.description,
                    style: AppText.caption.copyWith(color: AppColors.text))),
          ]),
        ),
      const SizedBox(height: AppSpacing.xs),
      groupTitle('Autres moyens'),
      // Same tiles and size as mobile money (3-column grid, 2 used).
      Row(children: [
        for (final (i, method)
            in [PaymentMethod.card, PaymentMethod.cashOnDelivery].indexed) ...[
          if (i > 0) const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _PayTile(
              label: method == PaymentMethod.cashOnDelivery
                  ? 'À la livraison'
                  : method.label,
              asset: _paymentAsset(method)!,
              selected: payment == method,
              enabled: method.available,
              onTap: () => setState(() => payment = method),
            ),
          ),
        ],
        const SizedBox(width: AppSpacing.sm),
        const Expanded(child: SizedBox.shrink()),
      ]),
      if (payment == PaymentMethod.card ||
          payment == PaymentMethod.cashOnDelivery)
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: Row(children: [
            const Icon(Icons.info_outline, size: 16, color: AppColors.primary),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
                child: Text(payment.description,
                    style: AppText.caption.copyWith(color: AppColors.text))),
          ]),
        ),
      if (ref.watch(signedInProvider) && availablePoints > 0) ...[
        const SizedBox(height: AppSpacing.lg),
        const Text('Payer avec mes points LO+', style: _sectionTitle),
        Text(
            '$availablePoints points disponibles · 1 point = ${formatXof(loyaltyPointValueXof)}',
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        if (maxPoints > 0)
          Slider(
              value: usedPoints.toDouble(),
              max: maxPoints.toDouble(),
              min: 0,
              divisions: maxPoints,
              label: '$usedPoints pts',
              // Below the 10-point minimum means no points at all.
              onChanged: (v) => setState(() => pointsToUse =
                  v.round() < loyaltyMinRedeemPoints ? 0 : v.round())),
        Text(usedPoints == 0
            ? 'Aucun point utilisé'
            : '$usedPoints points utilisés = −${formatXof(pointsDiscount)}'),
        const SizedBox(height: AppSpacing.xs),
        // The rest goes to the chosen payment method.
        Text(
            amountDue == 0
                ? 'Commande entièrement payée avec vos points'
                : 'Reste à payer avec ${payment.label} : ${formatXof(amountDue)}',
            style: const TextStyle(
                color: AppColors.primary, fontWeight: FontWeight.w800)),
      ],
      const SizedBox(height: AppSpacing.md),
      // Promo code and gift card are folded: few customers have one.
      Material(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.md),
          onTap: () => setState(() => _showCodes = !_showCodes),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(children: [
              const Icon(Icons.local_offer_outlined,
                  size: 20, color: AppColors.primaryDark),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                    hasCodes
                        ? 'Code promo / carte cadeau appliqué'
                        : 'Vous avez un code promo ou une carte cadeau ?',
                    style: const TextStyle(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w700)),
              ),
              Icon(
                  _showCodes || hasCodes
                      ? Icons.expand_less
                      : Icons.expand_more,
                  color: AppColors.primaryDark),
            ]),
          ),
        ),
      ),
      if (_showCodes || hasCodes) ...[
        const SizedBox(height: AppSpacing.md),
        const Text('Code promo', style: _sectionTitle),
        const SizedBox(height: AppSpacing.sm),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: TextField(
                  controller: promo,
                  textCapitalization: TextCapitalization.characters,
                  onSubmitted: (v) => setState(() => appliedPromo = v),
                  decoration: const InputDecoration(
                      hintText: 'Entrez votre code promo',
                      border: OutlineInputBorder(),
                      isDense: true))),
          const SizedBox(width: AppSpacing.sm),
          OutlinedButton(
              onPressed: () => setState(() => appliedPromo = promo.text),
              child: const Text('Appliquer')),
        ]),
        if (totals.promoStatus != PromoStatus.notProvided)
          Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                  totals.promoStatus == PromoStatus.applied
                      ? 'Code appliqué : −10 % sur vos articles'
                      : 'Code invalide ou expiré',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: totals.promoStatus == PromoStatus.applied
                          ? AppColors.success
                          : AppColors.danger))),
        const SizedBox(height: AppSpacing.lg),
        const SizedBox(height: AppSpacing.lg),
        const Text('Carte cadeau', style: _sectionTitle),
        const SizedBox(height: AppSpacing.sm),
        if (appliedGiftCode != null)
          Card(
            child: ListTile(
              leading:
                  const Icon(Icons.card_giftcard, color: AppColors.primary),
              title: Text(appliedGiftCode!),
              subtitle: Text(
                  'Solde ${formatXof(giftBalanceXof)} · −${formatXof(giftApplied)} sur cette commande'),
              trailing: IconButton(
                  tooltip: 'Retirer',
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() {
                        appliedGiftCode = null;
                        giftBalanceXof = 0;
                      })),
            ),
          )
        else ...[
          TextField(
              controller: giftCode,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                  labelText: 'Code de la carte cadeau',
                  hintText: 'LOGC-XXXX-XXXX',
                  border: OutlineInputBorder(),
                  isDense: true)),
          const SizedBox(height: AppSpacing.sm),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                child: TextField(
                    controller: giftOtp,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: const InputDecoration(
                        labelText: 'Code reçu par SMS',
                        helperText: 'Démo : $giftCardDemoOtp',
                        counterText: '',
                        border: OutlineInputBorder(),
                        isDense: true))),
            const SizedBox(width: AppSpacing.sm),
            OutlinedButton(
                onPressed: _applyGiftCard, child: const Text('Appliquer')),
          ]),
          if (giftError != null)
            Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(giftError!,
                    style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 12,
                        fontWeight: FontWeight.w700))),
        ],
      ],
    ];
    final reviewStep = <Widget>[
      _ReviewSection(
          title: 'Livraison',
          onEdit: () => setState(() => step = 0),
          lines: [
            delivery.label,
            if (delivery != DeliveryMethod.pickup) zone.label,
            '${name.text.trim()} · ${phone.text.trim()}',
            if (_needsAddress) address.text.trim(),
          ]),
      _ReviewSection(
          title: 'Paiement',
          onEdit: () => setState(() => step = 1),
          lines: [
            payment.label,
            if (totals.promoStatus == PromoStatus.applied)
              'Code promo ${appliedPromo.trim().toUpperCase()}',
            if (usedPoints > 0) '$usedPoints points LO+',
            if (appliedGiftCode != null) 'Carte cadeau $appliedGiftCode',
          ]),
      _ReviewItems(items: value.items),
      const SizedBox(height: AppSpacing.sm),
      Card(
          child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(children: [
                _line('Sous-total', formatXof(totals.subtotalXof)),
                if (totals.promoDiscountXof > 0)
                  _line('Code promo', '−${formatXof(totals.promoDiscountXof)}',
                      accent: AppColors.success),
                _line(
                    'Livraison',
                    totals.deliveryFeeXof == 0
                        ? 'Offerte'
                        : formatXof(totals.deliveryFeeXof)),
                // Guests earn no points: invite them to create an account.
                if (ref.watch(signedInProvider))
                  _line('Points LO+ gagnés',
                      '+${loyaltyPointsFor(totals.subtotalXof - totals.promoDiscountXof - pointsDiscount)} pts',
                      accent: AppColors.success)
                else
                  _line('Avec un compte LO+',
                      '+${loyaltyPointsFor(totals.subtotalXof - totals.promoDiscountXof)} pts',
                      accent: AppColors.textSecondary),
                const Divider(),
                _line('Total', formatXof(totals.totalXof), bold: true),
                if (pointsDiscount > 0)
                  _line('Points LO+ ($usedPoints pts)',
                      '−${formatXof(pointsDiscount)}',
                      accent: AppColors.success),
                if (giftApplied > 0)
                  _line('Carte cadeau', '−${formatXof(giftApplied)}',
                      accent: AppColors.success),
                if (pointsDiscount > 0 || giftApplied > 0)
                  _line('Reste à payer', formatXof(amountDue), bold: true),
              ]))),
      const SizedBox(height: AppSpacing.sm),
      const Text(
          'Garantie constructeur · Retour sous 7 jours\nSimulation uniquement : aucun paiement réel n’est effectué.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
    ];
    final last = step == _stepLabels.length - 1;
    // One scrolling page per step; the error box shows on the current one.
    Widget stepView(int i) => ColoredBox(
          color: AppColors.background,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              ...[deliveryStep, paymentStep, reviewStep][i],
              if (error != null && i == step)
                Container(
                  margin: const EdgeInsets.only(top: AppSpacing.md),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.dangerSoft,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    border: Border.all(
                        color: AppColors.danger.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 20, color: AppColors.danger),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                            child: Text(error!,
                                style: const TextStyle(
                                    color: AppColors.dangerDark,
                                    fontWeight: FontWeight.w700))),
                      ]),
                ),
            ],
          ),
        );
    return Column(children: [
      _StepIndicator(
          labels: _stepLabels,
          current: step,
          onStepTap: (i) => setState(() => step = i)),
      // Each step is a real page stacked by a nested navigator: it pushes
      // in on "Continuer" and pops off on back (or the iOS swipe gesture).
      Expanded(
        child: Navigator(
          pages: [
            for (var i = 0; i <= step; i++)
              MaterialPage<void>(
                  key: ValueKey('checkout-step-$i'), child: stepView(i)),
          ],
          onDidRemovePage: (page) {
            // A page the user popped (swipe back): follow it.
            if (page.key == ValueKey('checkout-step-$step') && step > 0) {
              setState(() {
                error = null;
                step--;
              });
            }
          },
        ),
      ),
      // Always visible: amount to pay, then a full-width button.
      Material(
        color: AppColors.white,
        // Thin top border: separates the bar from the scrolling content.
        shape: const Border(top: BorderSide(color: AppColors.border)),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('À payer', style: AppText.caption),
                      Text('Étape ${step + 1} sur ${_stepLabels.length}',
                          style: AppText.caption.copyWith(
                              fontSize: 11, color: AppColors.primary)),
                    ]),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(formatXof(amountDue),
                          style: const TextStyle(
                              fontSize: 19, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      textStyle: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    onPressed: sending ? null : (last ? submit : _next),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (last && !sending) ...[
                            const Icon(Icons.lock_outline, size: 18),
                            const SizedBox(width: AppSpacing.xs),
                          ],
                          Text(last
                              ? (sending ? 'Confirmation…' : 'Confirmer')
                              : 'Continuer'),
                          if (!last) ...[
                            const SizedBox(width: AppSpacing.xs),
                            const Icon(Icons.arrow_forward_rounded, size: 18),
                          ],
                        ])),
              ),
              const SizedBox(height: AppSpacing.xs),
              const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.verified_user_outlined,
                        size: 13, color: AppColors.textSecondary),
                    SizedBox(width: 4),
                    Flexible(
                      child: Text('Paiement sécurisé · Garantie constructeur',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 11, color: AppColors.textSecondary)),
                    ),
                  ]),
            ]),
          ),
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    // Phone back button: previous step first, leave only from step 1.
    return PopScope(
      canPop: step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
            bottom: false,
            child: Column(children: [
              AppHeader(title: 'Commande', onBack: _back),
              cart.when(
                  loading: () => const LoadingState(
                      layout: SkeletonLayout.form,
                      label: 'Chargement de votre commande…'),
                  error: (error, stackTrace) =>
                      ErrorState(onRetry: () => ref.invalidate(cartProvider)),
                  data: (value) => Expanded(child: _buildCartContent(value)))
            ])),
      ),
    );
  }

  Widget _line(String label, String value, {bool bold = false, Color? accent}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
              child: Text(label,
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 13))),
          const SizedBox(width: AppSpacing.sm),
          Text(value,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                  color: accent ?? AppColors.text)),
        ],
      ),
    );
  }

  String? _paymentAsset(PaymentMethod method) => switch (method) {
      PaymentMethod.cashOnDelivery =>
        'assets/paiement/Icône de paiement en espèces.png',
      PaymentMethod.wave => 'assets/paiement/wave.png',
      PaymentMethod.orangeMoney => 'assets/paiement/orange-money.png',
      PaymentMethod.freeMoney => 'assets/paiement/free-money.png',
      PaymentMethod.card =>
        'assets/paiement/Icône_de_carte_bancaire_moderne-removebg-preview.png',
    };
}

class _RadioOption<T> extends StatelessWidget {
  const _RadioOption({
    required this.value,
    required this.group,
    required this.onChanged,
    required this.title,
    required this.subtitle,
    this.icon,
    this.leading,
    this.badge,
    this.trailing,
    required this.selected,
    this.enabled = true,
  });

  final T value;
  final T group;
  final ValueChanged<T> onChanged;
  final String title;
  final String subtitle;
  final IconData? icon;
  final Widget? leading;

  /// Small pill after the title (e.g. delivery time).
  final String? badge;

  /// Right-aligned bold text (e.g. delivery price).
  final String? trailing;
  final bool selected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final leadingWidget = leading ??
        (icon != null ? Icon(icon, size: 20, color: AppColors.primary) : null);
    return Opacity(
        opacity: enabled ? 1 : 0.5,
        child: InkWell(
          onTap: enabled ? () => onChanged(value) : null,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: selected ? AppColors.primarySoft : AppColors.white,
              border: Border.all(
                  color: selected ? AppColors.primary : AppColors.border),
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 2),
                  ),
                  child: selected
                      ? Container(
                          margin: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: AppSpacing.sm),
                if (leadingWidget != null) ...[
                  leadingWidget,
                  const SizedBox(width: AppSpacing.sm),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                          spacing: 6,
                          runSpacing: 2,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(title,
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w700)),
                            if (badge != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F3F7),
                                  borderRadius:
                                      BorderRadius.circular(AppRadii.pill),
                                ),
                                child: Text(badge!,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textSecondary)),
                              ),
                          ]),
                      Text(subtitle,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Text(trailing!,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: trailing == 'Offerte' || trailing == 'Gratuit'
                              ? AppColors.success
                              : AppColors.text)),
                ],
              ],
            ),
          ),
        ));
  }
}

/// Mobile-money tile: the brand logo fills the top, name + radio below.
class _PayTile extends StatelessWidget {
  const _PayTile({
    required this.label,
    required this.asset,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });
  final String label;
  final String asset;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        selected: selected,
        button: true,
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: Material(
            color: AppColors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.lg),
              side: BorderSide(
                  color: selected ? AppColors.primaryDark : AppColors.border,
                  width: selected ? 2 : 1),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: enabled ? onTap : null,
              child: Column(children: [
                AspectRatio(
                  aspectRatio: 1.25,
                  child: Image.asset(asset, fit: BoxFit.cover),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.sm, AppSpacing.sm, AppSpacing.xs, AppSpacing.sm),
                  decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: AppColors.border))),
                  child: Row(children: [
                    Expanded(
                      child: Text(label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight:
                                  selected ? FontWeight.w800 : FontWeight.w600,
                              color: AppColors.text)),
                    ),
                    Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      size: 18,
                      color: selected
                          ? AppColors.primaryDark
                          : AppColors.textSecondary,
                    ),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      );
}

/// "1 Livraison — 2 Paiement — 3 Récapitulatif" progress header.
class _StepIndicator extends StatelessWidget {
  const _StepIndicator(
      {required this.labels, required this.current, required this.onStepTap});
  final List<String> labels;
  final int current;

  /// Called with a finished step's index to go back to it.
  final ValueChanged<int> onStepTap;

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0)
              const Icon(Icons.chevron_right,
                  size: 18, color: AppColors.textSecondary),
            Flexible(
              child: Semantics(
                button: i < current,
                label: 'Étape ${i + 1} sur ${labels.length} : ${labels[i]}'
                    '${i == current ? ', en cours' : i < current ? ', terminée' : ''}',
                child: ExcludeSemantics(
                  child: InkWell(
                    onTap: i < current ? () => onStepTap(i) : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs, vertical: AppSpacing.md),
                      // Current step: dark blue underline.
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: i == current
                                ? AppColors.primaryDark
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        if (i < current) ...[
                          const Icon(Icons.check,
                              size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 3),
                        ],
                        Flexible(
                          child: Text(labels[i],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: i == current
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: i == current
                                    ? AppColors.primaryDark
                                    : i < current
                                        ? AppColors.textSecondary
                                        : AppColors.textSecondary
                                            .withValues(alpha: 0.6),
                              )),
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ]),
      );
}

/// Recap block with an optional "Modifier" link back to its step.
class _ReviewSection extends StatelessWidget {
  const _ReviewSection({required this.title, required this.lines, this.onEdit});
  final String title;
  final List<String> lines;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800))),
              if (onEdit != null)
                TextButton(onPressed: onEdit, child: const Text('Modifier')),
            ]),
            for (final line in lines)
              if (line.isNotEmpty)
                Padding(
                    padding: const EdgeInsets.only(top: 2), child: Text(line)),
          ]),
        ),
      );
}

/// Recap of the ordered items: photo, name, quantity and line price.
class _ReviewItems extends StatelessWidget {
  const _ReviewItems({required this.items});
  final List<CartItem> items;

  @override
  Widget build(BuildContext context) {
    final count = items.fold<int>(0, (n, i) => n + i.quantity);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Articles ($count)',
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Row(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox.square(
                    dimension: 52,
                    child: ColoredBox(
                      color: const Color(0xFFF1F3F7),
                      child: ProductImage(
                          url: item.imageUrl,
                          categoryId: item.categoryId,
                          iconSize: 22),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                        Text('Quantité : ${item.quantity}',
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 12)),
                      ]),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(formatXof(item.unitPriceXof * item.quantity),
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800)),
              ]),
            ),
        ]),
      ),
    );
  }
}
