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
              const AppHeader(title: 'Lo+', subtitle: 'Programme de fidélité'),
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
              // Tap to turn the card over ("Ma carte" opens the QR page).
              return FlippableLoyaltyCard(
                cardNumber: member?.cardNumber ?? '•••• •••• ••••',
                // The signed-in customer's name (the demo API returns a fixed one).
                memberName: ref.watch(sessionUserProvider)?.name ??
                    member?.holderName ??
                    '',
                points: member?.points ?? loyalty.points,
                tierCode: loyalty.tierCode,
              );
            }),
          ),
          const SizedBox(height: AppSpacing.lg),
          _PointsSummary(points: loyalty.points),
          const SizedBox(height: AppSpacing.md),
          _TierProgress(
            currentTier: tier,
            nextTier: next,
            spend12MonthsXof: loyalty.spend12MonthsXof,
            progress: progress.clamp(0.0, 1.0).toDouble(),
          ),
          const SizedBox(height: AppSpacing.xl),
          const _LoyaltySectionTitle(
            title: 'Vos avantages LO+',
            subtitle: 'Accédez rapidement à vos services fidélité.',
          ),
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
          const _LoyaltySectionTitle(
            title: 'Comment ça marche',
            subtitle: 'Les règles pour gagner et utiliser vos points.',
          ),
          const SizedBox(height: AppSpacing.sm),
          _HowItWorksStep(
            number: '01',
            icon: Icons.shopping_bag_outlined,
            title: 'Gagnez des points',
            description:
                '1 point par tranche de ${formatXof(loyaltyTrancheXof)}, multiplié selon votre palier, en ligne comme en showroom.',
          ),
          _HowItWorksStep(
            number: '02',
            icon: Icons.redeem_outlined,
            title: 'Utilisez vos points',
            description:
                '1 point = ${formatXof(loyaltyPointValueXof)} · utilisable dès le panier à partir de $loyaltyMinRedeemPoints points',
          ),
          const _HowItWorksStep(
            number: '03',
            icon: Icons.group_add_outlined,
            title: 'Parrainez vos proches',
            description:
                '50 points par filleul actif et 20 points pour le filleul.',
            isLast: true,
          ),
          const SizedBox(height: AppSpacing.lg),
          const _LoyaltySectionTitle(
            title: 'Les paliers',
            subtitle: 'Découvrez les avantages associés à chaque niveau.',
          ),
          const SizedBox(height: AppSpacing.sm),
          for (var index = 0; index < loyaltyTiers.length; index++)
            _TierTimelineItem(
              tier: loyaltyTiers[index],
              current: loyaltyTiers[index].code == tier.code,
              isLast: index == loyaltyTiers.length - 1,
            ),
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

class _PointsSummary extends StatelessWidget {
  const _PointsSummary({required this.points});

  final int points;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          onTap: () => context.push('/lo/echanger'),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.lg),
              border:
                  Border.all(color: AppColors.primary.withValues(alpha: .12)),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                  child: const Icon(
                    Icons.stars_rounded,
                    color: AppColors.primaryDark,
                    size: 25,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Votre solde LO+',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$points points',
                        style: const TextStyle(
                          color: AppColors.primaryDark,
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Valeur : ${formatXof(points * loyaltyPointValueXof)}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.primaryDark),
              ],
            ),
          ),
        ),
      );
}

class _TierProgress extends StatelessWidget {
  const _TierProgress({
    required this.currentTier,
    required this.nextTier,
    required this.spend12MonthsXof,
    required this.progress,
  });

  final LoyaltyTier currentTier;
  final LoyaltyTier? nextTier;
  final int spend12MonthsXof;
  final double progress;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Progression de votre palier',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.goldOnDark.withValues(alpha: .35),
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                    child: Text(
                      currentTier.name,
                      style: const TextStyle(
                        color: AppColors.primaryDark,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.pill),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 9,
                  color: AppColors.primary,
                  backgroundColor: AppColors.border,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                nextTier == null
                    ? 'Vous avez atteint le palier le plus élevé.'
                    : 'Encore ${formatXof((nextTier!.minSpendXof - spend12MonthsXof).clamp(0, nextTier!.minSpendXof))} d’achats sur 12 mois pour atteindre ${nextTier!.name}.',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
}

class _LoyaltySectionTitle extends StatelessWidget {
  const _LoyaltySectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      );
}

class _HowItWorksStep extends StatelessWidget {
  const _HowItWorksStep({
    required this.number,
    required this.icon,
    required this.title,
    required this.description,
    this.isLast = false,
  });

  final String number;
  final IconData icon;
  final String title;
  final String description;
  final bool isLast;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.md),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 28,
                child: Column(
                  children: [
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: Icon(
                        icon,
                        color: AppColors.textSecondary,
                        size: 21,
                      ),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 1,
                          margin: const EdgeInsets.only(top: AppSpacing.xs),
                          color: AppColors.border,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          number,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: AppColors.text,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      description,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _TierTimelineItem extends StatelessWidget {
  const _TierTimelineItem({
    required this.tier,
    required this.current,
    required this.isLast,
  });

  final LoyaltyTier tier;
  final bool current;
  final bool isLast;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 32,
              child: Column(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: current ? AppColors.success : AppColors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: current
                            ? AppColors.success
                            : AppColors.textSecondary,
                        width: 2,
                      ),
                    ),
                    child: current
                        ? const Icon(Icons.check, color: Colors.white, size: 14)
                        : null,
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        color: AppColors.border,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Card(
                  margin: EdgeInsets.zero,
                  color: current
                      ? AppColors.success.withValues(alpha: .08)
                      : AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    side: BorderSide(
                      color: current ? AppColors.success : AppColors.border,
                      width: current ? 1.5 : 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                tier.name,
                                style: const TextStyle(
                                  color: AppColors.primaryDark,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (current)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                  vertical: AppSpacing.xs,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.success.withValues(alpha: .12),
                                  borderRadius:
                                      BorderRadius.circular(AppRadii.pill),
                                ),
                                child: const Text(
                                  'Votre palier',
                                  style: TextStyle(
                                    color: AppColors.success,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          tier.thresholdLabel,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        for (final benefit in tier.benefits)
                          Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppSpacing.xs),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding:
                                      const EdgeInsets.only(top: 3, right: 7),
                                  child: Icon(
                                    Icons.check_circle,
                                    color: current
                                        ? AppColors.success
                                        : AppColors.textSecondary,
                                    size: 14,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    benefit,
                                    style: const TextStyle(
                                      color: AppColors.text,
                                      fontSize: 12,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}

class _Shortcut extends StatelessWidget {
  const _Shortcut(this.icon, this.label, this.route);
  final IconData icon;
  final String label;
  final String route;
  @override
  Widget build(BuildContext context) => Card(
      margin: EdgeInsets.zero,
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        side: const BorderSide(color: AppColors.border),
      ),
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
