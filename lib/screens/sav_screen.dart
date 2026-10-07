import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/customer/customer_providers.dart';
import '../theme/tokens.dart';
import '../widgets/app_header.dart';

class SavScreen extends ConsumerStatefulWidget {
  const SavScreen({super.key});
  @override
  ConsumerState<SavScreen> createState() => _SavScreenState();
}

class _SavScreenState extends ConsumerState<SavScreen> {
  final product = TextEditingController();
  final symptom = TextEditingController();
  final phone = TextEditingController();
  @override
  void dispose() {
    product.dispose();
    symptom.dispose();
    phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tickets = ref.watch(savTicketsProvider);
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
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      children: [
                    const Text('Ouvrir un dossier SAV',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: AppSpacing.sm),
                    Card(
                        color: AppColors.primarySoft,
                        child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Row(children: [
                              const Icon(Icons.info_outline,
                                  color: AppColors.primary),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                  child: Text(
                                      'Diagnostic gratuit en 24 h · Devis avant réparation',
                                      style: TextStyle(
                                          color: AppColors.primaryDark)))
                            ]))),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                        controller: product,
                        decoration: const InputDecoration(
                            labelText: 'Produit concerné',
                            border: OutlineInputBorder())),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                        controller: symptom,
                        maxLines: 2,
                        decoration: const InputDecoration(
                            labelText: 'Symptôme',
                            border: OutlineInputBorder())),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                        controller: phone,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                            labelText: 'Téléphone',
                            border: OutlineInputBorder())),
                    const SizedBox(height: AppSpacing.md),
                    ElevatedButton(
                        onPressed: () {
                          if (product.text.trim().isEmpty ||
                              symptom.text.trim().isEmpty) return;
                          ref.read(savTicketsProvider.notifier).state = [
                            (
                              number: 'SAV-2026-${43 + tickets.length}',
                              product: product.text.trim(),
                              status: 'Dossier reçu'
                            ),
                            ...tickets
                          ];
                          product.clear();
                          symptom.clear();
                          phone.clear();
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Dossier SAV créé')));
                        },
                        child: const Text('Créer le dossier')),
                    const SizedBox(height: AppSpacing.xl),
                    const Text('Mes dossiers',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800)),
                    for (final ticket in tickets)
                      Card(
                          child: ListTile(
                              title: Text(ticket.product),
                              // Status under the number: a long status in
                              // `trailing` squeezes the tile on small phones.
                              subtitle: Text.rich(TextSpan(children: [
                                TextSpan(text: '${ticket.number} · '),
                                TextSpan(
                                    text: ticket.status,
                                    style: const TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w700)),
                              ]))))
                  ]))
            ])));
  }
}
