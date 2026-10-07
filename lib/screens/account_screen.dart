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
                    child: Center(
                        child: ElevatedButton(
                            onPressed: () => context.push('/connexion'),
                            child: const Text('Se connecter'))))
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
                              _Profile(
                                  ref.watch(sessionUserProvider)?.name ??
                                      account.name,
                                  ref.watch(sessionUserProvider)?.phone ??
                                      account.phone,
                                  loyaltyTierFor(account.loyalty.tierCode)
                                      .name),
                              const SizedBox(height: AppSpacing.md),
                              Card(
                                  child: Padding(
                                      padding:
                                          const EdgeInsets.all(AppSpacing.md),
                                      child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceAround,
                                          children: [
                                            _Stat('${account.ordersCount}',
                                                'Commandes'),
                                            _Stat('${account.loyalty.points}',
                                                'Points Lo+'),
                                            _Stat(
                                                loyaltyTierFor(account
                                                        .loyalty.tierCode)
                                                    .name,
                                                'Palier')
                                          ]))),
                              _MenuGroup(title: 'Mes achats', items: [
                                _Menu(
                                    icon: Icons.receipt_long_outlined,
                                    label: 'Mes commandes',
                                    onTap: () => context.push('/commandes')),
                                _Menu(
                                    icon: Icons.favorite_outline,
                                    label: 'Mes favoris',
                                    onTap: () => context.push('/favoris')),
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

class _Profile extends StatelessWidget {
  const _Profile(this.name, this.phone, this.level);
  final String name;
  final String phone;
  final String level;
  @override
  Widget build(BuildContext context) => Row(children: [
        CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.primary,
            child: Text(name[0],
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w800))),
        const SizedBox(width: AppSpacing.md),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          Text('$phone · LO+ $level',
              style: const TextStyle(color: AppColors.textSecondary))
        ]))
      ]);
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label);
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Expanded(
          child: Column(children: [
        Text(value,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: AppColors.primary,
                fontSize: 17,
                fontWeight: FontWeight.w800)),
        Text(label,
            textAlign: TextAlign.center,
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 11))
      ]));
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
            child: Text(title.toUpperCase(),
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .6)),
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
      leading: Icon(icon, color: AppColors.primary),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap);
}
