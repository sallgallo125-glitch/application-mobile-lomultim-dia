import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../contracts/account.dart';
import '../features/account/account_providers.dart';
import '../features/customer/customer_providers.dart';
import '../theme/redesign_fonts.dart';
import '../theme/tokens.dart';
import '../utils/currency.dart';
import '../utils/loyalty.dart';
import '../widgets/app_header.dart';
import '../widgets/empty_state.dart';
import '../widgets/nav_clearance.dart';

/// Visual kind of a notification, guessed from its wording (the stored
/// notifications carry no explicit type).
enum _Kind {
  order('Commandes', Icons.local_shipping_outlined, AppColors.primary,
      '/commandes'),
  loyalty('LO+', Icons.star_outline_rounded, AppColors.gold, '/lo'),
  promo('Offres', Icons.local_offer_outlined, AppColors.danger, '/boutique'),
  info('Infos', Icons.notifications_none, AppColors.textSecondary, null);

  const _Kind(this.label, this.icon, this.color, this.defaultLink);
  final String label;
  final IconData icon;
  final Color color;
  final String? defaultLink;

  static _Kind of(AppNotification item) {
    final text = '${item.title} ${item.message}'.toLowerCase();
    if (RegExp(r'lo\+|point|palier|fidélit').hasMatch(text)) return loyalty;
    if (RegExp(r'commande|livr|expédi|colis|retrait').hasMatch(text)) {
      return order;
    }
    if (RegExp(r'promo|offre|%|réduc|solde|vente').hasMatch(text)) {
      return promo;
    }
    return info;
  }
}

