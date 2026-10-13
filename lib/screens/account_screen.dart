import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/account/account_providers.dart';
import '../theme/tokens.dart';
import '../utils/loyalty.dart';
import '../widgets/app_header.dart';
import '../widgets/error_state.dart';
import '../widgets/loading_state.dart';
import '../widgets/header_actions.dart';
import '../widgets/nav_clearance.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(signedInProvider);
    final summary = ref.watch(accountSummaryProvider);
    return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
            bottom: false,
            child: Column(children: [
              AppHeader(title: 'Mon compte', actions: [
                notificationsHeaderAction(context, ref),
                cartHeaderAction(context, ref),
              ]),
              if (!signedIn)
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.lg,
                        AppSpacing.lg,
                        AppSpacing.lg + navBarClearance(context)),
                    children: [
                      _Entrance(
                        child: _GuestWelcomeCard(
                          onSignIn: () => context.push('/connexion'),
                          onRegister: () => context.push('/inscription'),
                        ),
                      ),
                      _MenuGroup(title: 'Achats & Suivi', items: [
                        _Menu(
                          icon: Icons.receipt_long_outlined,
                          label: 'Mes commandes',
                          onTap: () => context.push('/commandes'),
                        ),
                        _Menu(
                          icon: Icons.local_shipping_outlined,
                          label: 'Suivre une commande (sans compte)',
                          onTap: () => context.push('/suivi'),
                        ),
                      ]),
                      _MenuGroup(title: 'Service client & Aide', items: [
                        _Menu(
                          icon: Icons.support_agent,
                          label: 'Aide & assistance Arame',
                          onTap: () => context.push('/chat'),
                        ),
                        _Menu(
                          icon: Icons.location_on_outlined,
                          label: 'Nos showrooms',
                          onTap: () => context.push('/showrooms'),
                        ),
                        _Menu(
                          icon: Icons.help_outline,
                          label: 'Questions fréquentes',
                          onTap: () => context.push('/faq'),
                        ),
                        _Menu(
                          icon: Icons.contact_phone_outlined,
                          label: 'Contact',
                          onTap: () => context.push('/contact'),
                        ),
                      ]),
                    ],
                  ),
                )
              else
                summary.when(
                    loading: () => const LoadingState(
                        layout: SkeletonLayout.account,
                        label: 'Chargement de votre compte…'),
                    error: (error, stackTrace) => ErrorState(
                        onRetry: () => ref.invalidate(accountSummaryProvider)),
                    data: (account) => Expanded(
                            child: ListView(
                                padding: EdgeInsets.fromLTRB(
                                    AppSpacing.lg,
                                    AppSpacing.lg,
                                    AppSpacing.lg,
                                    AppSpacing.lg + navBarClearance(context)),
                                children: [
                              _Entrance(
                                child: _AccountHero(
                                  name: ref.watch(sessionUserProvider)?.name ??
                                      account.name,
                                  phone:
                                      ref.watch(sessionUserProvider)?.phone ??
                                          account.phone,
                                  tier: loyaltyTierFor(account.loyalty.tierCode)
                                      .name,
                                  orders: '${account.ordersCount}',
                                  points: '${account.loyalty.points}',
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Row(
                                children: [
                                  Expanded(
                                    child: _QuickAction(
                                      icon: Icons.receipt_long_rounded,
                                      label: 'Mes commandes',
                                      onTap: () => context.push('/commandes'),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: _QuickAction(
                                      icon: Icons.favorite_border_rounded,
                                      label: 'Mes favoris',
                                      onTap: () => context.push('/favoris'),
                                    ),
                                  ),
                                ],
                              ),
                              _MenuGroup(title: 'Mes achats', items: [
                                _Menu(
                                    icon: Icons.notifications_none,
                                    label: 'Notifications',
                                    onTap: () =>
                                        context.push('/notifications')),
                              ]),
                              _MenuGroup(title: 'Fidélité et cadeaux', items: [
                                _Menu(
                                    icon: Icons.workspace_premium_outlined,
                                    label: 'Programme LO+',
                                    onTap: () => context.go('/lo')),
                                _Menu(
                                    icon: Icons.card_giftcard,
                                    label: 'Mes cartes cadeaux',
                                    onTap: () =>
                                        context.push('/cartes-cadeaux')),
                              ]),
                              _MenuGroup(title: 'Service client', items: [
                                _Menu(
                                    icon: Icons.build_outlined,
                                    label: 'Service après-vente',
                                    onTap: () => context.push('/sav')),
                                _Menu(
                                    icon: Icons.support_agent,
                                    label: 'Aide & assistance Arame',
                                    onTap: () => context.push('/chat')),
                                _Menu(
                                    icon: Icons.location_on_outlined,
                                    label: 'Nos showrooms',
                                    onTap: () => context.push('/showrooms')),
                              ]),
                              _MenuGroup(title: 'Aide et informations', items: [
                                _Menu(
                                    icon: Icons.help_outline,
                                    label: 'Questions fréquentes',
                                    onTap: () => context.push('/faq')),
                                _Menu(
                                    icon: Icons.contact_phone_outlined,
                                    label: 'Contact',
                                    onTap: () => context.push('/contact')),
                                _Menu(
                                    icon: Icons.gavel_outlined,
                                    label: 'Informations légales',
                                    onTap: () => context.push('/legal')),
                              ]),
                              const SizedBox(height: AppSpacing.lg),
                              OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.danger,
                                      side: const BorderSide(
                                          color: AppColors.danger)),
                                  onPressed: () => ref
                                      .read(sessionUserProvider.notifier)
                                      .state = null,
                                  icon: const Icon(Icons.logout),
                                  label: const Text('Se déconnecter'))
                            ])))
            ])));
  }
}

