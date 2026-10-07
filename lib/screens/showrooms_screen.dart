import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/tokens.dart';
import '../widgets/app_header.dart';

class ShowroomsScreen extends StatelessWidget {
  const ShowroomsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
          bottom: false,
          child: Column(children: [
            AppHeader(
                title: 'Nos showrooms',
                onBack: () =>
                    context.canPop() ? context.pop() : context.go('/compte')),
            Expanded(
                child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    children: const [
                  _Showroom(
                      'Showroom Sandaga',
                      '27, avenue Émile Badiane x rue Paul Holl, Sandaga, Dakar',
                      'Lundi – samedi · 9 h – 19 h',
                      'tel:+221766211111',
                      'https://maps.google.com/?q=Sandaga+Dakar'),
                  _Showroom(
                      'Showroom Médina',
                      'Rue 15, Médina, Dakar',
                      'Lundi – samedi · 9 h – 19 h',
                      'tel:+221779980404',
                      'https://maps.google.com/?q=Medina+Dakar')
                ]))
          ])));
}

class _Showroom extends StatelessWidget {
  const _Showroom(this.name, this.address, this.hours, this.phone, this.mapUrl);
  final String name;
  final String address;
  final String hours;
  final String phone;
  final String mapUrl;
  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: AppSpacing.sm),
            Text(address),
            Text(hours, style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: AppSpacing.md),
            Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
              OutlinedButton.icon(
                  onPressed: () => _launch(phone),
                  icon: const Icon(Icons.call),
                  label: const Text('Appeler')),
              ElevatedButton.icon(
                  onPressed: () => _launch(mapUrl),
                  icon: const Icon(Icons.directions),
                  label: const Text('Itinéraire'))
            ])
          ])));
}
