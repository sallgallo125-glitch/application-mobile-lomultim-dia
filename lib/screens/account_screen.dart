import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../contracts/account.dart';
import '../features/account/account_providers.dart';
import '../features/customer/customer_providers.dart';
import '../theme/redesign_fonts.dart';
import '../theme/tokens.dart';
import '../utils/loyalty.dart';
import '../widgets/commerce/product_image.dart';
import '../widgets/error_state.dart';
import '../widgets/loading_state.dart';
import '../widgets/header_actions.dart';
import '../widgets/nav_clearance.dart';

/// Pale blue-grey page background; the white groups sit on it.
const _mist = Color(0xFFF1F3F9);

/// Icon tile behind the shortcuts and the order stages.
const _tileFill = Color(0x80F1F3F9);

/// Secondary text: darker than the shared grey for small sizes (6:1 on white).
const _grey = Color(0xFF566073);

/// Chevrons and empty-avatar icon (3.6:1 on white).
const _chevron = Color(0xFF7B8794);

/// Secondary text on the white band.
const _onBand = _grey;

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(signedInProvider);
    final summary = ref.watch(accountSummaryProvider);
    // The white band runs up under the status bar and carries the bell
    // (the cart is already in the bottom bar).
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.white,
        body: RedesignFonts(
            child: SafeArea(
          bottom: false,
          child: ColoredBox(
            color: AppColors.white,
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
                            tierCode: account.loyalty.tierCode,
                            favorites: favorites),
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
                          const _GroupLabel('Mon profil'),
                          _Group(children: [
                            _Row(Icons.person_outline_rounded,
                                'Informations personnelles',
                                onTap: () => context.push('/compte/infos')),
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
/// then [children].
class _AccountScroll extends StatefulWidget {
  const _AccountScroll({
    required this.collapsedTitle,
    required this.header,
    required this.children,
  });

  final String collapsedTitle;
  final Widget header;
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
    return CustomScrollView(controller: _controller, slivers: [
      SliverAppBar(
        pinned: true,
        primary: false,
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
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
              style: displayFont(AppText.pageTitle.copyWith(letterSpacing: -0.2))),
        ),
        actions: const [_BellButton(), SizedBox(width: AppSpacing.xs)],
      ),
      SliverToBoxAdapter(
        // The top border is pushed out of the clip so only the sides and
        // the rounded bottom show.
        child: ClipRect(
          child: Transform.translate(
            offset: const Offset(0, -1),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                border: Border.all(color: AppColors.border),
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
              clipBehavior: Clip.antiAlias,
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, 18),
              child: widget.header,
            ),
          ),
        ),
      ),
      SliverList(delegate: SliverChildListDelegate(widget.children)),
      SliverToBoxAdapter(child: SizedBox(height: navBarClearance(context))),
    ]);
  }
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
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: initials == null
                ? const Icon(Icons.person_outline_rounded,
                    size: 30, color: _chevron)
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
                  border: Border.all(color: AppColors.white, width: 3),
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
      {required this.name,
      required this.phone,
      required this.tierCode,
      required this.favorites});
  final String name;
  final String phone;
  final String tierCode;
  final int favorites;

  @override
  Widget build(BuildContext context) {
    final tier = loyaltyTierFor(tierCode);
    final shownPhone = phone.startsWith('+') ? phone : '+221 $phone';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        _Avatar(
            initials: _initials(name),
            tierColor: loyaltyTierColors[tier.code] ?? AppColors.primary),
        const SizedBox(width: 14),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Semantics(
              header: true,
              child: Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: displayFont(const TextStyle(
                      color: AppColors.text,
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
      ]),
      const SizedBox(height: AppSpacing.lg),
      Row(children: [
        _Shortcut(Icons.inventory_2_outlined, 'Commandes',
            onTap: () => context.push('/commandes')),
        _Shortcut(Icons.vpn_key_outlined, 'Mes codes',
            onTap: () => context.push('/mes-codes')),
        _Shortcut(Icons.favorite_border, 'Favoris',
            count: favorites, onTap: () => context.push('/favoris')),
        _Shortcut(Icons.card_giftcard_outlined, 'Cartes cadeaux',
            onTap: () => context.push('/cartes-cadeaux')),
        _Shortcut(Icons.group_add_outlined, 'Parrainage',
            onTap: () => context.push('/lo/parrainage')),
      ]),
    ]);
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut(this.icon, this.label, {this.count, required this.onTap});
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
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(children: [
              Badge(
                isLabelVisible: n > 0,
                backgroundColor: AppColors.primary,
                offset: const Offset(6, -6),
                label: Text('$n'),
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                      color: _tileFill, shape: BoxShape.circle),
                  child: Icon(icon, size: 22, color: AppColors.text),
                ),
              ),
              const SizedBox(height: 6),
              Text(label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 12,
                      height: 1.2,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ),
    );
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
                              color: AppColors.text,
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
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
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
                  foregroundColor: AppColors.primary,
                  minimumSize: const Size(0, 48),
                  shape: const StadiumBorder(),
                  side: const BorderSide(color: AppColors.primary, width: 1.5),
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
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.border)),
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
                                    color: _grey,
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
                                    color: _grey, fontSize: 13)),
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
            color: AppColors.white,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(20)),
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
                      color: _tileFill,
                      borderRadius: BorderRadius.circular(13)),
                  child: Icon(icon, size: 22, color: AppColors.text),
                ),
              ),
              const SizedBox(height: 7),
              Text(label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 12,
                      height: 1.2,
                      fontWeight: FontWeight.w600)),
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
                      color: _grey,
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
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AppColors.border)),
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
            Icon(icon, size: 22, color: ink),
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
                          color: _grey,
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
                  color: _chevron, size: 22),
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
                  foregroundColor: _grey,
                  minimumSize: const Size(48, 44),
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500)),
              onPressed: () => context.push('/legal'),
              child: const Text('Informations légales')),
          const Text('LO Multimédia',
              style: TextStyle(fontSize: 12, color: _grey, height: 1.35)),
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
            color: AppColors.text, size: 26),
      ),
    );
  }
}
