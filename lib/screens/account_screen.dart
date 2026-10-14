import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../contracts/account.dart';
import '../features/account/account_providers.dart';
import '../features/customer/customer_providers.dart';
import '../theme/redesign_fonts.dart';
import '../theme/tokens.dart';
import '../utils/currency.dart';
import '../utils/loyalty.dart';
import '../widgets/commerce/product_image.dart';
import '../widgets/error_state.dart';
import '../widgets/loading_state.dart';
import '../widgets/header_actions.dart';
import '../widgets/nav_clearance.dart';

/// Pale blue-grey page background; the white groups sit on it.
const _mist = Color(0xFFF1F3F9);

/// Light text on the blue band (contrast > 7:1 on primaryDark).
const _onBand = Color(0xFFDDE2F5);

/// 1 LO+ point = 100 F in store.
const _pointValueXof = 100;

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(signedInProvider);
    final summary = ref.watch(accountSummaryProvider);
    // The blue band runs up under the status bar and carries the bell
    // (the cart is already in the bottom bar).
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.primaryDark,
        body: RedesignFonts(
            child: SafeArea(
          bottom: false,
          child: ColoredBox(
            color: _mist,
            child: !signedIn
                ? _AccountScroll(
                    collapsedTitle: 'Mon compte',
                    header: _GuestHeader(
                      onSignIn: () => context.push('/connexion'),
                      onSignUp: () => context.push('/inscription'),
                    ),
                    children: [
                      const _GroupLabel('Commandes'),
                      _Group(children: [
                        _Row(Icons.local_shipping_outlined,
                            'Suivre une commande',
                            value: 'Sans compte',
                            muted: true,
                            onTap: () => context.push('/suivi')),
                      ]),
                      const _GroupLabel('Aide et services'),
                      const _HelpGroup(),
                      const _Footer(),
                    ],
                  )
                : summary.when(
                    loading: () => const Column(children: [
                          LoadingState(
                              layout: SkeletonLayout.account,
                              label: 'Chargement de votre compte…'),
                        ]),
                    error: (error, stackTrace) => Column(children: [
                          ErrorState(
                              onRetry: () =>
                                  ref.invalidate(accountSummaryProvider)),
                        ]),
                    data: (account) {
                      final session = ref.watch(sessionUserProvider);
                      final rawName = (session?.name ?? account.name).trim();
                      final name = rawName.isEmpty ? 'Mon compte' : rawName;
                      final phone = session?.phone ?? account.phone;
                      final favorites = ref.watch(favoriteIdsProvider).length;
                      final orders = ref.watch(ordersProvider).value;
                      final current =
                          orders == null ? null : _currentOrder(orders);
                      return _AccountScroll(
                        collapsedTitle: name,
                        header: _ProfileHeader(
                            name: name,
                            phone: phone,
                            tierCode: account.loyalty.tierCode),
                        overlap: _MemberCard(loyalty: account.loyalty),
                        children: [
                          if (current != null) ...[
                            _GroupLabel('Commande en cours',
                                action: 'Suivre',
                                onAction: () => context.push('/commandes')),
                            _CurrentOrder(
                                order: current,
                                onTap: () => context.push('/commandes')),
                          ],
                          _GroupLabel('Mes commandes',
                              action: 'Tout voir',
                              onAction: () => context.push('/commandes')),
                          _Stages(
                              counts:
                                  orders == null ? null : _countByStage(orders),
                              onOrders: () => context.push('/commandes')),
                          const _GroupLabel('Mes achats'),
                          _Group(children: [
                            _Row(Icons.favorite_border, 'Mes favoris',
                                value: '$favorites',
                                muted: true,
                                onTap: () => context.push('/favoris')),
                            _Row(Icons.card_giftcard_outlined, 'Cartes cadeaux',
                                onTap: () => context.push('/cartes-cadeaux')),
                            _Row(
                                Icons.group_add_outlined, 'Parrainer un proche',
                                value: '+50 pts',
                                onTap: () => context.push('/lo/parrainage')),
                          ]),
                          const _GroupLabel('Mon profil'),
                          _Group(children: [
                            _Row(Icons.notifications_none_rounded,
                                'Notifications',
                                value: 'SMS et app',
                                muted: true,
                                onTap: () => context.push('/notifications')),
                          ]),
                          const _GroupLabel('Aide et services'),
                          const _HelpGroup(),
                          const SizedBox(height: AppSpacing.md),
                          _Group(children: [
                            _Row(Icons.logout, 'Se déconnecter',
                                danger: true,
                                onTap: () => ref
                                    .read(sessionUserProvider.notifier)
                                    .state = null),
                          ]),
                          const _Footer(),
                        ],
                      );
                    }),
          ),
        )),
      ),
    );
  }
}

