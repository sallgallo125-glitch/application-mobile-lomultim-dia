import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../contracts/account.dart';
import '../features/account/account_providers.dart';
import '../theme/redesign_fonts.dart';
import '../theme/tokens.dart';
import '../utils/currency.dart';
import '../utils/loyalty.dart';
import '../features/member/member_providers.dart';
import '../widgets/app_header.dart';
import '../widgets/card_faces.dart';
import '../widgets/error_state.dart';
import '../widgets/header_actions.dart';
import '../widgets/loading_state.dart';
import '../widgets/nav_clearance.dart';

/// Pale blue-grey tiles and cards on the white page.
const _mist = Color(0xFFF1F3F9);

/// Light text on the blue band (contrast > 7:1 on primaryDark).
const _onBand = Color(0xFFDDE2F5);

class LoyaltyScreen extends ConsumerWidget {
  const LoyaltyScreen({super.key, this.backTo});

  /// Tab to return to (e.g. 'compte') when Lo+ was opened from it; null when
  /// reached from the bottom bar, where no back arrow is needed.
  final String? backTo;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(signedInProvider);
    final summary = ref.watch(accountSummaryProvider);
    final onBack = backTo == null ? null : () => context.go('/$backTo');
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.primaryDark,
        body: RedesignFonts(
            child: SafeArea(
          bottom: false,
          child: ColoredBox(
            color: AppColors.background,
            child: Column(children: [
              if (!signedIn)
                Expanded(child: _GuestContent(onBack: onBack))
              else
                summary.when(
                    loading: () => const LoadingState(
                        layout: SkeletonLayout.account,
                        label: 'Chargement de votre carte Lo+…'),
                    error: (error, stackTrace) => ErrorState(
                        onRetry: () => ref.invalidate(accountSummaryProvider)),
                    data: (account) => Expanded(
                        child: _LoyaltyContent(
                            loyalty: account.loyalty, onBack: onBack))),
            ]),
          ),
        )),
      ),
    );
  }
}

/// Blue band opening the page: the LO+ mark with a subtitle, the bell, and
/// [extra] below; [overlap] (the card) straddles its lower edge, reaching
/// [overlapHeight] up into the blue.
class _Band extends StatelessWidget {
  const _Band(
      {required this.subtitle,
      this.onBack,
      required this.extra,
      required this.overlap,
      required this.overlapHeight});
  final String subtitle;
  final VoidCallback? onBack;
  final Widget extra;
  final Widget overlap;
  final double overlapHeight;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: AppColors.primaryDark,
            padding: EdgeInsets.fromLTRB(
                onBack == null ? AppSpacing.lg : AppSpacing.xs,
                AppSpacing.xs,
                AppSpacing.xs,
                0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  if (onBack != null)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: AppBackButton(onPressed: onBack!, onDark: true),
                    ),
                  Expanded(
                    child: Semantics(
                      header: true,
                      label: 'LO+, $subtitle',
                      excludeSemantics: true,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text.rich(
                              const TextSpan(children: [
                                TextSpan(text: 'LO'),
                                TextSpan(
                                    text: '+',
                                    style:
                                        TextStyle(color: AppColors.goldOnDark)),
                              ]),
                              style: displayFont(const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 30,
                                  height: 1.1,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.6)),
                            ),
                            Text(subtitle,
                                style: const TextStyle(
                                    color: _onBand,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500)),
                          ]),
                    ),
                  ),
                  const _BellButton(),
                ]),
                Padding(
                  padding:
                      EdgeInsets.only(left: onBack == null ? 0 : AppSpacing.md),
                  child: extra,
                ),
              ],
            ),
          ),
          Stack(children: [
            Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: overlapHeight,
                child: const ColoredBox(color: AppColors.primaryDark)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Center(child: overlap),
            ),
          ]),
        ],
      );
}

