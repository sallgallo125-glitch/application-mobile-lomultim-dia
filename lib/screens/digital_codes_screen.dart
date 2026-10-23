import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../contracts/digital_code.dart';
import '../features/digital/digital_code_providers.dart';
import '../theme/redesign_fonts.dart';
import '../theme/tokens.dart';
import '../widgets/digital/digital_product_card.dart';
import '../widgets/error_state.dart';
import '../widgets/loading_state.dart';
import '../widgets/sub_page.dart';

/// "Mes codes": every game and licence bought, with its card.
class DigitalCodesScreen extends ConsumerWidget {
  const DigitalCodesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final codes = ref.watch(digitalCodesProvider);
    return RedesignFonts(
      child: SubPage(
        title: 'Mes codes',
        subtitle: 'Jeux et licences achetés',
        child: codes.when(
          loading: () => const LoadingState(label: 'Chargement de vos codes…'),
          error: (e, s) =>
              ErrorState(onRetry: () => ref.invalidate(digitalCodesProvider)),
          data: (list) => list.isEmpty
              ? const _Empty()
              : RefreshIndicator(
                  onRefresh: () => ref.refresh(digitalCodesProvider.future),
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
                        AppSpacing.md, AppSpacing.lg, AppSpacing.xxl),
                    itemCount: list.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: AppSpacing.lg),
                    itemBuilder: (context, i) => DigitalCodeTile(code: list[i]),
                  ),
                ),
        ),
      ),
    );
  }
}

/// What flies between the list (landscape card) and the detail (portrait
/// card): the brand-coloured card without content, which cannot overflow
/// while its shape changes.
HeroFlightShuttleBuilder _cardShuttle(DigitalCode code) =>
    (context, animation, direction, fromContext, toContext) => DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.xl),
            gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: PlatformBrand.of(code).colors),
          ),
        );

/// Card thumbnail + status line; opens the detail.
class DigitalCodeTile extends StatelessWidget {
  const DigitalCodeTile({super.key, required this.code});
  final DigitalCode code;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.xl),
      onTap: () => context.push('/mes-codes/${code.id}'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Hero(
            tag: 'code-${code.id}',
            flightShuttleBuilder: _cardShuttle(code),
            child: DigitalProductCard(code: code, compact: true)),
        const SizedBox(height: AppSpacing.sm),
        Row(children: [
          Expanded(
            child: Text('${code.orderNumber} · ${code.purchasedAt ?? ''}',
                style: AppText.caption),
          ),
          _StatusPill(code.status),
          const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        ]),
      ]),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill(this.status);
  final DigitalCodeStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      DigitalCodeStatus.delivered => ('Code disponible', AppColors.success),
      DigitalCodeStatus.pending => ('En cours de livraison', AppColors.gold),
      DigitalCodeStatus.failed => ('Échec de livraison', AppColors.danger),
      DigitalCodeStatus.revoked => ('Code révoqué', AppColors.danger),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadii.pill)),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.vpn_key_outlined,
              size: 48, color: AppColors.primary),
          const SizedBox(height: AppSpacing.md),
          const Text('Aucun code pour le moment', style: AppText.subtitle),
          const SizedBox(height: AppSpacing.xs),
          const Text(
              'Vos jeux et licences Windows achetés apparaîtront ici avec leur code.',
              textAlign: TextAlign.center,
              style: AppText.bodyMuted),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton(
              onPressed: () => context.go('/boutique'),
              child: const Text('Voir la boutique')),
        ]),
      ),
    );
  }
}

/// One code: full card, reveal / copy, activation link and steps, details.
class DigitalCodeDetailScreen extends ConsumerStatefulWidget {
  const DigitalCodeDetailScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<DigitalCodeDetailScreen> createState() =>
      _DigitalCodeDetailScreenState();
}

