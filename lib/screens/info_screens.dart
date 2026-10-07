import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../contracts/content.dart';
import '../features/member/member_providers.dart';
import '../theme/tokens.dart';
import '../widgets/error_state.dart';
import '../widgets/loading_state.dart';
import '../widgets/sub_page.dart';

/// Order tracking by number + phone (site: /suivi).
class TrackingScreen extends ConsumerStatefulWidget {
  const TrackingScreen({super.key, this.initialOrderNumber, this.initialPhone});
  final String? initialOrderNumber;

  /// Pre-filled from a guest order confirmation.
  final String? initialPhone;
  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen> {
  late final _number = TextEditingController(text: widget.initialOrderNumber);
  late final _phone = TextEditingController(text: widget.initialPhone);
  OrderTracking? _result;
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _number.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });
    try {
      final r = await ref
          .read(contentRepositoryProvider)
          .track(_number.text, _phone.text);
      if (mounted) setState(() => _result = r);
    } catch (e) {
      if (mounted) {
        setState(
            () => _error = errorMessage(e, 'Suivi indisponible. Réessayez.'));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return SubPage(
      title: 'Suivi de commande',
      child: ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [
        const Text(
            "Numéro de commande et téléphone utilisés lors de l'achat : vous voyez chaque étape, de la confirmation jusqu'à la remise du colis."),
        const SizedBox(height: AppSpacing.md),
        TextField(
            controller: _number,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
                labelText: 'Numéro de commande',
                hintText: 'LM-2614',
                border: OutlineInputBorder())),
        const SizedBox(height: AppSpacing.sm),
        TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            onSubmitted: (_) => _search(),
            decoration: const InputDecoration(
                labelText: 'Téléphone', border: OutlineInputBorder())),
        const SizedBox(height: AppSpacing.md),
        ElevatedButton(
            onPressed: _loading ? null : _search,
            child: Text(_loading ? 'Recherche…' : 'Suivre ma commande')),
        if (_error != null)
          Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Text(_error!,
                  style: const TextStyle(
                      color: AppColors.danger, fontWeight: FontWeight.w700))),
        if (result != null) ...[
          PageSectionTitle('Commande ${result.orderNumber}'),
          for (var i = 0; i < result.steps.length; i++)
            _StepTile(
                step: result.steps[i], last: i == result.steps.length - 1),
        ],
      ]),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({required this.step, required this.last});
  final TrackingStep step;
  final bool last;
  @override
  Widget build(BuildContext context) {
    final color = step.reached ? AppColors.success : AppColors.border;
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Column(children: [
          Icon(step.reached ? Icons.check_circle : Icons.radio_button_unchecked,
              color: color),
          if (!last) Expanded(child: Container(width: 2, color: color)),
        ]),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(step.label,
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: step.reached
                          ? AppColors.text
                          : AppColors.textSecondary)),
              Text(step.detail, style: const TextStyle(fontSize: 13)),
              if (step.at != null)
                Text(step.at!,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// FAQ grouped by category (site: /faq).
class FaqScreen extends ConsumerWidget {
  const FaqScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final faqs = ref.watch(faqsProvider);
    return SubPage(
      title: 'Questions fréquentes',
      child: faqs.when(
        loading: () => const LoadingState(label: 'Chargement de la FAQ…'),
        error: (e, _) =>
            ErrorState(onRetry: () => ref.invalidate(faqsProvider)),
        data: (items) {
          final categories = <String>[];
          for (final f in items) {
            if (!categories.contains(f.category)) categories.add(f.category);
          }
          return ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                for (final category in categories) ...[
                  PageSectionTitle(category),
                  for (final f in items.where((f) => f.category == category))
                    Card(
                      child: ExpansionTile(
                        title: Text(f.question,
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        childrenPadding: const EdgeInsets.fromLTRB(
                            AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
                        children: [Text(f.answer)],
                      ),
                    ),
                ],
                const SizedBox(height: AppSpacing.md),
                OutlinedButton(
                    onPressed: () => context.push('/contact'),
                    child: const Text('Une autre question ? Contactez-nous')),
              ]);
        },
      ),
    );
  }
}