/// Signed-out view: what LO+ is, a preview card, the ladder and one way in.
class _GuestContent extends StatelessWidget {
  const _GuestContent({this.onBack});
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => ListView(
        padding:
            EdgeInsets.only(bottom: AppSpacing.xl + navBarClearance(context)),
        children: [
          _Band(
            subtitle: 'Programme de fidélité',
            onBack: onBack,
            overlapHeight: 80,
            extra: Padding(
              padding: const EdgeInsets.only(top: 18, bottom: AppSpacing.lg),
              child: SizedBox(
                width: 260,
                child: Text('Vos achats vous font monter',
                    style: displayFont(const TextStyle(
                        color: AppColors.white,
                        fontSize: 40,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8))),
              ),
            ),
            overlap: const LoyaltyCardFace(
              cardNumber: '2026 •••• ••••',
              memberName: 'Votre nom ici',
              points: null,
              tierCode: 'BLEU',
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.fromLTRB(AppSpacing.lg, 20, AppSpacing.lg, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                    'Chaque achat chez LO Multimédia, en ligne ou en showroom, '
                    'vous rapporte des points et vous rapproche du palier '
                    'suivant.',
                    style: AppText.bodyMuted),
                const _SectionTitle('Les paliers'),
                const _TierLadder(currentCode: null, spendXof: 0),
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                      onPressed: () => context.push('/connexion'),
                      child: const Text('Se connecter pour voir mes points')),
                ),
              ],
            ),
          ),
        ],
      );
}

class _LoyaltyContent extends ConsumerWidget {
  const _LoyaltyContent({required this.loyalty, this.onBack});
  final LoyaltySummary loyalty;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tier = loyaltyTierFor(loyalty.tierCode);
    final member = ref.watch(loyaltyMemberProvider).value;
    final points = member?.points ?? loyalty.points;
    final value = formatXof(points * loyaltyPointValueXof);
    return ListView(
        padding:
            EdgeInsets.only(bottom: AppSpacing.xl + navBarClearance(context)),
        children: [
          _Band(
            subtitle: 'Membre ${tier.name}',
            onBack: onBack,
            overlapHeight: 104,
            extra: const SizedBox(height: AppSpacing.lg),
            // Tap to turn the card over ("Ma carte" opens the QR page).
            overlap: FlippableLoyaltyCard(
              cardNumber: member?.cardNumber ?? '•••• •••• ••••',
              // The signed-in customer's name (the demo API returns a fixed one).
              memberName: ref.watch(sessionUserProvider)?.name ??
                  member?.holderName ??
                  '',
              points: points,
              tierCode: loyalty.tierCode,
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: AppSpacing.md),
            child: Text('Touchez la carte pour afficher le QR code',
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
          ),
          Padding(
            padding:
                const EdgeInsets.fromLTRB(AppSpacing.lg, 22, AppSpacing.lg, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  label: '$points points, valeur en caisse $value',
                  excludeSemantics: true,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.bottomLeft,
                          child: Text.rich(
                            TextSpan(children: [
                              TextSpan(text: '$points'),
                              const TextSpan(
                                  text: ' points',
                                  style: TextStyle(
                                      fontSize: 20,
                                      letterSpacing: 0,
                                      fontWeight: FontWeight.w700)),
                            ]),
                            style: displayFont(const TextStyle(
                                color: AppColors.text,
                                fontSize: 76,
                                height: 0.95,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -2,
                                fontFeatures: [FontFeature.tabularFigures()])),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Valeur en caisse',
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13.5)),
                            Text(value,
                                style: const TextStyle(
                                    color: AppColors.text,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    fontFeatures: [
                                      FontFeature.tabularFigures()
                                    ])),
                          ]),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Row(children: [
                  _Tile(Icons.qr_code_2_rounded, 'Ma carte',
                      () => context.push('/lo/carte')),
                  const SizedBox(width: AppSpacing.sm),
                  _Tile(Icons.history_rounded, 'Historique',
                      () => context.push('/lo/historique')),
                  const SizedBox(width: AppSpacing.sm),
                  _Tile(Icons.group_add_outlined, 'Parrainer',
                      () => context.push('/lo/parrainage')),
                ]),
                const _SectionTitle('Vos paliers',
                    sub: 'Calculés sur vos achats des 12 derniers mois'),
                _TierLadder(
                    currentCode: loyalty.tierCode,
                    spendXof: loyalty.spend12MonthsXof),
                const _SectionTitle('Comment ça marche'),
                _HowTo(
                    '1 pt',
                    'tous les ${formatXof(loyaltyTrancheXof)} d’achat, '
                        'multiplié selon votre palier.'),
                _HowTo(
                    formatXof(loyaltyPointValueXof),
                    'la valeur d’un point, utilisable dès '
                    '$loyaltyMinRedeemPoints points en ligne ou en caisse.'),
                const _HowTo('+50 pts',
                    'pour chaque proche parrainé, et +20 points pour lui.'),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                      onPressed: () => context.go('/boutique'),
                      child: const Text('Gagner des points en boutique')),
                ),
              ],
            ),
          ),
        ]);
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.sub});
  final String title;
  final String? sub;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 28, bottom: AppSpacing.lg),
        child: Semantics(
          header: true,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: AppText.section),
            if (sub != null) ...[
              const SizedBox(height: 2),
              Text(sub!, style: AppText.caption),
            ],
          ]),
        ),
      );
}

