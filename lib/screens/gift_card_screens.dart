import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../contracts/gift_card.dart';
import '../features/account/account_providers.dart';
import '../features/member/member_providers.dart';
import '../theme/tokens.dart';
import '../utils/currency.dart';
import '../widgets/card_faces.dart';
import '../widgets/error_state.dart';
import '../widgets/loading_state.dart';
import '../widgets/sub_page.dart';

/// Same conditions as the site (GIFT_CARD_CONDITIONS).
const _conditions = [
  (
    'Quelle est la durée de validité ?',
    "Douze mois à compter de son activation. La date d'expiration figure dans l'e-mail de confirmation et dans votre espace client."
  ),
  (
    'La carte est-elle utilisable en plusieurs fois ?',
    'Oui. Le solde restant reste disponible jusqu\'à épuisement ou expiration, en ligne comme en showroom.'
  ),
  (
    'Peut-on la cumuler avec une promotion ?',
    'Oui, la carte cadeau est un moyen de paiement : elle se cumule avec les promotions, les codes promo et les remises Lo+.'
  ),
  (
    'Comment ma carte est-elle protégée ?',
    "À chaque utilisation, le porteur donne son nom et les 4 derniers chiffres du téléphone de l'acheteur ou du bénéficiaire. Un code de confirmation par SMS est demandé pour une carte offerte, un achat d'au moins 100 000 FCFA ou un code saisi à la main. Vous pouvez suspendre votre carte à tout moment depuis votre espace client."
  ),
  (
    'Est-elle remboursable ?',
    "Elle n'est ni remboursable ni échangeable contre des espèces, conformément à nos conditions générales de vente. En cas de perte d'une carte numérique, nous pouvons la réémettre sur justificatif d'achat."
  ),
];

/// Buy a gift card, check a balance, read the conditions (site: /carte-cadeau).
class GiftCardScreen extends ConsumerStatefulWidget {
  const GiftCardScreen({super.key, this.initialAmountXof});

  /// Amount preselected when opened from the home page.
  final int? initialAmountXof;
  @override
  ConsumerState<GiftCardScreen> createState() => _GiftCardScreenState();
}

class _GiftCardScreenState extends ConsumerState<GiftCardScreen> {
  late int _amount = giftCardPresetsXof.contains(widget.initialAmountXof)
      ? widget.initialAmountXof!
      : 50000;
  final _customAmount = TextEditingController();
  GiftCardDelivery _delivery = GiftCardDelivery.digitalWhatsapp;
  final _recipient = TextEditingController();
  final _buyerName = TextEditingController();
  final _buyerPhone = TextEditingController();
  final _message = TextEditingController();
  final _balanceCode = TextEditingController();
  String? _error;
  String? _balanceResult;
  bool _sending = false;

  @override
  void dispose() {
    _customAmount.dispose();
    _recipient.dispose();
    _buyerName.dispose();
    _buyerPhone.dispose();
    _message.dispose();
    _balanceCode.dispose();
    super.dispose();
  }

  int get _fee => _delivery == GiftCardDelivery.physicalHome
      ? giftCardHomeDeliveryFeeXof
      : 0;

