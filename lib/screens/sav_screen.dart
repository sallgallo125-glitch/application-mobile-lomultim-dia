import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/account/account_providers.dart';
import '../features/customer/customer_providers.dart';
import '../theme/tokens.dart';
import '../widgets/app_header.dart';
import '../widgets/nav_clearance.dart';

/// Repair steps shown as a timeline on every ticket.
const _steps = ['Dossier reçu', 'En diagnostic', 'Réparé', 'À récupérer'];

const _problems = [
  (Icons.power_settings_new, 'Ne s’allume plus'),
  (Icons.broken_image_outlined, 'Écran cassé'),
  (Icons.battery_alert_outlined, 'Batterie'),
  (Icons.volume_off_outlined, 'Son / micro'),
  (Icons.wifi_off, 'Réseau / Wi-Fi'),
  (Icons.slow_motion_video, 'Lenteurs'),
  (Icons.more_horiz, 'Autre'),
];

class SavScreen extends ConsumerStatefulWidget {
  const SavScreen({super.key});
  @override
  ConsumerState<SavScreen> createState() => _SavScreenState();
}

class _SavScreenState extends ConsumerState<SavScreen> {
  final product = TextEditingController();
  final symptom = TextEditingController();
  final phone = TextEditingController();
  int _step = 0;
  String? _problem;

  @override
  void dispose() {
    product.dispose();
    symptom.dispose();
    phone.dispose();
    super.dispose();
  }

  bool get _canContinue => switch (_step) {
        0 => product.text.trim().isNotEmpty,
        1 => _problem != null,
        _ => symptom.text.trim().isNotEmpty || _problem != 'Autre',
      };

  void _submit() {
    final tickets = ref.read(savTicketsProvider);
    ref.read(savTicketsProvider.notifier).state = [
      (
        number: 'SAV-2026-${43 + tickets.length}',
        product: product.text.trim(),
        status: _steps.first
      ),
      ...tickets
    ];
    product.clear();
    symptom.clear();
    phone.clear();
    setState(() {
      _step = 0;
      _problem = null;
    });
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Dossier SAV créé · nous vous rappelons sous 24 h')));
  }

  @override
  Widget build(BuildContext context) {
    final tickets = ref.watch(savTicketsProvider);
    // Products from past orders, for a one-tap choice.
    final purchased = ref.watch(ordersProvider).valueOrNull?.expand(
                (order) => order.items.map((line) => line.name)).toSet().toList() ??
        const <String>[];

    return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
            bottom: false,
            child: Column(children: [
              AppHeader(
                  title: 'Service après-vente',
                  onBack: () =>
                      context.canPop() ? context.pop() : context.go('/compte')),
              Expanded(
                  child: ListView(
                      padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg,
                          AppSpacing.lg, AppSpacing.lg + navBarClearance(context)),
                      children: [
                    _Banner(),
                    const SizedBox(height: AppSpacing.lg),
                    const Text('Ouvrir un dossier SAV', style: AppText.section),
                    const SizedBox(height: AppSpacing.md),
                    _StepIndicator(current: _step),
                    const SizedBox(height: AppSpacing.lg),
                    AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: KeyedSubtree(
                            key: ValueKey(_step),
                            child: switch (_step) {
                              0 => _productStep(purchased),
                              1 => _problemStep(),
                              _ => _detailsStep(),
                            })),
                    const SizedBox(height: AppSpacing.lg),
                    Row(children: [
                      if (_step > 0)
                        Expanded(
                            child: OutlinedButton(
                                onPressed: () => setState(() => _step--),
                                child: const Text('Retour'))),
                      if (_step > 0) const SizedBox(width: AppSpacing.sm),
                      Expanded(
                          flex: 2,
                          child: ElevatedButton(
                              onPressed: !_canContinue
                                  ? null
                                  : _step < 2
                                      ? () => setState(() => _step++)
                                      : _submit,
                              child: Text(_step < 2
                                  ? 'Continuer'
                                  : 'Créer le dossier'))),
                    ]),
                    const SizedBox(height: AppSpacing.xxl),
                    Row(children: [
                      const Expanded(
                          child: Text('Mes dossiers', style: AppText.section)),
                      if (tickets.isNotEmpty)
                        Text('${tickets.length}', style: AppText.bodyMuted),
                    ]),
                    const SizedBox(height: AppSpacing.sm),
                    if (tickets.isEmpty)
                      const Padding(
                          padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                          child: Text('Aucun dossier en cours.',
                              textAlign: TextAlign.center,
                              style: AppText.bodyMuted)),
                    for (final ticket in tickets)
                      _TicketCard(
                          number: ticket.number,
                          product: ticket.product,
                          status: ticket.status),
                  ]))
            ])));
  }

  Widget _productStep(List<String> purchased) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Quel produit est concerné ?', style: AppText.subtitle),
            const SizedBox(height: AppSpacing.sm),
            if (purchased.isNotEmpty) ...[
              const Text('Parmi vos achats', style: AppText.caption),
              const SizedBox(height: AppSpacing.xs),
              Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
                for (final name in purchased.take(6))
                  ChoiceChip(
                      label: Text(name, overflow: TextOverflow.ellipsis),
                      selected: product.text == name,
                      onSelected: (_) => setState(() => product.text = name)),
              ]),
              const SizedBox(height: AppSpacing.md),
            ],
            TextField(
                controller: product,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                    labelText: 'Produit concerné',
                    hintText: 'Ex. HP ProBook 450 G10',
                    prefixIcon: Icon(Icons.devices_other),
                    border: OutlineInputBorder())),
          ]);

  Widget _problemStep() => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Quel est le problème ?', style: AppText.subtitle),
            const SizedBox(height: AppSpacing.sm),
            Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
              for (final (icon, label) in _problems)
                ChoiceChip(
                    avatar: Icon(icon, size: 18),
                    label: Text(label),
                    selected: _problem == label,
                    onSelected: (_) => setState(() => _problem = label)),
            ]),
          ]);

  Widget _detailsStep() => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Quelques détails', style: AppText.subtitle),
            const SizedBox(height: AppSpacing.sm),
            TextField(
                controller: symptom,
                maxLines: 3,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                    labelText: 'Symptôme',
                    hintText: _problem == null
                        ? null
                        : '$_problem : depuis quand, dans quelles conditions…',
                    border: const OutlineInputBorder())),
            const SizedBox(height: AppSpacing.sm),
            TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                    labelText: 'Téléphone',
                    prefixIcon: Icon(Icons.phone_outlined),
                    border: OutlineInputBorder())),
          ]);
}