/// Grey shortcut tile under the balance.
class _Tile extends StatelessWidget {
  const _Tile(this.icon, this.label, this.onTap);
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Material(
          color: _mist,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
              child: Column(children: [
                Icon(icon, color: AppColors.primary, size: 24),
                const SizedBox(height: 6),
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ),
      );
}

/// "Comment ça marche" card: a big blue figure and its explanation.
class _HowTo extends StatelessWidget {
  const _HowTo(this.figure, this.text);
  final String figure;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
            color: _mist, borderRadius: BorderRadius.circular(18)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 78),
            child: Text(figure,
                style: displayFont(const TextStyle(
                    color: AppColors.primary,
                    fontSize: 26,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    fontFeatures: [FontFeature.tabularFigures()]))),
          ),
          const SizedBox(width: 14),
          Expanded(
              child: Text(text,
                  style: const TextStyle(
                      color: AppColors.text, fontSize: 14, height: 1.45))),
        ]),
      );
}

/// White notifications bell for the blue band, with the unread count.
class _BellButton extends ConsumerWidget {
  const _BellButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationsProvider);
    return IconButton(
      tooltip: unread > 0 ? 'Notifications, $unread non lues' : 'Notifications',
      onPressed: () => context.push('/notifications'),
      icon: Badge(
        isLabelVisible: unread > 0,
        backgroundColor: AppColors.danger,
        label: Text('$unread'),
        child: const Icon(Icons.notifications_outlined,
            color: AppColors.white, size: 26),
      ),
    );
  }
}

/// The four tiers as a vertical track, top tier first. The rail fills from
/// the bottom up to the customer's tier, and partly towards the next one in
/// proportion to their 12-month spend. [currentCode] null shows the bare
/// ladder (signed-out view).
class _TierLadder extends StatelessWidget {
  const _TierLadder({required this.currentCode, required this.spendXof});

  final String? currentCode;
  final int spendXof;

