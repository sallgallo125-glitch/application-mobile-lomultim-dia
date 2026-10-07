import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../contracts/loyalty.dart';
import '../features/member/member_providers.dart';
import '../theme/tokens.dart';
import '../utils/currency.dart';
import '../utils/loyalty.dart';
import '../widgets/card_faces.dart';
import '../widgets/error_state.dart';
import '../widgets/loading_state.dart';
import '../widgets/sub_page.dart';

/// Digital LO+ card with a QR code to show at the till (site: MemberQr).
/// The token is short-lived, so it refreshes when it expires.
class LoyaltyCardScreen extends ConsumerStatefulWidget {
  const LoyaltyCardScreen({super.key});
  @override
  ConsumerState<LoyaltyCardScreen> createState() => _LoyaltyCardScreenState();
}

class _LoyaltyCardScreenState extends ConsumerState<LoyaltyCardScreen> {
  LoyaltyQrToken? _qr;
  Object? _error;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _refresh();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final qr = _qr;
      if (qr != null && DateTime.now().isAfter(qr.expiresAt)) {
        _refresh();
      } else if (mounted) {
        setState(() {}); // countdown
      }
    });
  }

  Future<void> _refresh() async {
    setState(() {
      _qr = null;
      _error = null;
    });
    try {
      final qr = await ref.read(loyaltyRepositoryProvider).createQrToken();
      if (mounted) setState(() => _qr = qr);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final member = ref.watch(loyaltyMemberProvider);
    return SubPage(
      title: 'Ma carte LO+',
      fallbackRoute: '/lo',
      child: member.when(
        loading: () => const LoadingState(
            layout: SkeletonLayout.account,
            label: 'Chargement de votre carte…'),
        error: (e, _) =>
            ErrorState(onRetry: () => ref.invalidate(loyaltyMemberProvider)),
        data: (m) {
          final tier = loyaltyTierFor(m.tierCode);
          final qr = _qr;
          final remaining = qr == null
              ? 0
              : qr.expiresAt.difference(DateTime.now()).inSeconds;
          return ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Center(
                  child: LoyaltyCardFace(
                    cardNumber: m.cardNumber,
                    memberName: m.holderName,
                    points: m.points,
                    tierCode: m.tierCode,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                    'Palier ${tier.name} · ${m.pendingPoints} points en attente',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: AppSpacing.lg),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(AppRadii.lg),
                        border: Border.all(color: AppColors.border)),
                    child: SizedBox.square(
                      dimension: 220,
                      child: qr != null
                          ? QrImageView(data: qr.token, size: 220)
                          : _error != null
                              ? Center(
                                  child: TextButton(
                                      onPressed: _refresh,
                                      child: const Text('Réessayer')))
                              : const Center(
                                  child: CircularProgressIndicator()),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  qr == null
                      ? 'Génération du code…'
                      : 'Présentez ce code en caisse · nouveau code dans ${remaining ~/ 60}:${(remaining % 60).toString().padLeft(2, '0')}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.md),
                const Text(
                    'Le code change toutes les 5 minutes : une capture d’écran ne permet pas de l’utiliser.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ]);
        },
      ),
    );
  }
}

/// Points history (site: MemberHistory).
class LoyaltyHistoryScreen extends ConsumerWidget {
  const LoyaltyHistoryScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movements = ref.watch(loyaltyMovementsProvider);
    return SubPage(
      title: 'Historique des points',
      fallbackRoute: '/lo',
      child: movements.when(
        loading: () => const LoadingState(label: 'Chargement de l’historique…'),
        error: (e, _) =>
            ErrorState(onRetry: () => ref.invalidate(loyaltyMovementsProvider)),
        data: (items) => items.isEmpty
            ? const Center(child: Text('Aucun mouvement pour le moment.'))
            : ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: items.length + 1,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.xs),
                itemBuilder: (context, i) {
                  if (i == items.length) {
                    return const Padding(
                      padding: EdgeInsets.only(top: AppSpacing.md),
                      child: Text(loyaltyRulesNote,
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                    );
                  }
                  final m = items[i];
                  final positive = m.points >= 0;
                  return Card(
                    child: ListTile(
                      title: Text(m.label),
                      subtitle:
                          Text(m.pending ? '${m.date} · en attente' : m.date),
                      trailing: Text('${positive ? '+' : ''}${m.points} pts',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: m.pending
                                  ? AppColors.textSecondary
                                  : positive
                                      ? AppColors.success
                                      : AppColors.danger)),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

/// Exchange points for rewards (site: MemberExchange).
class LoyaltyExchangeScreen extends ConsumerWidget {
  const LoyaltyExchangeScreen({super.key});

  Future<void> _convert(BuildContext context, WidgetRef ref,
      LoyaltyReward reward, int balance) async {
    int? points;
    if (reward.freeValue) {
      points = await showDialog<int>(
          context: context,
          builder: (_) => _VoucherDialog(min: reward.points, max: balance));
      if (points == null) return;
    } else {
      final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                title: Text(reward.title),
                content: Text('Échanger ${reward.points} points ?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Annuler')),
                  ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Échanger')),
                ],
              ));
      if (ok != true) return;
    }
    try {
      final voucher = await ref
          .read(loyaltyActionsProvider)
          .convert(reward.id, points: points);
      if (!context.mounted) return;
      await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
                title: const Text('Échange confirmé'),
                content: Text([
                  voucher.title,
                  if (voucher.valueXof != null) formatXof(voucher.valueXof!),
                  'Code : ${voucher.code}',
                  voucher.validUntil,
                ].join('\n')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK')),
                ],
              ));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(errorMessage(e, 'Échange impossible. Réessayez.'))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rewards = ref.watch(loyaltyRewardsProvider);
    final balance = ref.watch(loyaltyMemberProvider).value?.points ?? 0;
    return SubPage(
      title: 'Échanger mes points',
      subtitle:
          '$balance points disponibles · 1 point = ${formatXof(loyaltyPointValueXof)}',
      fallbackRoute: '/lo',
      child: rewards.when(
        loading: () => const LoadingState(label: 'Chargement des récompenses…'),
        error: (e, _) =>
            ErrorState(onRetry: () => ref.invalidate(loyaltyRewardsProvider)),
        data: (items) => ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, i) {
            final r = items[i];
            final affordable = balance >= r.points;
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.title,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(r.description,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 13)),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        children: [
                          Text(
                              r.freeValue
                                  ? 'Dès ${r.points} points'
                                  : '${r.points} points',
                              style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w800)),
                          if (r.stock != null && !r.outOfStock)
                            Text('${r.stock} en stock',
                                style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12)),
                          ElevatedButton(
                            onPressed: r.outOfStock || !affordable
                                ? null
                                : () => _convert(context, ref, r, balance),
                            child: Text(r.outOfStock
                                ? 'Épuisé'
                                : affordable
                                    ? 'Échanger'
                                    : 'Points insuffisants'),
                          ),
                        ],
                      ),
                    ]),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _VoucherDialog extends StatefulWidget {
  const _VoucherDialog({required this.min, required this.max});
  final int min;
  final int max;
  @override
  State<_VoucherDialog> createState() => _VoucherDialogState();
}