/// The page's scroll view: a pinned blue bar ("Mon compte", then the name
/// once the header has scrolled away, plus the bell), the blue [header],
/// an optional card straddling the band's lower edge, then [children].
class _AccountScroll extends StatefulWidget {
  const _AccountScroll({
    required this.collapsedTitle,
    required this.header,
    this.overlap,
    required this.children,
  });

  final String collapsedTitle;
  final Widget header;
  final Widget? overlap;
  final List<Widget> children;

  @override
  State<_AccountScroll> createState() => _AccountScrollState();
}

class _AccountScrollState extends State<_AccountScroll> {
  static const _collapseAt = 70.0;
  bool _collapsed = false;
  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final collapsed = _controller.offset > _collapseAt;
      if (collapsed != _collapsed) setState(() => _collapsed = collapsed);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fast = MediaQuery.of(context).disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 180);
    final overlap = widget.overlap;
    return CustomScrollView(controller: _controller, slivers: [
      SliverAppBar(
        pinned: true,
        primary: false,
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.primaryDark,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleSpacing: AppSpacing.lg,
        title: AnimatedSwitcher(
          duration: fast,
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.centerLeft,
            children: [...previous, if (current != null) current],
          ),
          child: Text(_collapsed ? widget.collapsedTitle : 'Mon compte',
              key: ValueKey(_collapsed),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: displayFont(const TextStyle(
                  color: AppColors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2))),
        ),
        actions: const [_BellButton(), SizedBox(width: AppSpacing.xs)],
      ),
      SliverToBoxAdapter(
        child: ClipRect(
          child: Container(
            color: AppColors.primaryDark,
            padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xs,
                AppSpacing.lg, overlap == null ? 26 : 20),
            child: Stack(clipBehavior: Clip.none, children: [
              const Positioned(right: -230, top: -40, child: _Ring()),
              widget.header,
            ]),
          ),
        ),
      ),
      if (overlap != null)
        SliverToBoxAdapter(
          child: Stack(children: [
            const Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 64,
                child: ColoredBox(color: AppColors.primaryDark)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: overlap,
            ),
          ]),
        ),
      SliverList(delegate: SliverChildListDelegate(widget.children)),
      SliverToBoxAdapter(child: SizedBox(height: navBarClearance(context))),
    ]);
  }
}

/// Faint tilted ellipse decorating the blue band.
class _Ring extends StatelessWidget {
  const _Ring();

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Transform.rotate(
          angle: -12 * math.pi / 180,
          child: Container(
            width: 440,
            height: 190,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(Radius.elliptical(220, 95)),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08), width: 1.5),
            ),
          ),
        ),
      );
}

class _Avatar extends StatelessWidget {
  const _Avatar({this.initials, this.tierColor});
  final String? initials;
  final Color? tierColor;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 64,
        height: 64,
        child: Stack(clipBehavior: Clip.none, children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: Colors.white.withValues(alpha: 0.16),
                    spreadRadius: 3)
              ],
            ),
            child: initials == null
                ? const Icon(Icons.person_outline_rounded,
                    size: 30, color: Color(0xFFA0AEC0))
                : Text(initials!,
                    style: displayFont(const TextStyle(
                        color: AppColors.primary,
                        fontSize: 24,
                        fontWeight: FontWeight.w800))),
          ),
          if (tierColor != null)
            Positioned(
              right: -1,
              bottom: 1,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: tierColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primaryDark, width: 3),
                ),
              ),
            ),
        ]),
      );
}

