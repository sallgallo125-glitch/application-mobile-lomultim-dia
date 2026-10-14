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

/// One legal page (site: /legal/:slug), with a tappable table of contents.
class LegalScreen extends ConsumerStatefulWidget {
  const LegalScreen({super.key, required this.slug});
  final String slug;
  @override
  ConsumerState<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends ConsumerState<LegalScreen> {
  final Map<int, GlobalKey> _anchors = {};

  GlobalKey _anchor(int index) => _anchors.putIfAbsent(index, GlobalKey.new);

  void _jumpTo(int index) {
    final target = _anchors[index]?.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(target,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          alignment: 0.02);
    }
  }

  @override
  Widget build(BuildContext context) {
    final slug = widget.slug;
    final doc = ref.watch(legalDocumentProvider(slug));
    return SubPage(
      title: doc.value?.title ?? 'Informations légales',
      fallbackRoute: '/legal',
      child: doc.when(
        loading: () => const LoadingState(label: 'Chargement…'),
        error: (e, _) => ErrorState(
            onRetry: () => ref.invalidate(legalDocumentProvider(slug))),
        data: (d) {
          final headings = legalHeadings(d.bodyHtml);
          // Column + SingleChildScrollView (not a lazy ListView) so every
          // heading is built and the table of contents can reach it.
          return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxl),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      const Icon(Icons.update,
                          size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: AppSpacing.xs),
                      Text('Mise à jour : ${d.updatedAt}',
                          style: AppText.caption),
                    ]),
                    if (headings.length > 1) ...[
                      const SizedBox(height: AppSpacing.md),
                      _TableOfContents(headings: headings, onTap: _jumpTo),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    ...legalHtmlToWidgets(d.bodyHtml, anchorFor: _anchor),
                  ]));
        },
      ),
    );
  }
}

class _TableOfContents extends StatefulWidget {
  const _TableOfContents({required this.headings, required this.onTap});
  final List<String> headings;
  final ValueChanged<int> onTap;
  @override
  State<_TableOfContents> createState() => _TableOfContentsState();
}

class _TableOfContentsState extends State<_TableOfContents> {
  bool _open = false;
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(AppRadii.lg)),
        child: Column(children: [
          InkWell(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(children: [
                const Icon(Icons.toc, color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                    child: Text('Sommaire · ${widget.headings.length} sections',
                        style: AppText.subtitle
                            .copyWith(color: AppColors.primaryDark))),
                Icon(_open ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.primary),
              ]),
            ),
          ),
          if (_open)
            for (var i = 0; i < widget.headings.length; i++)
              InkWell(
                onTap: () => widget.onTap(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                            width: 26,
                            child: Text('${i + 1}.',
                                style: AppText.body.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w800))),
                        Expanded(
                            child:
                                Text(widget.headings[i], style: AppText.body)),
                      ]),
                ),
              ),
          if (_open) const SizedBox(height: AppSpacing.sm),
        ]),
      );
}

String _decode(String text) => text
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&rsquo;', '’')
    .replaceAll('&laquo;', '«')
    .replaceAll('&raquo;', '»')
    .replaceAll('&euro;', '€')
    .replaceAll('&amp;', '&');

String _stripTags(String html) => _decode(html
        .replaceAll(RegExp(r'<br\s*/?>'), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), ''))
    .trim();

/// Inline HTML (b/strong, i/em, a, br) as styled spans.
TextSpan _inline(String html, TextStyle base) {
  final spans = <InlineSpan>[];
  final token =
      RegExp(r'<(/?)(b|strong|i|em|a|br)\b[^>]*>', caseSensitive: false);
  var bold = 0, italic = 0, link = 0;
  var cursor = 0;
  void push(String raw) {
    final text = _decode(raw.replaceAll(RegExp(r'<[^>]+>'), ''));
    if (text.isEmpty) return;
    spans.add(TextSpan(
        text: text,
        style: TextStyle(
            fontWeight: bold > 0 ? FontWeight.w800 : null,
            fontStyle: italic > 0 ? FontStyle.italic : null,
            color: link > 0 ? AppColors.primary : null,
            decoration: link > 0 ? TextDecoration.underline : null)));
  }

  for (final m in token.allMatches(html)) {
    push(html.substring(cursor, m.start));
    cursor = m.end;
    final delta = m.group(1)!.isNotEmpty ? -1 : 1;
    switch (m.group(2)!.toLowerCase()) {
      case 'b' || 'strong':
        bold = (bold + delta).clamp(0, 9);
      case 'i' || 'em':
        italic = (italic + delta).clamp(0, 9);
      case 'a':
        link = (link + delta).clamp(0, 9);
      case 'br':
        spans.add(const TextSpan(text: '\n'));
    }
  }
  push(html.substring(cursor));
  return TextSpan(style: base, children: spans);
}

