import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../contracts/loyalty.dart';
import '../features/member/member_providers.dart';
import '../theme/redesign_fonts.dart';
import '../theme/tokens.dart';
import '../utils/currency.dart';
import '../utils/loyalty.dart';
import '../widgets/app_header.dart';
import '../widgets/card_faces.dart';
import '../widgets/error_state.dart';
import '../widgets/loading_state.dart';
import '../widgets/sub_page.dart';
import '../features/account/account_providers.dart';

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
                  // Tap to see the back (QR code, number).
                  child: FlippableLoyaltyCard(
                    cardNumber: m.cardNumber,
                    // The signed-in customer's name (the demo API returns a fixed one).
                    memberName:
                        ref.watch(sessionUserProvider)?.name ?? m.holderName,
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

/// Points history (site: MemberHistory), as on the redesign mockup: a dark
/// balance card with the balance curve and totals, the points awaiting
/// delivery, then the movements filtered and grouped by month.
class LoyaltyHistoryScreen extends ConsumerStatefulWidget {
  const LoyaltyHistoryScreen({super.key});
  @override
  ConsumerState<LoyaltyHistoryScreen> createState() =>
      _LoyaltyHistoryScreenState();
}

enum _HistFilter { all, earned, used }

class _LoyaltyHistoryScreenState extends ConsumerState<LoyaltyHistoryScreen> {
  _HistFilter _filter = _HistFilter.all;

  @override
  Widget build(BuildContext context) {
    final movements = ref.watch(loyaltyMovementsProvider);
    final account = ref.watch(accountSummaryProvider).value;
    final balance = ref.watch(loyaltyMemberProvider).value?.points ??
        account?.loyalty.points;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RedesignFonts(
        child: SafeArea(
          bottom: false,
          child: Column(children: [
            _MockupBar(
                title: 'Historique des points',
                onBack: () =>
                    context.canPop() ? context.pop() : context.go('/lo')),
            movements.when(
              loading: () =>
                  const LoadingState(label: 'Chargement de l’historique…'),
              error: (e, _) => ErrorState(
                  onRetry: () => ref.invalidate(loyaltyMovementsProvider)),
              data: (items) {
                final h = _History.from(items, balance);
                final list = h.settled
                    .where((e) => switch (_filter) {
                          _HistFilter.all => true,
                          _HistFilter.earned => e.m.points > 0,
                          _HistFilter.used => e.m.points < 0,
                        })
                    .toList();
                final months = <String, List<_Entry>>{};
                for (final e in list) {
                  (months[e.month] ??= []).add(e);
                }
                return Expanded(
                  child: ListView(
                    padding: EdgeInsets.only(
                        bottom: AppSpacing.xl +
                            MediaQuery.of(context).padding.bottom),
                    children: [
                      if (h.expiry != null) _ExpiryNote(h.expiry!),
                      if (h.pending.isNotEmpty) ...[
                        const _HistTitle('En attente de livraison'),
                        _PendingBlock(h.pending),
                      ],
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                        child: _Segmented(
                          labels: const ['Tout', 'Gagnés', 'Utilisés'],
                          selected: _filter.index,
                          onSelect: (i) =>
                              setState(() => _filter = _HistFilter.values[i]),
                        ),
                      ),
                      if (months.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 28),
                          child: Text('Aucun mouvement pour ce filtre.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: _muted, fontSize: 14)),
                        )
                      else
                        for (final entry in months.entries) ...[
                          _MonthHeader(entry.key),
                          _BorderedList(children: [
                            for (final e in entry.value) _MovementRow(e),
                          ]),
                        ],
                    ],
                  ),
                );
              },
            ),
          ]),
        ),
      ),
    );
  }
}

/// Mockup colours for the history page.
const _mist = Color(0xFFF1F3F9);
const _faint = Color(0xFF8A91A8);

const _frMonths = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', //
  'août', 'septembre', 'octobre', 'novembre', 'décembre',
];
const _frShort = [
  'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', //
  'août', 'sept.', 'oct.', 'nov.', 'déc.',
];

/// "24 septembre 2026" (or "1er …") → date; null if it does not parse.
DateTime? _parseFrDate(String s) {
  final w = s.trim().split(RegExp(r'\s+'));
  if (w.length < 3) return null;
  final d = int.tryParse(w[0].replaceAll('er', ''));
  final m = _frMonths.indexOf(w[1].toLowerCase());
  final y = int.tryParse(w[2]);
  if (d == null || m < 0 || y == null) return null;
  return DateTime(y, m + 1, d);
}