/// Contact details, same as the site's ContactPage.
class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  static const _blocks = [
    (
      'Showroom Médina',
      [
        'Avenue Blaise Diagne, Médina, Dakar',
        'Téléphone : +221 33 822 30 60',
        'Mobile / WhatsApp : +221 77 998 04 04',
        'Horaires : lundi – samedi, 9 h – 19 h',
        'Atelier SAV : sur place',
      ]
    ),
    (
      'Showroom Sandaga',
      [
        'Marché Sandaga, Dakar Plateau',
        'Téléphone : +221 33 823 81 87',
        'Horaires : lundi – samedi, 9 h – 19 h',
        'Retrait de commande : gratuit',
      ]
    ),
    (
      'E-mails',
      [
        'Direction : modou@lomultimedia.com',
        'Commercial : prime@lomultimedia.com',
        'Réponse sous 24 h ouvrées',
      ]
    ),
  ];

  void _open(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    return SubPage(
      title: 'Contact',
      child: ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [
        const Text(
            'Deux showrooms à Dakar, une équipe joignable par téléphone, WhatsApp et e-mail.'),
        const SizedBox(height: AppSpacing.md),
        Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
          ElevatedButton.icon(
              onPressed: () => _open('https://wa.me/221779980404'),
              icon: const Icon(Icons.chat),
              label: const Text('WhatsApp')),
          OutlinedButton.icon(
              onPressed: () => _open('tel:+221338223060'),
              icon: const Icon(Icons.call),
              label: const Text('Appeler')),
          OutlinedButton.icon(
              onPressed: () => _open('mailto:modou@lomultimedia.com'),
              icon: const Icon(Icons.mail_outline),
              label: const Text('E-mail')),
        ]),
        for (final (title, lines) in _blocks) ...[
          PageSectionTitle(title),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [for (final l in lines) Text(l)]),
            ),
          ),
        ],
      ]),
    );
  }
}

/// List of legal pages (site: /legal).
class LegalIndexScreen extends ConsumerWidget {
  const LegalIndexScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docs = ref.watch(legalDocumentsProvider);
    return SubPage(
      title: 'Informations légales',
      child: docs.when(
        loading: () => const LoadingState(label: 'Chargement…'),
        error: (e, _) =>
            ErrorState(onRetry: () => ref.invalidate(legalDocumentsProvider)),
        data: (items) =>
            ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [
          for (final d in items)
            Card(
              child: ListTile(
                title: Text(d.title),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/legal/${d.slug}'),
              ),
            ),
        ]),
      ),
    );
  }
}

/// One legal page (site: /legal/:slug).
class LegalScreen extends ConsumerWidget {
  const LegalScreen({super.key, required this.slug});
  final String slug;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doc = ref.watch(legalDocumentProvider(slug));
    return SubPage(
      title: doc.value?.title ?? 'Informations légales',
      fallbackRoute: '/legal',
      child: doc.when(
        loading: () => const LoadingState(label: 'Chargement…'),
        error: (e, _) => ErrorState(
            onRetry: () => ref.invalidate(legalDocumentProvider(slug))),
        data: (d) =>
            ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [
          Text('Mise à jour : ${d.updatedAt}',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: AppSpacing.sm),
          ...legalHtmlToWidgets(d.bodyHtml),
        ]),
      ),
    );
  }
}

String _stripTags(String html) => html
    .replaceAll(RegExp(r'<br\s*/?>'), '\n')
    .replaceAll(RegExp(r'<[^>]+>'), '')
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&amp;', '&')
    .trim();

/// Renders the small HTML subset the site's legal pages use: h2, p, ul/li,
/// tables and "encart" boxes. Anything else is shown as plain text.
List<Widget> legalHtmlToWidgets(String html) {
  final widgets = <Widget>[];
  final block = RegExp(r'<(h2|p|ul|table|div)[^>]*>(.*?)</\1>', dotAll: true);
  for (final m in block.allMatches(html)) {
    final tag = m.group(1)!;
    final inner = m.group(2)!;
    switch (tag) {
      case 'h2':
        widgets.add(PageSectionTitle(_stripTags(inner)));
      case 'p':
        widgets.add(Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(_stripTags(inner))));
      case 'ul':
        for (final li
            in RegExp(r'<li>(.*?)</li>', dotAll: true).allMatches(inner)) {
          widgets.add(Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Text('•  ${_stripTags(li.group(1)!)}')));
        }
        widgets.add(const SizedBox(height: AppSpacing.sm));
      case 'table':
        final rows = RegExp(r'<tr>(.*?)</tr>', dotAll: true)
            .allMatches(inner)
            .map((r) => RegExp(r'<t[hd]>(.*?)</t[hd]>', dotAll: true)
                .allMatches(r.group(1)!)
                .map((c) => _stripTags(c.group(1)!))
                .toList())
            .toList();
        if (rows.isEmpty) break;
        final header = rows.first;
        // Each row as a card: reads well on narrow phones.
        for (final row in rows.skip(1)) {
          widgets.add(Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(row.first,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    for (var i = 1; i < row.length && i < header.length; i++)
                      Text('${header[i]} : ${row[i]}',
                          style: const TextStyle(fontSize: 13)),
                  ]),
            ),
          ));
        }
        widgets.add(const SizedBox(height: AppSpacing.sm));
      case 'div':
        widgets.add(Card(
          color: AppColors.primarySoft,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(_stripTags(inner.replaceAll('</b>', '</b>\n'))),
          ),
        ));
    }
  }
  if (widgets.isEmpty) widgets.add(Text(_stripTags(html)));
  return widgets;
}