  Future<void> _buy() async {
    // Without an account the buyer gives a name and phone (no redirect).
    final guest = !ref.read(signedInProvider);
    if (guest &&
        (_buyerName.text.trim().length < 2 ||
            _buyerPhone.text.replaceAll(RegExp(r'\D'), '').length < 9)) {
      setState(() => _error =
          'Indiquez votre nom et votre téléphone (acheteur de la carte).');
      return;
    }
    if (_amount < giftCardMinXof ||
        _amount > giftCardMaxXof ||
        _amount % giftCardStepXof != 0) {
      setState(() => _error =
          'Montant entre ${formatXof(giftCardMinXof)} et ${formatXof(giftCardMaxXof)}, par multiples de 1 000.');
      return;
    }
    if (_recipient.text.trim().length < 2) {
      setState(() => _error = 'Indiquez le nom du bénéficiaire.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final card = await ref.read(giftCardActionsProvider).buy(
          amountXof: _amount,
          delivery: _delivery,
          recipientName: _recipient.text.trim(),
          message: _message.text,
          buyerName: guest ? _buyerName.text.trim() : null,
          buyerPhone: guest ? _buyerPhone.text.trim() : null);
      if (!mounted) return;
      await showDialog<void>(
          context: context,
          // A plain Dialog: AlertDialog measures its content's intrinsic
          // width, which the card preview (LayoutBuilder) cannot provide.
          builder: (context) => Dialog(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('Carte cadeau créée',
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w800)),
                          const SizedBox(height: AppSpacing.md),
                          FlippableGiftCard(
                              amountXof: card.initialXof,
                              code: card.code,
                              serial: card.serial,
                              maxWidth: 320),
                          const SizedBox(height: AppSpacing.xs),
                          const Text('Touchez la carte pour la retourner',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12)),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                              'Pour ${card.recipientName}\nCode : ${card.code}\n${_delivery.label}\n\nSimulation : aucun paiement réel.'),
                          const SizedBox(height: AppSpacing.sm),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('OK')),
                          ),
                        ]),
                  ),
                ),
              ));
      _recipient.clear();
      _message.clear();
    } catch (e) {
      if (mounted) {
        setState(
            () => _error = errorMessage(e, 'Achat impossible. Réessayez.'));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _checkBalance() async {
    final code = _balanceCode.text.trim();
    if (code.isEmpty) return;
    setState(() => _balanceResult = 'Vérification…');
    try {
      final b = await ref.read(giftCardRepositoryProvider).checkBalance(code);
      if (mounted) {
        setState(() => _balanceResult =
            'Solde : ${formatXof(b.balanceXof)} · ${b.status == 'ACTIVE' ? 'active' : 'suspendue'} · expire le ${b.expiresAt}');
      }
    } catch (e) {
      if (mounted) {
        setState(
            () => _balanceResult = errorMessage(e, 'Vérification impossible.'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SubPage(
      title: 'Carte cadeau',
      subtitle: 'Offrez le choix, de 5 000 à 1 000 000 FCFA',
      child: ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [
        // Live preview: the card's colour follows the amount, like the site.
        Center(child: GiftCardFace(amountXof: _amount, maxWidth: 400)),
        const SizedBox(height: AppSpacing.lg),
        const Text('Montant',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        const SizedBox(height: AppSpacing.sm),
        Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
          for (final preset in giftCardPresetsXof)
            ChoiceChip(
                label: Text(formatXof(preset)),
                selected: _amount == preset && _customAmount.text.isEmpty,
                onSelected: (_) => setState(() {
                      _customAmount.clear();
                      _amount = preset;
                    })),
        ]),
        const SizedBox(height: AppSpacing.sm),
        TextField(
            controller: _customAmount,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            // Emptied field: back to the default amount (not the last digit).
            onChanged: (v) =>
                setState(() => _amount = int.tryParse(v) ?? 50000),
            decoration: const InputDecoration(
                labelText: 'Autre montant (FCFA)',
                helperText: 'Multiple de 1 000',
                border: OutlineInputBorder())),
        const SizedBox(height: AppSpacing.md),
        const Text('Remise de la carte',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        RadioGroup<GiftCardDelivery>(
          groupValue: _delivery,
          onChanged: (v) => setState(() => _delivery = v!),
          child: Column(children: [
            for (final d in GiftCardDelivery.values)
              RadioListTile<GiftCardDelivery>(
                  contentPadding: EdgeInsets.zero,
                  value: d,
                  title: Text(d.label)),
          ]),
        ),
        if (!ref.watch(signedInProvider)) ...[
          const SizedBox(height: AppSpacing.sm),
          const Text('Vous (acheteur)',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: AppSpacing.sm),
          TextField(
              controller: _buyerName,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                  labelText: 'Votre nom', border: OutlineInputBorder())),
          const SizedBox(height: AppSpacing.sm),
          TextField(
              controller: _buyerPhone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                  labelText: 'Votre téléphone',
                  prefixText: '+221 ',
                  border: OutlineInputBorder())),
          const SizedBox(height: AppSpacing.md),
        ],
        TextField(
            controller: _recipient,
            decoration: const InputDecoration(
                labelText: 'Nom du bénéficiaire',
                border: OutlineInputBorder())),
        const SizedBox(height: AppSpacing.sm),
        TextField(
            controller: _message,
            maxLines: 2,
            decoration: const InputDecoration(
                labelText: 'Message (facultatif)',
                border: OutlineInputBorder())),
        const SizedBox(height: AppSpacing.md),
        Text(
            'Total : ${formatXof(_amount + _fee)}${_fee > 0 ? ' (dont ${formatXof(_fee)} de livraison)' : ''}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        if (_error != null)
          Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(_error!,
                  style: const TextStyle(
                      color: AppColors.danger, fontWeight: FontWeight.w700))),
        const SizedBox(height: AppSpacing.sm),
        ElevatedButton(
            onPressed: _sending ? null : _buy,
            child: Text(_sending ? 'Création…' : 'Offrir cette carte')),
        const PageSectionTitle('Vérifier un solde'),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: TextField(
                  controller: _balanceCode,
                  textCapitalization: TextCapitalization.characters,
                  onSubmitted: (_) => _checkBalance(),
                  decoration: const InputDecoration(
                      hintText: 'LOGC-XXXX-XXXX',
                      border: OutlineInputBorder(),
                      isDense: true))),
          const SizedBox(width: AppSpacing.sm),
          OutlinedButton(
              onPressed: _checkBalance, child: const Text('Vérifier')),
        ]),
        if (_balanceResult != null)
          Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(_balanceResult!,
                  style: const TextStyle(fontWeight: FontWeight.w700))),
        const PageSectionTitle('Conditions'),
        for (final (q, a) in _conditions)
          ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title:
                  Text(q, style: const TextStyle(fontWeight: FontWeight.w700)),
              childrenPadding: const EdgeInsets.only(bottom: AppSpacing.sm),
              children: [Text(a)]),
      ]),
    );
  }
}