String _initials(String name) => name
    .split(RegExp(r'\s+'))
    .where((w) => w.isNotEmpty)
    .take(2)
    .map((w) => w[0].toUpperCase())
    .join();

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader(
      {required this.name, required this.phone, required this.tierCode});
  final String name;
  final String phone;
  final String tierCode;

  @override
  Widget build(BuildContext context) {
    final tier = loyaltyTierFor(tierCode);
    final shownPhone = phone.startsWith('+') ? phone : '+221 $phone';
    return Row(children: [
      _Avatar(
          initials: _initials(name),
          tierColor: loyaltyTierColors[tier.code] ?? AppColors.primary),
      const SizedBox(width: 14),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Semantics(
            header: true,
            child: Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: displayFont(const TextStyle(
                    color: AppColors.white,
                    fontSize: 25,
                    height: 1.05,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3))),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(shownPhone,
              style: const TextStyle(
                  color: _onBand,
                  fontSize: 13.5,
                  fontFeatures: [FontFeature.tabularFigures()])),
        ]),
      ),
    ]);
  }
}

class _GuestHeader extends StatelessWidget {
  const _GuestHeader({required this.onSignIn, required this.onSignUp});
  final VoidCallback onSignIn;
  final VoidCallback onSignUp;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const _Avatar(),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text('Bienvenue chez LO',
                          style: displayFont(const TextStyle(
                              color: AppColors.white,
                              fontSize: 25,
                              height: 1.05,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3))),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    const Text('Vous naviguez en invité',
                        style: TextStyle(color: _onBand, fontSize: 13.5)),
                  ]),
            ),
          ]),
          const SizedBox(height: AppSpacing.lg),
          const Text(
              'Connectez-vous pour suivre vos achats, retrouver vos favoris '
              'et cumuler des points LO+ à chaque commande.',
              style: TextStyle(color: _onBand, fontSize: 14.5, height: 1.5)),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.white,
                  foregroundColor: AppColors.primaryDark,
                  minimumSize: const Size(0, 48),
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
                onPressed: onSignIn,
                child: const Text('Se connecter'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.white,
                  minimumSize: const Size(0, 48),
                  shape: const StadiumBorder(),
                  side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.35), width: 1.5),
                  textStyle: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
                onPressed: onSignUp,
                child: const Text('Créer un compte'),
              ),
            ),
          ]),
        ],
      );
}

/// White LO+ card straddling the band: tier, balance and its value, progress
/// to the next tier, then three shortcuts.
class _MemberCard extends StatelessWidget {
  const _MemberCard({required this.loyalty});
  final LoyaltySummary loyalty;

  @override
  Widget build(BuildContext context) {
    final tier = loyaltyTierFor(loyalty.tierCode);
    final next = nextLoyaltyTier(loyalty.tierCode);
    final tierColor = loyaltyTierColors[tier.code] ?? AppColors.primary;
    final progress = next == null
        ? 1.0
        : ((loyalty.spend12MonthsXof - tier.minSpendXof) /
                (next.minSpendXof - tier.minSpendXof))
            .clamp(0.0, 1.0);
    final note = next == null
        ? 'Palier maximum atteint.'
        : 'Encore ${formatXof(next.minSpendXof - loyalty.spend12MonthsXof)} '
            "d'achats sur 12 mois pour passer ${next.name}.";
    final animate = !MediaQuery.of(context).disableAnimations;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
              color: Color(0x40050A28),
              offset: Offset(0, 20),
              blurRadius: 40,
              spreadRadius: -26),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(9, 5, 11, 5),
                      decoration: BoxDecoration(
                          color: _mist,
                          borderRadius: BorderRadius.circular(AppRadii.pill)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                                color: tierColor, shape: BoxShape.circle)),
                        const SizedBox(width: 7),
                        Text('Membre ${tier.name}',
                            style: const TextStyle(
                                color: AppColors.text,
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
                      ]),
                    ),
                    const SizedBox(height: 10),
                    const Text('Solde LO+',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 12.5)),
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(text: '${loyalty.points}'),
                        const TextSpan(
                            text: ' points',
                            style: TextStyle(fontSize: 16, letterSpacing: 0)),
                      ]),
                      style: displayFont(const TextStyle(
                          color: AppColors.text,
                          fontSize: 44,
                          height: 1,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.8,
                          fontFeatures: [FontFeature.tabularFigures()])),
                    ),
                  ]),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child:
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                const Text('Valeur en caisse',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12.5)),
                const SizedBox(height: 2),
                Text(formatXof(loyalty.points * _pointValueXof),
                    style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        fontFeatures: [FontFeature.tabularFigures()])),
              ]),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (next != null) ...[
              Row(children: [
                Text(tier.name,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
                const Spacer(),
                Text(next.name,
                    style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 7),
            ],
            Semantics(
              label: note,
              excludeSemantics: true,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: animate ? 0 : progress, end: progress),
                duration: const Duration(milliseconds: 900),
                curve: const Cubic(.2, .8, .2, 1),
                builder: (context, value, _) => ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: LinearProgressIndicator(
                    value: value,
                    minHeight: 8,
                    backgroundColor: _mist,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(note, style: AppText.caption),
          ]),
        ),
        const Divider(height: 1, color: AppColors.border),
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _CardAction(Icons.qr_code_2_rounded, 'Ma carte',
                onTap: () => context.push('/lo/carte')),
            const VerticalDivider(width: 1, color: AppColors.border),
            _CardAction(Icons.history_rounded, 'Historique',
                onTap: () => context.push('/lo/historique')),
            const VerticalDivider(width: 1, color: AppColors.border),
            _CardAction(Icons.star_outline_rounded, 'Avantages',
                onTap: () => context.go('/lo?from=compte')),
          ]),
        ),
      ]),
    );
  }
}

