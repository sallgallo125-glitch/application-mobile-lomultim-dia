import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/customer/customer_providers.dart';
import '../theme/tokens.dart';
import '../widgets/app_header.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});
  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final input = TextEditingController();
  String assistant = 'Arame';
  final List<String> quickReplies = const [
    'Prix d\'un PC portable',
    'Kit Starlink',
    'Délai de livraison',
    'Moyens de paiement',
    'Garantie et SAV',
    'Horaires showroom'
  ];

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  void send() {
    final text = input.text.trim();
    if (text.isEmpty) return;
    final current = ref.read(chatMessagesProvider);
    final lower = text.toLowerCase();
    String reply;
    if (assistant == 'Arame') {
      if (lower.contains('pc') ||
          lower.contains('portable') ||
          lower.contains('ordinateur')) {
        reply =
            'Nos portables commencent à 565 000 FCFA. Pour la bureautique, le HP ProBook 450 G10 est à 795 000 FCFA en promotion, garantie 12 mois. Dites-moi votre budget, je vous propose 3 modèles.';
      } else if (lower.contains('starlink') || lower.contains('internet')) {
        reply =
            'Le kit Starlink Standard est à 425 000 FCFA, avec installation offerte à Dakar sous 48 h. Nous configurons le routeur et testons le débit avec vous.';
      } else if (lower.contains('livraison') || lower.contains('delai')) {
        reply =
            'Livraison standard en 24 à 72 h : 2 500 FCFA à Dakar Centre, 3 000 en banlieue, 4 000 à Rufisque, 5 000 à Thiès, 7 000 en régions. Offerte dès 500 000 FCFA. Express sous 4 h à Dakar : 4 500 FCFA. Retrait gratuit en showroom.';
      } else if (lower.contains('paiement') ||
          lower.contains('payer') ||
          lower.contains('wave')) {
        reply =
            'Pour le moment, le paiement se fait à la livraison ou au retrait en showroom, en espèces. Wave, Orange Money et la carte bancaire seront disponibles au lancement.';
      } else if (lower.contains('garantie') || lower.contains('sav')) {
        reply =
            'Tous nos produits sont garantis 12 mois minimum. Notre atelier agréé HP, Lenovo et ASUS fait le diagnostic gratuitement en 24 h, avec devis avant réparation.';
      } else if (lower.contains('horaire') ||
          lower.contains('showroom') ||
          lower.contains('adresse')) {
        reply =
            'Deux showrooms à Dakar : 27 avenue Émile Badiane x rue Paul Holl (Sandaga) et rue 15 à la Médina. Ouverts du lundi au samedi, 9 h – 19 h.';
      } else {
        reply =
            'Je note votre demande. Pour une réponse précise, un conseiller peut vous répondre sur WhatsApp au 77 998 04 04. Je peux aussi vous aider sur les prix, la livraison, la garantie ou nos showrooms.';
      }
    } else {
      reply =
          'Merci, Mouhamed va vous aider pour votre dossier SAV. Un conseiller vous répondra sous 24 h.';
    }
    ref.read(chatMessagesProvider.notifier).state = [
      ...current,
      (mine: true, text: text),
      (mine: false, text: reply),
    ];
    input.clear();
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatMessagesProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          AppHeader(
              title: 'Assistance',
              onBack: () =>
                  context.canPop() ? context.pop() : context.go('/compte')),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'Arame', label: Text('Arame · Achat')),
                ButtonSegment(value: 'Mouhamed', label: Text('Mouhamed · SAV'))
              ],
              selected: {assistant},
              onSelectionChanged: (value) =>
                  setState(() => assistant = value.first),
            ),
          ),
          if (assistant == 'Arame')
            SizedBox(
                height: 44,
                child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                    children: [
                      for (final reply in quickReplies)
                        Padding(
                            padding:
                                const EdgeInsets.only(right: AppSpacing.xs),
                            child: ActionChip(
                                label: Text(reply,
                                    style: const TextStyle(fontSize: 12)),
                                onPressed: () {
                                  input.text = reply;
                                  send();
                                }))
                    ])),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                return Align(
                  alignment: message.mine
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                        color:
                            message.mine ? AppColors.primary : AppColors.white,
                        borderRadius: BorderRadius.circular(AppRadii.lg)),
                    child: Text(message.text,
                        style: TextStyle(
                            color:
                                message.mine ? Colors.white : AppColors.text)),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(children: [
              Expanded(
                  child: TextField(
                      controller: input,
                      onSubmitted: (_) => send(),
                      decoration: const InputDecoration(
                          hintText: 'Écrivez votre message…',
                          border: OutlineInputBorder()))),
              IconButton(
                  onPressed: send,
                  icon: const Icon(Icons.send, color: AppColors.primary)),
            ]),
          ),
        ]),
      ),
    );
  }
}