/// "il y a 2 h", "hier", "12/10".
String _relativeDate(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return "à l'instant";
  if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
  if (diff.inDays < 2) return 'hier';
  if (diff.inDays < 7) return 'il y a ${diff.inDays} j';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}';
}

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  void _replace(WidgetRef ref, List<AppNotification> next) =>
      ref.read(notificationsProvider.notifier).state = next;

  AppNotification _asRead(AppNotification n) => (
        title: n.title,
        message: n.message,
        read: true,
        date: n.date,
        link: n.link,
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(notificationsProvider);
    final prefs = ref.watch(notificationPrefsProvider);

    // Indexes of the visible notifications, newest first.
    final visible = [
      for (var i = 0; i < items.length; i++)
        if (prefs.contains(_Kind.of(items[i]).name)) i
    ]..sort((a, b) => items[b].date.compareTo(items[a].date));

    void open(int index) {
      final item = items[index];
      if (!item.read) {
        _replace(ref, [...items]..[index] = _asRead(item));
      }
      final link = item.link ?? _Kind.of(item).defaultLink;
      if (link == null) return;
      // Bottom-bar tabs live in the shell: switch tab instead of pushing.
      const tabs = ['/', '/boutique', '/panier', '/lo', '/compte'];
      tabs.contains(Uri.parse(link).path)
          ? context.go(link)
          : context.push(link);
    }

    void remove(int index) {
      final removed = items[index];
      _replace(ref, [...items]..removeAt(index));
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
            // With an action the bar persists by default: let it time out.
            persist: false,
            duration: const Duration(seconds: 4),
            content: const Text('Notification supprimée'),
            action: SnackBarAction(
                label: 'Annuler',
                onPressed: () {
                  final current = [...ref.read(notificationsProvider)];
                  current.insert(index.clamp(0, current.length), removed);
                  _replace(ref, current);
                })));
    }

    // Sober bottom-sheet confirmation, then "Annuler" like swipe-delete.
    Future<void> clearAll() async {
      final ok = await showModalBottomSheet<bool>(
          context: context,
          backgroundColor: AppColors.white,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
          builder: (sheet) => SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
                      AppSpacing.xl, AppSpacing.lg, AppSpacing.md),
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                            'Supprimer ${items.length > 1 ? 'les ${items.length} notifications' : 'la notification'} ?',
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w800)),
                        const SizedBox(height: AppSpacing.xs),
                        const Text('Elles disparaîtront de cette page.',
                            style: AppText.bodyMuted),
                        const SizedBox(height: AppSpacing.lg),
                        ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.danger,
                                foregroundColor: AppColors.white),
                            onPressed: () => Navigator.pop(sheet, true),
                            child: const Text('Supprimer')),
                        TextButton(
                            style: TextButton.styleFrom(
                                foregroundColor: AppColors.text),
                            onPressed: () => Navigator.pop(sheet, false),
                            child: const Text('Annuler')),
                      ]),
                ),
              ));
      if (ok != true || !context.mounted) return;
      final removed = items;
      _replace(ref, const []);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
            // With an action the bar persists by default: let it time out.
            persist: false,
            duration: const Duration(seconds: 4),
            content: const Text('Notifications supprimées'),
            action: SnackBarAction(
                label: 'Annuler', onPressed: () => _replace(ref, removed))));
    }

    final allUnread = items.where((n) => !n.read).length;
    final orders = ref.watch(ordersProvider).value ?? const <OrderSummary>[];
    final fresh = [
      for (final i in visible)
        if (!items[i].read) i
    ];
    final earlier = [
      for (final i in visible)
        if (items[i].read) i
    ];

    void openPrefs() => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => _PrefsSheet(
            onClearAll: items.isEmpty
                ? null
                : () {
                    Navigator.pop(context);
                    clearAll();
                  }));

    Widget tile(int index) => Dismissible(
        key: ObjectKey(items[index]),
        direction: DismissDirection.endToStart,
        background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: AppSpacing.xl),
            color: AppColors.danger,
            child: const Icon(Icons.delete_outline, color: Colors.white)),
        onDismissed: (_) => remove(index),
        child: _NotificationTile(
            item: items[index], orders: orders, onTap: () => open(index)));

    Widget section(String title, List<int> indexes, {Widget? trailing}) =>
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 8, 8),
            child: Row(children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(title.toUpperCase(),
                      style: const TextStyle(
                          color: _muted,
                          fontSize: 12,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w700)),
                ),
              ),
              if (trailing != null) trailing,
            ]),
          ),
          for (final (k, i) in indexes.indexed) ...[
            if (k > 0)
              const Divider(
                  height: 1,
                  indent: 72,
                  endIndent: 20,
                  color: AppColors.border),
            tile(i),
          ],
        ]);

    return Scaffold(
        backgroundColor: AppColors.background,
        body: RedesignFonts(
          child: SafeArea(
              bottom: false,
              child: Column(children: [
                AppHeader(
                    title: 'Notifications',
                    subtitle: allUnread == 0
                        ? 'Tout est lu'
                        : '$allUnread non lue${allUnread > 1 ? 's' : ''}',
                    onBack: () => context.canPop()
                        ? context.pop()
                        : context.go('/compte'),
                    actions: [
                      HeaderAction(
                          icon: Icons.tune_rounded,
                          label: 'Réglages des notifications',
                          onPressed: openPrefs),
                    ]),
                Expanded(
                    child: visible.isEmpty
                        ? const EmptyState(
                            icon: Icons.notifications_none_rounded,
                            iconSize: 72,
                            title: 'Rien de nouveau',
                            message:
                                'Le suivi de vos commandes, vos points LO+ et nos offres apparaîtront ici.')
                        : ListView(
                            padding: EdgeInsets.only(
                                bottom:
                                    AppSpacing.xl + navBarClearance(context)),
                            children: [
                                if (fresh.isNotEmpty)
                                  section('Nouveau', fresh,
                                      trailing: TextButton(
                                        style: TextButton.styleFrom(
                                            foregroundColor: AppColors.primary,
                                            minimumSize: const Size(48, 44),
                                            textStyle: const TextStyle(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w600)),
                                        onPressed: () => _replace(ref, [
                                          for (final n in items) _asRead(n)
                                        ]),
                                        child: const Text('Tout lire'),
                                      )),
                                if (earlier.isNotEmpty)
                                  section('Plus tôt', earlier),
                              ]))
              ])),
        ));
  }
}

const _ink = Color(0xFF0E1430);
const _muted = Color(0xFF59627F);
const _faint = Color(0xFF8A91A8);
const _mist = Color(0xFFF1F3F9);

/// "LO-2026-00142" found in the title, message or link.
String? _orderNumber(AppNotification n) => RegExp(r'LO-\d{4}-\d+')
    .firstMatch('${n.title} ${n.message} ${n.link ?? ''}')
    ?.group(0);

/// Points quoted in a LO+ notification ("gagné 20 points").
int? _points(AppNotification n) {
  final m = RegExp(r'(\d+)\s*(?:points|pts)')
      .firstMatch('${n.title} ${n.message}'.toLowerCase());
  return m == null ? null : int.tryParse(m.group(1)!);
}

/// One notification: a round icon (solid blue while unread), the title and
/// time, the message, and at most one compact line of context.
class _NotificationTile extends StatelessWidget {
  const _NotificationTile(
      {required this.item, required this.orders, required this.onTap});
  final AppNotification item;
  final List<OrderSummary> orders;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kind = _Kind.of(item);
    final unread = !item.read;