class _CardAction extends StatelessWidget {
  const _CardAction(this.icon, this.label, {required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 21, color: AppColors.primary),
              const SizedBox(height: 5),
              Text(label,
                  style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      );
}

/// Order stages shown in the "Mes commandes" tiles.
enum _Stage { preparing, shipping, delivered, cancelled }

_Stage _stageOf(OrderSummary o) {
  final s = o.status.toLowerCase();
  if (s.contains('annul') || s.contains('cancel')) return _Stage.cancelled;
  if (s.contains('livr') || s.contains('deliver')) return _Stage.delivered;
  if (s.contains('rout') || s.contains('exp') || s.contains('ship')) {
    return _Stage.shipping;
  }
  return _Stage.preparing;
}

Map<_Stage, int> _countByStage(List<OrderSummary> orders) {
  final counts = {for (final s in _Stage.values) s: 0};
  for (final o in orders) {
    final stage = _stageOf(o);
    counts[stage] = counts[stage]! + 1;
  }
  return counts;
}

/// The order to feature: one on its way first, else one being prepared.
OrderSummary? _currentOrder(List<OrderSummary> orders) {
  for (final o in orders) {
    if (_stageOf(o) == _Stage.shipping) return o;
  }
  for (final o in orders) {
    if (_stageOf(o) == _Stage.preparing) return o;
  }
  return null;
}

class _CurrentOrder extends StatelessWidget {
  const _CurrentOrder({required this.order, required this.onTap});
  final OrderSummary order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shipping = _stageOf(order) == _Stage.shipping;
    final step = shipping ? 3 : 2;
    final item = order.items.isEmpty ? null : order.items.first;
    final others = order.items.length - 1;
    final what = item == null
        ? order.status
        : '${item.name}${others > 0 ? ' + $others autre${others > 1 ? 's' : ''}' : ''}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                          color: _mist,
                          borderRadius: BorderRadius.circular(14)),
                      clipBehavior: Clip.antiAlias,
                      child: ProductImage(
                        url: item?.imageUrl,
                        categoryId: item?.categoryId,
                        fit: BoxFit.cover,
                        iconSize: 26,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(order.number,
                                style: displayFont(const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3))),
                            Text(
                                shipping
                                    ? 'En route vers vous'
                                    : 'Préparation en cours',
                                style: const TextStyle(
                                    color: AppColors.text,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700)),
                            Text(what,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13)),
                          ]),
                    ),
                  ]),
                  const SizedBox(height: AppSpacing.md),
                  Semantics(
                    label: 'Étape $step sur 4',
                    excludeSemantics: true,
                    child: Row(children: [
                      for (var k = 1; k <= 4; k++) ...[
                        if (k > 1) const SizedBox(width: 4),
                        Expanded(
                          child: Container(
                            height: 5,
                            decoration: BoxDecoration(
                              color: k <= step ? AppColors.primary : _mist,
                              borderRadius: BorderRadius.circular(9),
                            ),
                          ),
                        ),
                      ],
                    ]),
                  ),
                ]),
          ),
        ),
      ),
    );
  }
}