String _shortDate(DateTime d) =>
    '${d.day == 1 ? '1er' : d.day} ${_frShort[d.month - 1]}';

/// One settled movement with its date and the balance right after it.
class _Entry {
  _Entry(this.m, this.date, this.balanceAfter);
  final LoyaltyMovement m;
  final DateTime? date;
  final int balanceAfter;

  String get shortDate => date == null ? m.date : _shortDate(date!);
  String get month {
    if (date == null) return 'Plus ancien';
    final name = _frMonths[date!.month - 1];
    return '${name[0].toUpperCase()}${name.substring(1)} ${date!.year}';
  }
}

/// Figures behind the page, from the movements (newest first).
class _History {
  _History(this.balance, this.settled, this.pending);

  factory _History.from(List<LoyaltyMovement> items, int? balance) {
    final settledMoves = items.where((m) => !m.pending).toList();
    final total = settledMoves.fold<int>(0, (s, m) => s + m.points);
    var after = balance ?? total;
    final settled = <_Entry>[];
    for (final m in settledMoves) {
      settled.add(_Entry(m, _parseFrDate(m.date), after));
      after -= m.points;
    }
    return _History(
        balance ?? total, settled, items.where((m) => m.pending).toList());
  }

  final int balance;
  final List<_Entry> settled;
  final List<LoyaltyMovement> pending;

  int get earned =>
      settled.where((e) => e.m.points > 0).fold(0, (s, e) => s + e.m.points);
  int get used =>
      settled.where((e) => e.m.points < 0).fold(0, (s, e) => s - e.m.points);
  int get pendingTotal => pending.fold(0, (s, m) => s + m.points);

  /// Points are valid 12 months: the oldest earning expires first.
  ({int points, DateTime date})? get expiry {
    final earning =
        settled.where((e) => e.m.points > 0 && e.date != null).toList();
    if (earning.isEmpty) return null;
    final oldest = earning.last;
    final d = oldest.date!;
    return (
      points: oldest.m.points,
      date: DateTime(d.year + 1, d.month, d.day)
    );
  }

  /// Dated movements, oldest first, for the curve.
  List<_Entry> get chronological =>
      settled.where((e) => e.date != null).toList().reversed.toList();
}

/// White bar of the mockup's sub pages: round grey back button and title.
class _MockupBar extends StatelessWidget {
  const _MockupBar({required this.title, required this.onBack});
  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 60),
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(children: [
          AppBackButton(onPressed: onBack),
          const SizedBox(width: 10),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: displayFont(const TextStyle(
                      color: AppColors.text,
                      fontSize: 21,
                      height: 1.1,
                      fontWeight: FontWeight.w700))),
            ),
          ),
        ]),
      );
}

class _ExpiryNote extends StatelessWidget {
  const _ExpiryNote(this.expiry);
  final ({int points, DateTime date}) expiry;

  @override
  Widget build(BuildContext context) {
    final d = expiry.date;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Text.rich(
        TextSpan(children: [
          const TextSpan(
              text: 'Vos points restent valables 12 mois. '
                  'Prochaine échéance : '),
          TextSpan(
              text: '${expiry.points} points le ${_shortDate(d)} '
                  '${d.year}',
              style: const TextStyle(color: _ink, fontWeight: FontWeight.w600)),
          const TextSpan(text: '.'),
        ]),
        style: const TextStyle(color: _muted, fontSize: 13, height: 1.35),
      ),
    );
  }
}

class _HistTitle extends StatelessWidget {
  const _HistTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
        child: Semantics(
          header: true,
          child: Text(title,
              style: displayFont(const TextStyle(
                  color: _ink,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2))),
        ),
      );
}

/// Grey segmented control (Tout / Gagnés / Utilisés).
class _Segmented extends StatelessWidget {
  const _Segmented(
      {required this.labels, required this.selected, required this.onSelect});
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
            color: _mist, borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Semantics(
                selected: i == selected,
                button: true,
                child: GestureDetector(
                  onTap: () => onSelect(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == selected ? AppColors.white : null,
                      borderRadius: BorderRadius.circular(11),
                      boxShadow: i == selected
                          ? const [
                              BoxShadow(
                                  color: Color(0x240E1430),
                                  offset: Offset(0, 1),
                                  blurRadius: 3)
                            ]
                          : null,
                    ),
                    child: Text(labels[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: i == selected ? _ink : _muted,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ),
        ]),
      );
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader(this.month);
  final String month;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
        child: Text(month,
            style: const TextStyle(
                color: _muted, fontSize: 13.5, fontWeight: FontWeight.w600)),
      );
}