class _Banner extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryLight]),
          borderRadius: BorderRadius.circular(AppRadii.xl)),
      child: const Row(children: [
        Icon(Icons.build_circle_outlined, color: Colors.white, size: 40),
        SizedBox(width: AppSpacing.md),
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Diagnostic gratuit en 24 h',
              style: TextStyle(
                  color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
          SizedBox(height: 2),
          Text('Devis avant réparation · Suivi en temps réel',
              style: TextStyle(color: Colors.white70, fontSize: 13)),
        ])),
      ]));
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.current});
  final int current;
  static const _labels = ['Produit', 'Problème', 'Détails'];

  @override
  Widget build(BuildContext context) => Row(children: [
        for (var i = 0; i < _labels.length; i++) ...[
          Expanded(
              child: Column(children: [
            AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 4,
                decoration: BoxDecoration(
                    color: i <= current ? AppColors.primary : AppColors.border,
                    borderRadius: BorderRadius.circular(AppRadii.pill))),
            const SizedBox(height: AppSpacing.xs),
            Text('${i + 1}. ${_labels[i]}',
                style: AppText.caption.copyWith(
                    color: i <= current
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    fontWeight: i == current ? FontWeight.w800 : null)),
          ])),
          if (i < _labels.length - 1) const SizedBox(width: AppSpacing.xs),
        ]
      ]);
}

class _TicketCard extends StatelessWidget {
  const _TicketCard(
      {required this.number, required this.product, required this.status});
  final String number;
  final String product;
  final String status;

  @override
  Widget build(BuildContext context) {
    final reached = _steps.indexOf(status);
    final done = reached == _steps.length - 1;
    final color = done ? AppColors.success : AppColors.primary;
    return Card(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(product, style: AppText.subtitle),
                      Text(number, style: AppText.caption),
                    ])),
                const SizedBox(width: AppSpacing.sm),
                Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm, vertical: 3),
                    decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadii.pill)),
                    child: Text(status,
                        style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w700))),
              ]),
              if (reached >= 0) ...[
                const SizedBox(height: AppSpacing.md),
                Row(children: [
                  for (var i = 0; i < _steps.length; i++) ...[
                    Icon(
                        i <= reached
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        size: 18,
                        color: i <= reached ? color : AppColors.border),
                    if (i < _steps.length - 1)
                      Expanded(
                          child: Container(
                              height: 2,
                              color: i < reached ? color : AppColors.border)),
                  ]
                ]),
                const SizedBox(height: AppSpacing.xs),
                Row(children: [
                  for (var i = 0; i < _steps.length; i++)
                    Expanded(
                        child: Text(_steps[i],
                            textAlign: i == 0
                                ? TextAlign.start
                                : i == _steps.length - 1
                                    ? TextAlign.end
                                    : TextAlign.center,
                            style: AppText.caption.copyWith(fontSize: 10.5))),
                ]),
              ],
            ])));
  }
}