  @override
  Widget build(BuildContext context) {
    final current = currentCode == null
        ? -1
        : loyaltyTiers.indexWhere((t) => t.code == currentCode);
    final next = current >= 0 && current + 1 < loyaltyTiers.length
        ? loyaltyTiers[current + 1]
        : null;
    final towardsNext = next == null
        ? 0.0
        : ((spendXof - loyaltyTiers[current].minSpendXof) /
                (next.minSpendXof - loyaltyTiers[current].minSpendXof))
            .clamp(0.0, 1.0);

    // Fill of the rail segment just below tier i (from tier i-1 up to i).
    double segmentFill(int i) =>
        i <= current ? 1 : (i == current + 1 ? towardsNext : 0);

    String noteFor(int i) {
      final tier = loyaltyTiers[i];
      if (i == current) return 'Votre palier actuel';
      if (tier == next) {
        return 'Encore ${formatXof(tier.minSpendXof - spendXof)} '
            "d'achats sur 12 mois";
      }
      if (i == 0) return 'Dès votre premier achat';
      return "Dès ${formatXof(tier.minSpendXof)} d'achats sur 12 mois";
    }

    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: reduceMotion || current < 0
          ? Duration.zero
          : const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) => Column(children: [
        for (var i = loyaltyTiers.length - 1; i >= 0; i--)
          _TierStep(
            tier: loyaltyTiers[i],
            reached: i <= current,
            isCurrent: i == current,
            note: noteFor(i),
            // The bottom tier has no rail below it.
            railFill: i == 0 ? null : segmentFill(i) * t,
          ),
      ]),
    );
  }
}

class _TierStep extends StatelessWidget {
  const _TierStep({
    required this.tier,
    required this.reached,
    required this.isCurrent,
    required this.note,
    required this.railFill,
  });

  final LoyaltyTier tier;
  final bool reached;
  final bool isCurrent;
  final String note;

  /// How much of the rail under this step is filled (0–1); null for none.
  final double? railFill;

  @override
  Widget build(BuildContext context) {
    final color = loyaltyTierColors[tier.code] ?? AppColors.primary;
    final m = tier.multiplier;
    final multiplier =
        '×${m == m.roundToDouble() ? m.toInt() : m.toString().replaceAll('.', ',')}';

    final dot = Container(
      width: isCurrent ? 22 : 14,
      height: isCurrent ? 22 : 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: reached ? color : AppColors.white,
        border: Border.all(
          color: isCurrent
              ? AppColors.primary
              : (reached ? color : const Color(0xFFCBD5E1)),
          width: isCurrent ? 3 : 2,
        ),
      ),
    );

    return Semantics(
      label: '${tier.name}, points $multiplier. $note',
      excludeSemantics: true,
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            width: 28,
            child: Column(children: [
              SizedBox(height: 22, child: Center(child: dot)),
              if (railFill != null)
                Expanded(
                  child: CustomPaint(
                    size: const Size(28, double.infinity),
                    painter: _RailPainter(railFill!),
                  ),
                ),
            ]),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding:
                  EdgeInsets.only(bottom: railFill == null ? 0 : AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(tier.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: displayFont(TextStyle(
                              color: reached
                                  ? AppColors.text
                                  : AppColors.textSecondary,
                              fontSize: isCurrent ? 22 : 19,
                              height: 1.3,
                              fontWeight: isCurrent
                                  ? FontWeight.w800
                                  : FontWeight.w600))),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text('points $multiplier',
                        style: TextStyle(
                            color: isCurrent
                                ? AppColors.primary
                                : AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [
                              FontFeature.tabularFigures()
                            ])),
                  ]),
                  const SizedBox(height: 2),
                  Text(note,
                      style: isCurrent
                          ? const TextStyle(
                              color: AppColors.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)
                          : AppText.caption),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Vertical rail between two tier dots, filled from the bottom by [fill].
class _RailPainter extends CustomPainter {
  _RailPainter(this.fill);
  final double fill;

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 2;
    final top = 2.0, bottom = size.height - 2;
    final paint = Paint()
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        Offset(x, top), Offset(x, bottom), paint..color = AppColors.border);
    if (fill > 0) {
      canvas.drawLine(Offset(x, bottom - (bottom - top) * fill),
          Offset(x, bottom), paint..color = AppColors.primary);
    }
  }

  @override
  bool shouldRepaint(_RailPainter old) => old.fill != fill;
}