/// "Mes cartes cadeaux" in the account (site: MyGiftCardsSection).
class MyGiftCardsScreen extends ConsumerWidget {
  const MyGiftCardsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(myGiftCardsProvider);
    return SubPage(
      title: 'Mes cartes cadeaux',
      child: cards.when(
        loading: () => const LoadingState(label: 'Chargement de vos cartes…'),
        error: (e, _) =>
            ErrorState(onRetry: () => ref.invalidate(myGiftCardsProvider)),
        data: (items) =>
            ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [
          OutlinedButton.icon(
              onPressed: () => context.push('/carte-cadeau'),
              icon: const Icon(Icons.card_giftcard),
              label: const Text('Offrir une carte cadeau')),
          const SizedBox(height: AppSpacing.md),
          if (items.isEmpty)
            const Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.md),
                child: Text('Vous n’avez pas encore de carte cadeau.')),
          for (final c in items)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        // Tap to see the back (barcode, number).
                        child: FlippableGiftCard(
                          amountXof: c.initialXof,
                          code: c.code,
                          serial: c.serial,
                          dimmed: !c.active,
                          stateLabel: c.active ? null : 'SUSPENDUE',
                          maxWidth: 400,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                          spacing: AppSpacing.sm,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(formatXof(c.balanceXof),
                                style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800)),
                            Text('sur ${formatXof(c.initialXof)}',
                                style: const TextStyle(
                                    color: AppColors.textSecondary)),
                          ]),
                      SelectableText(c.code,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, letterSpacing: 1)),
                      Text(
                          '${c.recipientName ?? ''} · expire le ${c.expiresAt} · ${c.active ? 'active' : 'suspendue'}',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                            onPressed: () async {
                              try {
                                await ref
                                    .read(giftCardActionsProvider)
                                    .setSuspended(c.id, c.active);
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(errorMessage(
                                              e, 'Opération impossible.'))));
                                }
                              }
                            },
                            child: Text(c.active ? 'Suspendre' : 'Réactiver',
                                style: TextStyle(
                                    color: c.active
                                        ? AppColors.danger
                                        : AppColors.primary))),
                      ),
                    ]),
              ),
            ),
        ]),
      ),
    );
  }
}