/// Four stage tiles in a white card, with counts when known.
class _Stages extends StatelessWidget {
  const _Stages({required this.counts, required this.onOrders});
  final Map<_Stage, int>? counts;
  final VoidCallback onOrders;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        decoration: BoxDecoration(
            color: AppColors.white, borderRadius: BorderRadius.circular(20)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _StageTile(Icons.inventory_2_outlined, 'En préparation',
              count: counts?[_Stage.preparing], onTap: onOrders),
          _StageTile(Icons.local_shipping_outlined, 'En route',
              count: counts?[_Stage.shipping], onTap: onOrders),
          _StageTile(Icons.task_alt_outlined, 'Livrées',
              count: counts?[_Stage.delivered], onTap: onOrders),
          _StageTile(Icons.assignment_return_outlined, 'Retours et SAV',
              onTap: () => context.push('/sav')),
        ]),
      );
}

class _StageTile extends StatelessWidget {
  const _StageTile(this.icon, this.label, {this.count, required this.onTap});
  final IconData icon;
  final String label;
  final int? count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final n = count ?? 0;
    return Expanded(
      child: Semantics(
        button: true,
        label: n > 0 ? '$label, $n' : label,
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
            child: Column(children: [
              Badge(
                isLabelVisible: n > 0,
                backgroundColor: AppColors.primary,
                offset: const Offset(6, -6),
                label: Text('$n'),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                      color: _mist, borderRadius: BorderRadius.circular(13)),
                  child: Icon(icon, size: 22, color: AppColors.text),
                ),
              ),
              const SizedBox(height: 7),
              Text(label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.25,
                      fontWeight: FontWeight.w500)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Grey caption above a group, with an optional link on the right.
class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.label, {this.action, this.onAction});
  final String label;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(20, action == null ? 24 : 14,
            action == null ? 20 : 8, action == null ? 9 : 0),
        child: Row(children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(label,
                  style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600)),
            ),
          ),
          if (action != null)
            TextButton(
              style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  minimumSize: const Size(48, 44),
                  textStyle: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w700)),
              onPressed: onAction,
              child: Text(action!),
            ),
        ]),
      );
}

/// Rows grouped in a white rounded card.
class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Material(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0)
                const Divider(height: 1, indent: 56, color: AppColors.border),
              children[i],
            ],
          ]),
        ),
      );
}

class _HelpGroup extends StatelessWidget {
  const _HelpGroup();

  @override
  Widget build(BuildContext context) => _Group(children: [
        _Row(Icons.build_outlined, 'Service après-vente',
            onTap: () => context.push('/sav')),
        _Row(Icons.support_agent_outlined, 'Assistance Arame',
            value: '24 h/24', muted: true, onTap: () => context.push('/chat')),
        _Row(Icons.storefront_outlined, 'Nos showrooms',
            onTap: () => context.push('/showrooms')),
        _Row(Icons.help_outline, 'Questions fréquentes',
            onTap: () => context.push('/faq')),
        _Row(Icons.call_outlined, 'Contact',
            onTap: () => context.push('/contact')),
      ]);
}

class _Row extends StatelessWidget {
  const _Row(this.icon, this.label,
      {this.value,
      this.muted = false,
      this.danger = false,
      required this.onTap});
  final IconData icon;
  final String label;
  final String? value;

  /// Grey value (plain info) rather than a blue highlight.
  final bool muted;
  final bool danger;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = danger ? AppColors.danger : AppColors.text;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 54),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 10, 8),
          child: Row(children: [
            Icon(icon, size: 22, color: danger ? ink : AppColors.primary),
            const SizedBox(width: 18),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: ink,
                      fontSize: 15.5,
                      fontWeight: danger ? FontWeight.w700 : FontWeight.w500)),
            ),
            if (value != null) ...[
              const SizedBox(width: AppSpacing.sm),
              muted
                  ? Text(value!,
                      style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13.5,
                          fontFeatures: [FontFeature.tabularFigures()]))
                  : Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(AppRadii.pill)),
                      child: Text(value!,
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700)),
                    ),
            ],
            if (!danger) ...[
              const SizedBox(width: AppSpacing.xs),
              const Icon(Icons.chevron_right_rounded,
                  color: Color(0xFFA0AEC0), size: 22),
            ],
          ]),
        ),
      ),
    );
  }
}

/// Closing band with the legal link.
class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: AppSpacing.lg),
        child: Column(children: [
          TextButton(
              style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  minimumSize: const Size(48, 44),
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500)),
              onPressed: () => context.push('/legal'),
              child: const Text('Informations légales')),
          const Text('LO Multimédia', style: AppText.caption),
        ]),
      );
}

/// White notifications bell for the blue bar, with the unread count.
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
