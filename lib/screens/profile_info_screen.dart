import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/account/account_providers.dart';
import '../theme/tokens.dart';
import '../widgets/sub_page.dart';

/// "Informations personnelles": name, phone and the delivery address kept
/// from the last order. Read-only until the account API allows edits.
class ProfileInfoScreen extends ConsumerWidget {
  const ProfileInfoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionUserProvider);
    final last =
        user == null ? null : ref.watch(lastDeliveryProvider(user.phone));
    final phone = user == null
        ? ''
        : (user.phone.startsWith('+') ? user.phone : '+221 ${user.phone}');
    return SubPage(
      title: 'Informations personnelles',
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _InfoCard(children: [
            _InfoLine(Icons.person_outline_rounded, 'Nom', user?.name ?? '—'),
            _InfoLine(Icons.phone_outlined, 'Téléphone', phone),
            _InfoLine(
                Icons.location_on_outlined,
                'Adresse de livraison',
                last?.address ??
                    'Aucune adresse enregistrée pour le moment. Elle sera '
                        'retenue à votre prochaine commande.'),
          ]),
          const SizedBox(height: AppSpacing.lg),
          const Text('Pour modifier ces informations, contactez notre équipe.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => context.push('/contact'),
              icon: const Icon(Icons.call_outlined, size: 18),
              label: const Text('Nous contacter'),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, indent: 56, color: AppColors.border),
            children[i],
          ],
        ]),
      );
}

class _InfoLine extends StatelessWidget {
  const _InfoLine(this.icon, this.label, this.value);
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 22, color: AppColors.primary),
          const SizedBox(width: 18),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12.5)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
      );
}