class _VoucherDialogState extends State<_VoucherDialog> {
  late double _points = widget.min.toDouble();
  @override
  Widget build(BuildContext context) {
    final points = _points.round();
    return AlertDialog(
      title: const Text("Bon d'achat"),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('$points points = ${formatXof(points * loyaltyPointValueXof)}',
            style: const TextStyle(fontWeight: FontWeight.w800)),
        if (widget.max > widget.min)
          Slider(
              value: _points,
              min: widget.min.toDouble(),
              max: widget.max.toDouble(),
              divisions: widget.max - widget.min,
              onChanged: (v) => setState(() => _points = v)),
      ]),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler')),
        ElevatedButton(
            onPressed: () => Navigator.pop(context, points),
            child: const Text('Échanger')),
      ],
    );
  }
}

/// Referral programme (site: MemberReferral).
class LoyaltyReferralScreen extends ConsumerWidget {
  const LoyaltyReferralScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(loyaltyReferralsProvider);
    return SubPage(
      title: 'Parrainage',
      fallbackRoute: '/lo',
      child: data.when(
        loading: () => const LoadingState(label: 'Chargement du parrainage…'),
        error: (e, _) =>
            ErrorState(onRetry: () => ref.invalidate(loyaltyReferralsProvider)),
        data: (r) {
          final message =
              'Rejoins LO+ avec mon code ${r.code} : tu gagnes ${r.refereePoints} points sur ton premier achat chez LO Multimédia.';
          return ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Text(
                    'Vous gagnez ${r.referrerPoints} points par filleul actif (premier achat d’au moins ${formatXof(r.minPurchaseXof)}). Votre filleul reçoit ${r.refereePoints} points.',
                    style: const TextStyle(fontSize: 15)),
                const SizedBox(height: AppSpacing.md),
                Card(
                  color: AppColors.primarySoft,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(children: [
                      const Text('Votre code',
                          style: TextStyle(color: AppColors.textSecondary)),
                      SelectableText(r.code,
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2)),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: [
                            OutlinedButton.icon(
                                onPressed: () async {
                                  await Clipboard.setData(
                                      ClipboardData(text: r.code));
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text('Code copié')));
                                  }
                                },
                                icon: const Icon(Icons.copy),
                                label: const Text('Copier')),
                            ElevatedButton.icon(
                                onPressed: () => launchUrl(
                                    Uri.parse(
                                        'https://wa.me/?text=${Uri.encodeComponent(message)}'),
                                    mode: LaunchMode.externalApplication),
                                icon: const Icon(Icons.share),
                                label: const Text('Partager sur WhatsApp')),
                          ]),
                    ]),
                  ),
                ),
                PageSectionTitle('Mes filleuls (${r.referrals.length})'),
                if (r.referrals.isEmpty)
                  const Text('Aucun filleul pour le moment.')
                else
                  for (final f in r.referrals)
                    Card(
                      child: ListTile(
                        title: Text(f.name),
                        subtitle: Text(f.status == 'ACTIVE'
                            ? 'Filleul actif'
                            : 'Inscrit · en attente de son premier achat'),
                        trailing: Text(f.points > 0 ? '+${f.points} pts' : '—',
                            style: const TextStyle(
                                color: AppColors.success,
                                fontWeight: FontWeight.w800)),
                      ),
                    ),
              ]);
        },
      ),
    );
  }
}

