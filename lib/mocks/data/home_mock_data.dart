/// Mirrors ../mobile-app/src/mocks/data/home.ts — kept as raw JSON-shaped
/// maps (not typed model instances) so it flows through HomeContent.fromJson
/// exactly like a real HTTP response would.
final List<Map<String, dynamic>> mockBanners = [
  {
    'id': 'b-showroom-1',
    'imageUrl': 'assets/banners/qqq.jpg',
    'icon': 'store',
    'badgeLabel': 'SHOWROOM DAKAR',
    'title': 'LO Multimédia — Médina',
    'subtitle':
        'Avenue Blaise Diagne · Matériel high-tech garanti 100% officiel',
    'ctaLabel': 'Découvrir',
  },
  {
    'id': 'b-showroom-2',
    'imageUrl': 'assets/banners/tel.jpg',
    'icon': 'phone',
    'badgeLabel': 'PRODUITS & RETAIL',
    'title': 'Large choix de smartphones & IT',
    'subtitle': 'Livraison express à Dakar et partout au Sénégal',
    'ctaLabel': 'Voir la boutique',
  },
  {
    'id': 'b-banner2',
    'imageUrl': 'assets/banners/banner2.jpg',
    'icon': 'sparkle',
    'badgeLabel': 'OFFRES SPÉCIALES',
    'title': 'Sélection de produits high-tech',
    'subtitle': 'Des prix imbattables sur le meilleur de la technologie',
    'ctaLabel': 'Profiter des offres',
  },
];

final List<Map<String, dynamic>> mockCategories = [
  {
    'id': 'c-informatique',
    'imageUrl': 'assets/categories/informatique.png',
    'name': 'Informatique',
    'icon': 'laptop-outline'
  },
  {
    'id': 'c-smartphones',
    'imageUrl': 'assets/categories/smartphones.png',
    'name': 'Smartphones',
    'icon': 'phone-portrait-outline'
  },
  {
    'id': 'c-multimedia',
    'imageUrl': 'assets/categories/multimedia.png',
    'name': 'Multimédia',
    'icon': 'film-outline'
  },
  {
    'id': 'c-reseau',
    'imageUrl': 'assets/categories/reseau.png',
    'name': 'Réseau',
    'icon': 'wifi-outline'
  },
  {
    'id': 'c-securite',
    'imageUrl': 'assets/categories/securite.png',
    'name': 'Sécurité',
    'icon': 'shield-checkmark-outline'
  },
  {
    'id': 'c-electromenager',
    'imageUrl': 'assets/categories/electromenager.png',
    'name': 'Électroménager',
    'icon': 'snow-outline'
  },
  {
    'id': 'c-papeterie',
    'imageUrl': 'assets/categories/papeterie.png',
    'name': 'Papeterie',
    'icon': 'book-outline'
  },
  {
    'id': 'c-jeux',
    'imageUrl': 'assets/categories/jeux.png',
    'name': 'Jeux vidéo',
    'icon': 'game-controller-outline'
  },
];