/// Section titles (h2) of a legal page, in order.
List<String> legalHeadings(String html) =>
    RegExp(r'<h2[^>]*>(.*?)</h2>', dotAll: true)
        .allMatches(html)
        .map((m) => _stripTags(m.group(1)!))
        .toList();

/// Renders the HTML subset the site's legal pages use: h2/h3, p, ul/ol,
/// tables and "encart" boxes, with bold/italic/links inside paragraphs.
/// [anchorFor] gives each h2 a key so the table of contents can scroll to it.
List<Widget> legalHtmlToWidgets(String html,
    {GlobalKey Function(int index)? anchorFor}) {
  final widgets = <Widget>[];
  var headingIndex = 0;
  final block =
      RegExp(r'<(h2|h3|p|ul|ol|table|div)[^>]*>(.*?)</\1>', dotAll: true);
  for (final m in block.allMatches(html)) {
    final tag = m.group(1)!;
    final inner = m.group(2)!;
    switch (tag) {
      case 'h2':
        final index = headingIndex++;
        widgets.add(Padding(
          key: anchorFor?.call(index),
          padding:
              const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
                width: 4,
                height: 22,
                margin: const EdgeInsets.only(right: AppSpacing.sm, top: 1),
                decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(AppRadii.pill))),
            Expanded(child: Text(_stripTags(inner), style: AppText.section)),
          ]),
        ));
      case 'h3':
        widgets.add(Padding(
            padding: const EdgeInsets.only(
                top: AppSpacing.sm, bottom: AppSpacing.xs),
            child: Text(_stripTags(inner), style: AppText.subtitle)));
      case 'p':
        widgets.add(Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Text.rich(_inline(inner.trim(), AppText.body))));
      case 'ul' || 'ol':
        var n = 0;
        for (final li
            in RegExp(r'<li[^>]*>(.*?)</li>', dotAll: true).allMatches(inner)) {
          n++;
          widgets.add(Padding(
              padding: const EdgeInsets.only(
                  bottom: AppSpacing.sm, left: AppSpacing.xs),
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                        width: 22,
                        child: tag == 'ol'
                            ? Text('$n.',
                                style: AppText.body.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w800))
                            : const Padding(
                                padding: EdgeInsets.only(top: 7),
                                child: Icon(Icons.circle,
                                    size: 6, color: AppColors.primary))),
                    Expanded(
                        child: Text.rich(
                            _inline(li.group(1)!.trim(), AppText.body))),
                  ])));
        }
        widgets.add(const SizedBox(height: AppSpacing.sm));
      case 'table':
        final rows = RegExp(r'<tr[^>]*>(.*?)</tr>', dotAll: true)
            .allMatches(inner)
            .map((r) => RegExp(r'<t[hd][^>]*>(.*?)</t[hd]>', dotAll: true)
                .allMatches(r.group(1)!)
                .map((c) => _stripTags(c.group(1)!))
                .toList())
            .toList();
        if (rows.isEmpty) break;
        final header = rows.first;
        // Each row as a card: reads well on narrow phones.
        for (final row in rows.skip(1)) {
          widgets.add(Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
                color: AppColors.white,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(AppRadii.md)),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(row.first, style: AppText.subtitle),
                  const SizedBox(height: AppSpacing.xs),
                  for (var i = 1; i < row.length && i < header.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                                flex: 2,
                                child: Text(header[i], style: AppText.caption)),
                            Expanded(
                                flex: 3,
                                child: Text(row[i],
                                    style:
                                        AppText.body.copyWith(fontSize: 13))),
                          ]),
                    ),
                ]),
          ));
        }
        widgets.add(const SizedBox(height: AppSpacing.sm));
      case 'div':
        widgets.add(Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: const Border(
                  left: BorderSide(color: AppColors.primary, width: 4))),
          child: Text.rich(_inline(inner.trim(), AppText.body)),
        ));
    }
  }
  if (widgets.isEmpty) {
    widgets.add(Text(_stripTags(html), style: AppText.body));
  }
  return widgets;
}