    Widget? context_;
    if (kind == _Kind.order) {
      final number = _orderNumber(item);
      final order = number == null
          ? null
          : orders.where((o) => o.number == number).firstOrNull;
      if (order != null) context_ = _OrderLine(order);
    } else if (kind == _Kind.loyalty) {
      final pts = _points(item);
      if (pts != null && pts > 0) context_ = _PointsLine(pts);
    }

    return Material(
      color: AppColors.white,
      child: InkWell(
        onTap: onTap,
        highlightColor: _mist,
        child: Semantics(
          label: unread ? 'Non lue' : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: unread ? AppColors.primary : _mist,
                  shape: BoxShape.circle,
                ),
                child: Icon(kind.icon,
                    size: 20, color: unread ? AppColors.white : _muted),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Expanded(
                              child: Text(item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: _ink,
                                      fontSize: 15,
                                      height: 1.3,
                                      fontWeight: unread
                                          ? FontWeight.w700
                                          : FontWeight.w500)),
                            ),
                            const SizedBox(width: 10),
                            Text(_relativeDate(item.date),
                                style: TextStyle(
                                    color: unread ? AppColors.primary : _faint,
                                    fontSize: 12,
                                    fontWeight: unread
                                        ? FontWeight.w600
                                        : FontWeight.w400)),
                          ]),
                      const SizedBox(height: 2),
                      Text(item.message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: _muted, fontSize: 14, height: 1.4)),
                      if (context_ != null) ...[
                        const SizedBox(height: 8),
                        context_,
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

/// "LO-2026-00142 · en préparation" with a thin 4-step track.
class _OrderLine extends StatelessWidget {
  const _OrderLine(this.order);
  final OrderSummary order;

  @override
  Widget build(BuildContext context) {
    final s = order.status.toLowerCase();
    final step = s.contains('livr') || s.contains('deliver')
        ? 4
        : s.contains('rout') || s.contains('exp') || s.contains('ship')
            ? 3
            : 2;
    return Semantics(
      label: 'Commande ${order.number}, ${order.status}, étape $step sur 4',
      excludeSemantics: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${order.number} · ${order.status.toLowerCase()}',
            style: const TextStyle(
                color: _ink,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                fontFeatures: [FontFeature.tabularFigures()])),
        const SizedBox(height: 6),
        SizedBox(
          width: 140,
          child: Row(children: [
            for (var k = 1; k <= 4; k++) ...[
              if (k > 1) const SizedBox(width: 3),
              Expanded(
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                      color: k <= step ? AppColors.primary : AppColors.border,
                      borderRadius: BorderRadius.circular(9)),
                ),
              ),
            ],
          ]),
        ),
      ]),
    );
  }
}

/// "+20 pts · 2 000 FCFA de réduction".
class _PointsLine extends StatelessWidget {
  const _PointsLine(this.points);
  final int points;

  @override
  Widget build(BuildContext context) => Text.rich(
        TextSpan(children: [
          TextSpan(
              text: '+$points pts',
              style: const TextStyle(
                  color: AppColors.primary, fontWeight: FontWeight.w700)),
          TextSpan(
              text: ' · ${formatXof(points * loyaltyPointValueXof)} '
                  'de réduction'),
        ]),
        style: const TextStyle(
            color: _muted,
            fontSize: 12.5,
            fontFeatures: [FontFeature.tabularFigures()]),
      );
}

/// Bottom sheet to choose which notification kinds are shown.
class _PrefsSheet extends ConsumerWidget {
  const _PrefsSheet({this.onClearAll});

  /// Deletes every notification; null when there are none.
  final VoidCallback? onClearAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(notificationPrefsProvider);
    const descriptions = {
      _Kind.order: 'Préparation, expédition et livraison',
      _Kind.loyalty: 'Points gagnés, paliers et défis',
      _Kind.promo: 'Ventes flash et réductions',
      _Kind.info: 'Informations générales',
    };
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Je souhaite recevoir',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: AppSpacing.sm),
                for (final kind in _Kind.values)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: Icon(kind.icon, color: kind.color),
                    title: Text(kind.label),
                    subtitle: Text(descriptions[kind]!),
                    activeThumbColor: AppColors.primaryDark,
                    value: prefs.contains(kind.name),
                    onChanged: (on) =>
                        ref.read(notificationPrefsProvider.notifier).state = on
                            ? {...prefs, kind.name}
                            : ({...prefs}..remove(kind.name)),
                  ),
                if (onClearAll != null) ...[
                  const Divider(height: AppSpacing.xl),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        minimumSize: const Size(48, 44)),
                    onPressed: onClearAll,
                    icon: const Icon(Icons.delete_sweep_outlined, size: 20),
                    label: const Text('Supprimer toutes les notifications'),
                  ),
                ],
              ]),
        ),
      ),
    );
  }
}