/// Rounded card around a list of rows, separated by thin lines.
class _BorderedList extends StatelessWidget {
  const _BorderedList({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(20),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const Divider(height: 1, color: AppColors.border),
              children[i],
            ],
          ]),
        ),
      );
}

/// Row shape shared by the movements and the pending orders.
class _HhRow extends StatelessWidget {
  const _HhRow(
      {required this.icon,
      required this.title,
      this.sub,
      this.detail,
      required this.amount,
      required this.semantics,
      this.onTap});
  final IconData icon;
  final String title;
  final String? sub;
  final String? detail;
  final String amount;
  final String semantics;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(children: [
        Icon(icon, size: 22, color: _muted),
        const SizedBox(width: 14),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(
                    color: _ink,
                    fontSize: 14.5,
                    height: 1.3,
                    fontWeight: FontWeight.w600)),
            if (sub != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(sub!,
                    style: const TextStyle(
                        color: _muted, fontSize: 12.5, height: 1.35)),
              ),
            if (detail != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(detail!,
                    style: const TextStyle(
                        color: _faint,
                        fontSize: 12,
                        height: 1.35,
                        fontFeatures: [FontFeature.tabularFigures()])),
              ),
          ]),
        ),
        const SizedBox(width: 8),
        Text('$amount pts',
            style: const TextStyle(
                color: _ink,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()])),
      ]),
    );
    return Semantics(
      label: semantics,
      button: onTap != null,
      excludeSemantics: true,
      child: onTap == null ? row : InkWell(onTap: onTap, child: row),
    );
  }
}

class _PendingBlock extends StatelessWidget {
  const _PendingBlock(this.pending);
  final List<LoyaltyMovement> pending;

  @override
  Widget build(BuildContext context) => _BorderedList(children: [
        for (final m in pending)
          _HhRow(
            icon: Icons.schedule_rounded,
            // "Commande LO-… (en attente de livraison)" → "Commande LO-…".
            title: m.label.replaceAll(RegExp(r'\s*\(.*\)\s*$'), ''),
            sub: '${m.date}, crédités à la livraison',
            amount: '+${m.points}',
            semantics: '${m.label}, ${m.points} points crédités à la livraison',
            onTap: () => context.push('/commandes'),
          ),
      ]);
}

class _MovementRow extends StatelessWidget {
  const _MovementRow(this.e);
  final _Entry e;

  @override
  Widget build(BuildContext context) {
    final m = e.m;
    final l = m.label.toLowerCase();
    final icon = l.contains('parrain')
        ? Icons.group_add_outlined
        : m.points < 0
            ? Icons.local_offer_outlined
            : l.contains('commande') || l.contains('achat')
                ? Icons.storefront_outlined
                : Icons.star_outline_rounded;
    final positive = m.points > 0;
    final amount = '${positive ? '+' : '−'}${m.points.abs()}';
    return _HhRow(
      icon: icon,
      title: m.label,
      detail: e.shortDate,
      amount: amount,
      semantics: '${m.label}, ${m.date}, $amount points, '
          'solde après ${e.balanceAfter} points',
    );
  }
}