class _GuestWelcomeCard extends StatelessWidget {
  const _GuestWelcomeCard({required this.onSignIn, required this.onRegister});

  final VoidCallback onSignIn;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              Container(
                width: 76,
                height: 76,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: Image.asset('assets/images/logo.png', height: 46),
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'Bienvenue sur LoMultimedia',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'Connectez-vous pour retrouver vos achats et cumuler vos points LO+.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onSignIn,
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('Se connecter'),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onRegister,
                  child: const Text('Créer un compte'),
                ),
              ),
            ],
          ),
        ),
      );
}

class _Entrance extends StatelessWidget {
  const _Entrance({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration:
          reduceMotion ? Duration.zero : const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      builder: (context, progress, child) => Opacity(
        opacity: progress,
        child: Transform.translate(
          offset: Offset(0, 10 * (1 - progress)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

class _AccountHero extends StatelessWidget {
  const _AccountHero({
    required this.name,
    required this.phone,
    required this.tier,
    required this.orders,
    required this.points,
  });

  final String name;
  final String phone;
  final String tier;
  final String orders;
  final String points;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primaryDark, AppColors.primary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppRadii.xl),
          boxShadow: const [
            BoxShadow(
              color: Color(0x24434F9F),
              blurRadius: 16,
              offset: Offset(0, 7),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 27,
                    backgroundColor: Colors.white.withValues(alpha: .18),
                    child: Text(
                      name.trim().isEmpty
                          ? '?'
                          : name.trim().characters.first.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Bonjour,',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          phone,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: AppColors.goldOnDark.withValues(alpha: .18),
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      border: Border.all(
                          color: AppColors.goldOnDark.withValues(alpha: .5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.workspace_premium_rounded,
                            color: AppColors.goldOnDark, size: 16),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          tier,
                          style: const TextStyle(
                            color: AppColors.goldOnDark,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: _HeroStat(value: orders, label: 'Commandes'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _HeroStat(value: points, label: 'Points LO+'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _HeroStat(value: tier, label: 'Palier'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(color: Colors.white.withValues(alpha: .18)),
        ),
        child: Column(
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
      );
}

class _QuickAction extends StatefulWidget {
  const _QuickAction(
      {required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  State<_QuickAction> createState() => _QuickActionState();
}

class _QuickActionState extends State<_QuickAction> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.of(context).disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 120);
    return AnimatedScale(
      scale: _pressed ? .97 : 1,
      duration: duration,
      curve: Curves.easeOutCubic,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: AppSpacing.md),
            child: Row(
              children: [
                Icon(widget.icon, color: AppColors.primaryDark, size: 22),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    widget.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textSecondary, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A titled card grouping related menu entries.
class _MenuGroup extends StatelessWidget {
  const _MenuGroup({required this.title, required this.items});
  final String title;
  final List<_Menu> items;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: AppSpacing.lg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(
                left: AppSpacing.xs, bottom: AppSpacing.xs),
            child: Row(
              children: [
                Text(title.toUpperCase(),
                    style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .6)),
              ],
            ),
          ),
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 56),
                items[i],
              ]
            ]),
          ),
        ]),
      );
}

class _Menu extends StatelessWidget {
  const _Menu({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      leading: Icon(icon, color: AppColors.primaryDark, size: 22),
      title: Text(label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_right_rounded,
          color: AppColors.textSecondary),
      onTap: onTap);
}