/// Challenges and badges (site: MemberChallenges).
class LoyaltyChallengesScreen extends ConsumerWidget {
  const LoyaltyChallengesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(loyaltyChallengesProvider);
    return SubPage(
      title: 'Défis et badges',
      fallbackRoute: '/lo',
      child: data.when(
        loading: () => const LoadingState(label: 'Chargement des défis…'),
        error: (e, _) => ErrorState(
            onRetry: () => ref.invalidate(loyaltyChallengesProvider)),
        data: (d) =>
            ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [
          const Text('Défis en cours',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: AppSpacing.sm),
          for (final c in d.challenges)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.label,
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text(
                          '${c.reward} · ${c.frequency == 'MONTHLY' ? 'chaque mois' : 'une fois'}',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                      const SizedBox(height: AppSpacing.sm),
                      LinearProgressIndicator(
                          value: (c.progress / c.target)
                              .clamp(0.0, 1.0)
                              .toDouble(),
                          color: c.done ? AppColors.success : AppColors.primary,
                          backgroundColor: AppColors.border),
                      const SizedBox(height: 2),
                      Text(
                          c.done
                              ? 'Défi réussi'
                              : c.unit == 'FCFA'
                                  ? '${formatXof(c.progress)} / ${formatXof(c.target)}'
                                  : '${c.progress} / ${c.target} ${c.unit}',
                          style: const TextStyle(fontSize: 12)),
                    ]),
              ),
            ),
          const PageSectionTitle('Mes badges'),
          for (final b in d.badges)
            Opacity(
              opacity: b.earned ? 1 : 0.55,
              child: Card(
                child: ListTile(
                  leading: Icon(
                      b.earned ? Icons.military_tech : Icons.lock_outline,
                      color:
                          b.earned ? AppColors.gold : AppColors.textSecondary),
                  title: Text(b.label),
                  subtitle: Text(b.condition),
                  trailing: b.points > 0 ? Text('+${b.points} pts') : null,
                ),
              ),
            ),
        ]),
      ),
    );
  }
}
