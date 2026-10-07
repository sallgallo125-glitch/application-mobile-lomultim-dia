import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../contracts/product.dart';
import '../features/catalog/catalog_providers.dart';
import '../theme/tokens.dart';
import '../widgets/app_header.dart';
import '../widgets/commerce/product_card.dart';
import '../widgets/header_actions.dart';
import '../widgets/shimmer.dart' show shopGridColumnsFor;

/// Camera button of the search bars: asks camera or gallery, then opens the
/// photo search page with the picture.
Future<void> startPhotoSearch(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Rechercher par photo',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: AppSpacing.xs),
          const Text(
              'Photographiez un produit pour trouver le même ou un '
              'modèle similaire.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.lg),
          _SourceTile(
              icon: Icons.photo_camera_outlined,
              label: 'Prendre une photo',
              onTap: () => Navigator.pop(context, ImageSource.camera)),
          const SizedBox(height: AppSpacing.sm),
          _SourceTile(
              icon: Icons.photo_library_outlined,
              label: 'Choisir dans la galerie',
              onTap: () => Navigator.pop(context, ImageSource.gallery)),
        ]),
      ),
    ),
  );
  if (source == null || !context.mounted) return;
  try {
    // Downsized: enough for recognition, light to upload.
    final photo = await ImagePicker().pickImage(
        source: source, maxWidth: 1024, maxHeight: 1024, imageQuality: 75);
    if (photo == null || !context.mounted) return;
    context.push('/recherche/photo', extra: photo);
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Impossible d’accéder à l’appareil photo ou aux photos. '
            'Vérifiez les autorisations de l’application.')));
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.md),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(children: [
              Icon(icon, color: AppColors.primaryDark),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w700)),
              ),
              const Icon(Icons.chevron_right, color: AppColors.primaryDark),
            ]),
          ),
        ),
      );
}

/// Photo search: the picture, an "analysing" step, then similar products.
class PhotoSearchScreen extends ConsumerStatefulWidget {
  const PhotoSearchScreen({super.key, required this.photo});
  final XFile? photo;
  @override
  ConsumerState<PhotoSearchScreen> createState() => _PhotoSearchScreenState();
}

class _PhotoSearchScreenState extends ConsumerState<PhotoSearchScreen> {
  late Future<({String detected, List<ProductSummary> products})> _search =
      _run();

  Future<({String detected, List<ProductSummary> products})> _run() async {
    final photo = widget.photo;
    if (photo == null) throw StateError('no photo');
    final bytes = await photo.readAsBytes();
    // Both the analysis and a short minimum, so the step is readable.
    final results = await Future.wait([
      ref.read(catalogRepositoryProvider).searchByImage(base64Encode(bytes)),
      Future<void>.delayed(const Duration(milliseconds: 1600)),
    ]);
    return results.first as ({String detected, List<ProductSummary> products});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          bottom: false,
          child: Column(children: [
            AppHeader(
              title: 'Recherche par photo',
              onBack: () => context.canPop() ? context.pop() : context.go('/'),
              actions: [cartHeaderAction(context, ref)],
            ),
            Expanded(
              child: FutureBuilder(
                future: _search,
                builder: (context, snap) {
                  final preview = _PhotoPreview(photo: widget.photo);
                  if (snap.connectionState != ConnectionState.done) {
                    return ListView(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        children: [
                          _Scanning(child: preview),
                          const SizedBox(height: AppSpacing.lg),
                          const Center(
                            child: Text('Analyse de l’image…',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          const Center(
                            child: Text('Recherche de produits similaires',
                                style:
                                    TextStyle(color: AppColors.textSecondary)),
                          ),
                        ]);
                  }
                  if (snap.hasError) {
                    return _Message(
                      text: 'La recherche par photo n’a pas abouti. '
                          'Réessayez avec une photo plus nette.',
                      onRetry: () => startPhotoSearch(context),
                    );
                  }
                  final result = snap.data!;
                  return _Results(
                    preview: preview,
                    detected: result.detected,
                    products: result.products,
                    onRetake: () => startPhotoSearch(context),
                    onRetry: () => setState(() => _search = _run()),
                  );
                },
              ),
            ),
          ]),
        ),
      );
}

class _PhotoPreview extends StatelessWidget {
  const _PhotoPreview({required this.photo});
  final XFile? photo;
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: ColoredBox(
            color: const Color(0xFFF1F3F7),
            child: photo == null
                ? const Icon(Icons.image_outlined,
                    size: 48, color: AppColors.textSecondary)
                : FutureBuilder(
                    future: photo!.readAsBytes(),
                    builder: (context, snap) => snap.hasData
                        ? Image.memory(snap.data!,
                            fit: BoxFit.cover,
                            // Unreadable picture: neutral placeholder.
                            errorBuilder: (_, __, ___) => const Icon(
                                Icons.image_outlined,
                                size: 48,
                                color: AppColors.textSecondary))
                        : const SizedBox.shrink(),
                  ),
          ),
        ),
      );
}

/// Blue scan line sweeping over the photo while it is analysed.
class _Scanning extends StatefulWidget {
  const _Scanning({required this.child});
  final Widget child;
  @override
  State<_Scanning> createState() => _ScanningState();
}

class _ScanningState extends State<_Scanning>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => Align(
                alignment: Alignment(0, _controller.value * 2 - 1),
                child: Container(
                  height: 3,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x884754A4),
                          blurRadius: 12,
                          spreadRadius: 2),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ]);
}

class _Results extends StatelessWidget {
  const _Results(
      {required this.preview,
      required this.detected,
      required this.products,
      required this.onRetake,
      required this.onRetry});
  final Widget preview;
  final String detected;
  final List<ProductSummary> products;
  final VoidCallback onRetake;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final columns = shopGridColumnsFor(constraints.maxWidth);
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final tileWidth = (constraints.maxWidth -
                2 * AppSpacing.lg -
                (columns - 1) * AppSpacing.sm) /
            columns;
        return CustomScrollView(slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            sliver: SliverToBoxAdapter(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      SizedBox(width: 96, child: preview),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Produits similaires',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800)),
                              if (detected.isNotEmpty)
                                Text('Rayon détecté : $detected',
                                    style: const TextStyle(
                                        color: AppColors.primaryDark,
                                        fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              const Text('Mode démonstration',
                                  style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12)),
                            ]),
                      ),
                    ]),
                    const SizedBox(height: AppSpacing.md),
                    OutlinedButton.icon(
                      onPressed: onRetake,
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Reprendre une photo'),
                    ),
                  ]),
            ),
          ),
          if (products.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Text('Aucun produit similaire trouvé.',
                    textAlign: TextAlign.center),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
              sliver: SliverGrid.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: AppSpacing.sm,
                    mainAxisSpacing: AppSpacing.sm,
                    mainAxisExtent: tileWidth * .85 + 215 * textScale),
                itemCount: products.length,
                itemBuilder: (context, i) => ProductCardWidget(
                    product: products[i],
                    width: double.infinity,
                    onPressed: (p) => context.push('/produit/${p.id}')),
              ),
            ),
        ]);
      });
}

class _Message extends StatelessWidget {
  const _Message({required this.text, required this.onRetry});
  final String text;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.image_not_supported_outlined,
                size: 48, color: AppColors.textSecondary),
            const SizedBox(height: AppSpacing.md),
            Text(text, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(
                onPressed: onRetry, child: const Text('Reprendre une photo')),
          ]),
        ),
      );
}