class _DigitalCodeDetailScreenState
    extends ConsumerState<DigitalCodeDetailScreen> {
  // Hidden by default: the code is shown on demand only.
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final code = ref.watch(digitalCodeProvider(widget.id));
    return RedesignFonts(
      child: SubPage(
        title: 'Mon code',
        fallbackRoute: '/mes-codes',
        child: code.when(
          loading: () => const LoadingState(label: 'Chargement…'),
          error: (e, s) => ErrorState(
              onRetry: () => ref.invalidate(digitalCodeProvider(widget.id))),
          data: (c) => c == null
              ? const Center(child: Text('Code introuvable.'))
              : _body(c),
        ),
      ),
    );
  }

  Widget _body(DigitalCode code) {
    final brand = PlatformBrand.of(code);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxl),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Hero(
                tag: 'code-${code.id}',
                flightShuttleBuilder: _cardShuttle(code),
                child: DigitalProductCard(code: code, revealed: _revealed)),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (code.hasCode) ...[
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _revealed = !_revealed),
                icon: Icon(_revealed
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined),
                label: Text(_revealed ? 'Masquer' : 'Révéler le code'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _copy(code),
                icon: const Icon(Icons.copy_rounded),
                label: const Text('Copier'),
              ),
            ),
          ]),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: () => launchUrl(Uri.parse(brand.redeemUrl),
                mode: LaunchMode.externalApplication),
            icon: const Icon(Icons.open_in_new),
            label: Text(brand.redeemLabel),
          ),
        ] else
          _Notice(code: code),
        const SizedBox(height: AppSpacing.xl),
        const Text('Comment l’activer', style: AppText.section),
        const SizedBox(height: AppSpacing.md),
        for (final (i, step) in brand.steps.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: AppColors.primarySoft,
                child: Text('${i + 1}',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary)),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text(step, style: AppText.body)),
            ]),
          ),
        const SizedBox(height: AppSpacing.md),
        const Text('Informations', style: AppText.section),
        const SizedBox(height: AppSpacing.sm),
        _InfoTable(rows: [
          ('Produit', code.productName),
          if (code.edition != null) ('Édition', code.edition!),
          ('Plateforme', brand.name == 'Microsoft' ? 'PC Windows' : brand.name),
          if (code.regionCode != null) ('Région', code.regionCode!),
          if (code.licenseType != null) ('Type de licence', code.licenseType!),
          if (code.devices != null) ('Appareils', '${code.devices} PC'),
          ('Activation', code.activationMethod),
          if (code.sku != null) ('Référence', code.sku!),
          ('Commande', code.orderNumber),
          if (code.purchasedAt != null) ('Achat', code.purchasedAt!),
          if (code.deliveredAt != null) ('Livré le', code.deliveredAt!),
        ]),
        const SizedBox(height: AppSpacing.md),
        TextButton.icon(
          onPressed: () => context.push('/commandes/${code.orderNumber}'),
          icon: const Icon(Icons.receipt_long_outlined),
          label: const Text('Voir la commande'),
        ),
        const SizedBox(height: AppSpacing.sm),
        const Text(
            'Ne partagez jamais ce code : une fois activé, il est lié à votre compte '
            'et ne peut plus être utilisé.',
            textAlign: TextAlign.center,
            style: AppText.caption),
      ],
    );
  }

  Future<void> _copy(DigitalCode code) async {
    await Clipboard.setData(ClipboardData(text: code.code!));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Code copié dans le presse-papiers.')));
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.code});
  final DigitalCode code;

  @override
  Widget build(BuildContext context) {
    final pending = code.status == DigitalCodeStatus.pending;
    final color = pending ? AppColors.primary : AppColors.danger;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
          color: pending ? AppColors.primarySoft : AppColors.dangerSoft,
          borderRadius: BorderRadius.circular(AppRadii.md)),
      child: Row(children: [
        Icon(pending ? Icons.schedule : Icons.error_outline, color: color),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
              pending
                  ? 'Votre code est en cours de livraison. Il apparaîtra ici '
                      'dès la confirmation du paiement, généralement en quelques minutes.'
                  : code.failureReason ??
                      'Ce code n’est plus disponible. Contactez le service client.',
              style: AppText.body),
        ),
      ]),
    );
  }
}

class _InfoTable extends StatelessWidget {
  const _InfoTable({required this.rows});
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppRadii.md)),
      child: Column(children: [
        for (final (i, (k, v)) in rows.indexed) ...[
          if (i > 0) const Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: 10),
            child: Row(children: [
              Expanded(child: Text(k, style: AppText.bodyMuted)),
              Flexible(
                child: Text(v,
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
        ],
      ]),
    );
  }
}
