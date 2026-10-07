/// Configurable options of the demo laptops, taken from the
/// "Mobile E-commerce App Design" mock-up (src/App.tsx, ProductScreen and
/// `configuredPrice`): RAM, storage, operating system and optional
/// accessories. The real catalogue (ERP) will send these per product.
library;

/// Price of each choice in the mock-up, relative to its cheapest-but-one
/// option; a product's own default is subtracted to get its deltas.
const _ramPrices = {'8 Go': 0, '16 Go': 35000, '32 Go': 85000};
const _storagePrices = {
  '256 Go SSD': -20000,
  '512 Go SSD': 0,
  '1 To SSD': 75000
};
const _osPrices = {'Sans licence': 0, 'Windows 11 Pro': 65000};

/// Base configuration of each laptop (what its catalogue price includes).
const _laptopDefaults = {
  'p-001': ('16 Go', '512 Go SSD'), // HP ProBook 450 G10
  'p-002': ('16 Go', '512 Go SSD'), // Lenovo ThinkPad E14
  'p-003': ('8 Go', '512 Go SSD'), // ASUS Vivobook 15
  'p-031': ('16 Go', '512 Go SSD'), // PC Gamer ASUS TUF
};

String _id(String label) =>
    label.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');

Map<String, dynamic> _group(
    String id, String label, Map<String, int> prices, String defaultLabel) {
  final base = prices[defaultLabel]!;
  return {
    'id': id,
    'label': label,
    'defaultChoiceId': '$id-${_id(defaultLabel)}',
    'choices': [
      for (final e in prices.entries)
        {
          'id': '$id-${_id(e.key)}',
          'label': e.key,
          'priceDeltaXof': e.value - base,
          'inStock': true,
        }
    ],
  };
}

/// Option groups of [productId], empty for non-configurable products.
List<Map<String, dynamic>> optionGroupsFor(String productId) {
  final d = _laptopDefaults[productId];
  if (d == null) return const [];
  return [
    _group('ram', 'Mémoire RAM', _ramPrices, d.$1),
    _group('storage', 'Stockage', _storagePrices, d.$2),
    _group('os', "Système d'exploitation", _osPrices, 'Sans licence'),
  ];
}

/// "Complétez votre équipement" accessories (+15 000 F each in the mock-up).
List<Map<String, dynamic>> accessoriesFor(String productId) =>
    _laptopDefaults.containsKey(productId)
        ? [
            for (final name in ['Sacoche', 'Souris', 'Onduleur'])
              {
                'id': '$productId-${_id(name)}',
                'name': name,
                'priceXof': 15000
              },
          ]
        : const [];