/// Referral programme (site: MemberReferral), as on the redesign mockup.
class LoyaltyReferralScreen extends ConsumerWidget {
  const LoyaltyReferralScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(loyaltyReferralsProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RedesignFonts(
        child: SafeArea(
          child: Column(children: [
            _MockupBar(
                title: 'Parrainage',
                onBack: () =>
                    context.canPop() ? context.pop() : context.go('/lo')),
            data.when(
              loading: () =>
                  const LoadingState(label: 'Chargement du parrainage…'),
              error: (e, _) => ErrorState(
                  onRetry: () => ref.invalidate(loyaltyReferralsProvider)),
              data: (r) {
                final message = 'Rejoins LO+ avec mon code ${r.code} : tu '
                    'gagnes ${r.refereePoints} points sur ton premier achat '
                    'chez LO Multimédia.';
                return Expanded(
                  child: Column(children: [
                    Expanded(
                      child: ListView(children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Semantics(
                                  header: true,
                                  child: Text(
                                      'Parrainez un proche, gagnez '
                                      '${r.referrerPoints} points',
                                      style: displayFont(const TextStyle(
                                          color: _ink,
                                          fontSize: 36,
                                          height: 1.02,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.7))),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                    'Votre filleul reçoit ${r.refereePoints} points '
                                    'dès son premier achat, et vous '
                                    '${r.referrerPoints} points, soit '
                                    '${formatXof(r.referrerPoints * loyaltyPointValueXof)} '
                                    'de réduction.',
                                    style: const TextStyle(
                                        color: _muted,
                                        fontSize: 15,
                                        height: 1.5)),
                              ]),
                        ),
                        _CodeTicket(code: r.code),
                        const _MockupSection('Comment ça se passe'),
                        const _SeqStep(1, 'Partagez votre code',
                            'Par WhatsApp, SMS ou de vive voix.'),
                        const _SeqStep(2, 'Votre proche l’utilise',
                            'À la création de son compte ou en caisse.'),
                        const _SeqStep(3, 'Vous gagnez tous les deux',
                            'Les points arrivent après son premier achat.'),
                        const SizedBox(height: AppSpacing.lg),
                      ]),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.white,
                            minimumSize: const Size(0, 52),
                            shape: const StadiumBorder(),
                            textStyle: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          onPressed: () => launchUrl(
                              Uri.parse('https://wa.me/?text='
                                  '${Uri.encodeComponent(message)}'),
                              mode: LaunchMode.externalApplication),
                          icon: const Icon(Icons.share_rounded, size: 20),
                          label: const Text('Partager mon code'),
                        ),
                      ),
                    ),
                  ]),
                );
              },
            ),
          ]),
        ),
      ),
    );
  }
}

const _muted = Color(0xFF59627F);
const _ink = Color(0xFF0E1430);
const _loTint = Color(0xFFE7EBFA);

/// Dashed blue ticket holding the referral code and a copy button.
class _CodeTicket extends StatelessWidget {
  const _CodeTicket({required this.code});
  final String code;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
        child: CustomPaint(
          foregroundPainter: _DashedBorderPainter(),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: _loTint, borderRadius: BorderRadius.circular(20)),
            child: Column(children: [
              const Text('Votre code de parrainage',
                  style: TextStyle(color: _muted, fontSize: 12.5, height: 1.4)),
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 12),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SelectableText(code,
                      style: displayFont(const TextStyle(
                          color: AppColors.primaryDark,
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.4))),
                ),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.white,
                  foregroundColor: AppColors.primaryDark,
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(
                      fontSize: 14.5, fontWeight: FontWeight.w600),
                ),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: code));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Code $code copié')));
                  }
                },
                icon: const Icon(Icons.copy_rounded, size: 20),
                label: const Text('Copier le code'),
              ),
            ]),
          ),
        ),
      );
}

/// 2 px blue dashed rounded border (Flutter has no dashed BoxBorder).
class _DashedBorderPainter extends CustomPainter {
  static const color = AppColors.primary;
  static const width = 2.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
        (Offset.zero & size).deflate(width / 2), const Radius.circular(20));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    for (final metric in (Path()..addRRect(rect)).computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 9) {
        canvas.drawPath(metric.extractPath(d, d + 5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) => false;
}

class _MockupSection extends StatelessWidget {
  const _MockupSection(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 28, 16, 12),
        child: Semantics(
          header: true,
          child: Text(title,
              style: displayFont(const TextStyle(
                  color: _ink,
                  fontSize: 22,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2))),
        ),
      );
}

/// Numbered step: blue round number, bold title, grey text.
class _SeqStep extends StatelessWidget {
  const _SeqStep(this.n, this.title, this.text);
  final int n;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
                color: AppColors.primary, shape: BoxShape.circle),
            child: Text('$n',
                style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: const TextStyle(
                      color: _ink,
                      fontSize: 14.5,
                      height: 1.45,
                      fontWeight: FontWeight.w700)),
              Text(text,
                  style: const TextStyle(
                      color: _muted, fontSize: 13.5, height: 1.45)),
            ]),
          ),
        ]),
      );
}
