import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../contracts/account.dart';
import '../features/account/account_providers.dart';
import '../theme/tokens.dart';
import '../utils/currency.dart';
import '../utils/loyalty.dart';
import '../features/member/member_providers.dart';
import '../widgets/app_header.dart';
import '../widgets/card_faces.dart';
import '../widgets/error_state.dart';
import '../widgets/loading_state.dart';
import '../widgets/nav_clearance.dart';

class LoyaltyScreen extends ConsumerWidget {
  const LoyaltyScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(signedInProvider);
    final summary = ref.watch(accountSummaryProvider);
    return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
            bottom: false,
            child: Column(children: [
              AppHeader(title: 'Lo+', subtitle: 'Programme de fidélité'),
              if (!signedIn)
                Expanded(
                    child: Center(
                        child: ElevatedButton(
                            onPressed: () => context.push('/connexion'),
                            child: const Text(
                                'Connectez-vous pour voir vos points'))))
              else
                summary.when(
                    loading: () => const LoadingState(
                        layout: SkeletonLayout.account,
                        label: 'Chargement de votre carte Lo+…'),
                    error: (error, stackTrace) => ErrorState(
                        onRetry: () => ref.invalidate(accountSummaryProvider)),
                    data: (account) => Expanded(
                        child: _LoyaltyContent(loyalty: account.loyalty)))
            ])));
  }
}

class _LoyaltyContent extends StatelessWidget {
  const _LoyaltyContent({required this.loyalty});
  final LoyaltySummary loyalty;

  @override
  Widget build(BuildContext context) {
    final tier = loyaltyTierFor(loyalty.tierCode);
    final next = nextLoyaltyTier(loyalty.tierCode);
    final progress = next == null
        ? 1.0
        : (loyalty.spend12MonthsXof - tier.minSpendXof) /
            (next.minSpendXof - tier.minSpendXof);
    return ListView(
        padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg,
            AppSpacing.lg, AppSpacing.lg + navBarClearance(context)),
        children: [
          Center(
            child: Consumer(builder: (context, ref, _) {
              final member = ref.watch(loyaltyMemberProvider).value;
              return GestureDetector(
                onTap: () => context.push('/lo/carte'),
                child: LoyaltyCardFace(
                  cardNumber: member?.cardNumber ?? '•••• •••• ••••',
                  memberName: member?.holderName ?? '',
                  points: member?.points ?? loyalty.points,
                  tierCode: loyalty.tierCode,
                ),
              );
            }),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
              '${loyalty.points} points · soit ${formatXof(loyalty.points * loyaltyPointValueXof)} à utiliser',
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: AppSpacing.sm),
          LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0).toDouble(),
              color: AppColors.primary,
              backgroundColor: AppColors.border),
          const SizedBox(height: AppSpacing.xs),
          Text(
              next == null
                  ? 'Palier ${tier.name} · vous êtes au palier le plus élevé'
                  : 'Palier ${tier.name} · encore ${formatXof(next.minSpendXof - loyalty.spend12MonthsXof)} d\'achats sur 12 mois pour le palier ${next.name}',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: AppSpacing.md),
          GridView.count(
            crossAxisCount: MediaQuery.sizeOf(context).width >= 600 ? 5 : 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 1.1,
            children: const [
              _Shortcut(Icons.qr_code_2, 'Ma carte', '/lo/carte'),
              _Shortcut(Icons.history, 'Historique', '/lo/historique'),
              _Shortcut(Icons.redeem, 'Échanger', '/lo/echanger'),
              _Shortcut(
                  Icons.group_add_outlined, 'Parrainer', '/lo/parrainage'),
              _Shortcut(Icons.emoji_events_outlined, 'Défis', '/lo/defis'),
              _Shortcut(Icons.card_giftcard, 'Carte cadeau', '/carte-cadeau'),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text('Comment ça marche',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: AppSpacing.sm),
          _Rule('1', '1 point par tranche de ${formatXof(loyaltyTrancheXof)}',
              'Multiplié selon votre palier, en ligne comme en showroom'),
          _Rule('2', '1 point = ${formatXof(loyaltyPointValueXof)}',
              'Utilisable dès le panier, à partir de $loyaltyMinRedeemPoints points'),
          const _Rule('3', 'Parrainage',
              '50 points par filleul actif, 20 points pour le filleul'),
          const SizedBox(height: AppSpacing.lg),
          const Text('Les paliers',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: AppSpacing.sm),
          for (final t in loyaltyTiers)
            _TierCard(tier: t, current: t.code == tier.code),
          const SizedBox(height: AppSpacing.sm),
          const Text(loyaltyRulesNote,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: AppSpacing.xl),
          ElevatedButton(
              onPressed: () => context.go('/boutique'),
              child: const Text('Gagner des points maintenant'))
        ]);
  }
}

class _Rule extends StatelessWidget {
  const _Rule(this.step, this.title, this.subtitle);
  final String step;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Card(
      child: ListTile(
          leading: CircleAvatar(
              backgroundColor: AppColors.primarySoft,
              child: Text(step,
                  style: const TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.w800))),
          title: Text(title),
          subtitle: Text(subtitle)));
}

class _TierCard extends StatelessWidget {
  const _TierCard({required this.tier, required this.current});
  final LoyaltyTier tier;
  final bool current;
  @override
  Widget build(BuildContext context) => Card(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          side: BorderSide(
              color: current ? AppColors.primary : Colors.transparent,
              width: 2)),
      child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(
                spacing: AppSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(tier.name,
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800)),
                  if (current)
                    const Text('Votre palier',
                        style: TextStyle(
                            color: AppColors.success,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                ]),
            Text(tier.thresholdLabel,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: AppSpacing.xs),
            for (final benefit in tier.benefits)
              Text('• $benefit', style: const TextStyle(fontSize: 13)),
          ])));
}

class _Shortcut extends StatelessWidget {
  const _Shortcut(this.icon, this.label, this.route);
  final IconData icon;
  final String label;
  final String route;
  @override
  Widget build(BuildContext context) => Card(
      margin: EdgeInsets.zero,
      child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.md),
          onTap: () => context.push(route),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xs),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(height: AppSpacing.xs),
              Text(label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
          )));
}
