import '../../contracts/digital_code.dart';

/// Digital products sold in the shop (product_variants of the spec): what
/// the card shows and how their code looks. Keyed by catalogue product id.
class DigitalProductSpec {
  const DigitalProductSpec({
    required this.name,
    required this.platform,
    required this.edition,
    required this.region,
    required this.activation,
    required this.sku,
    this.imageAsset,
    this.licenseType,
    this.devices,
  });

  final String name;
  final DigitalPlatform platform;
  final String edition;
  final String region;
  final String activation;
  final String sku;
  final String? imageAsset;
  final String? licenseType;
  final int? devices;

  /// Card preview (no code) for the shop thumbnails.
  DigitalCode preview(String id) => DigitalCode(
        id: 'preview-$id',
        orderNumber: '',
        productName: name,
        platform: platform,
        status: DigitalCodeStatus.pending,
        edition: edition,
        regionCode: region,
        activationMethod: activation,
        sku: sku,
        licenseType: licenseType,
        devices: devices,
      );
}

/// Image URL scheme for digital products: the shop draws the brand card
/// instead of loading a photo.
const digitalImagePrefix = 'digital://';

const digitalCatalog = <String, DigitalProductSpec>{
  'p-200': DigitalProductSpec(
      name: 'Windows 11 Professionnel',
      platform: DigitalPlatform.windows,
      edition: 'Pro',
      region: 'Mondial',
      activation: 'Clé produit',
      sku: 'FQC-10572',
      imageAsset: 'assets/licencejeux/images-removebg-preview.png',
      licenseType: 'Retail',
      devices: 1),
  'p-201': DigitalProductSpec(
      name: 'Windows 11 Famille',
      platform: DigitalPlatform.windows,
      edition: 'Famille',
      region: 'Mondial',
      activation: 'Clé produit',
      sku: 'KW9-00664',
      imageAsset: 'assets/licencejeux/windows10.png',
      licenseType: 'Retail',
      devices: 1),
  'p-202': DigitalProductSpec(
      name: 'Windows 10 Professionnel',
      platform: DigitalPlatform.windows,
      edition: 'Pro',
      region: 'Mondial',
      activation: 'Clé produit',
      sku: 'FQC-09131',
      imageAsset:
          'assets/licencejeux/Microsoft-Windows-10-Pro-OEM-Lifetime-License-Global-500x500-removebg-preview.png',
      licenseType: 'Retail',
      devices: 1),
  'p-203': DigitalProductSpec(
      name: 'Windows 10 Famille',
      platform: DigitalPlatform.windows,
      edition: 'Famille',
      region: 'Mondial',
      activation: 'Clé produit',
      sku: 'KW9-00265',
      licenseType: 'Retail',
      devices: 1),
  'p-210': DigitalProductSpec(
      name: 'EA SPORTS FC 26',
      platform: DigitalPlatform.playstation,
      edition: 'Standard · PS5',
      region: 'EU',
      activation: 'Code PlayStation Store',
      sku: 'PS5-FC26-STD-EU',
      imageAsset:
          'assets/licencejeux/OHKLZFOZZZHOPONXDZNEBDMTTM-removebg-preview.png'),
  'p-211': DigitalProductSpec(
      name: 'Marvel’s Spider-Man 2',
      platform: DigitalPlatform.playstation,
      edition: 'Standard · PS5',
      region: 'EU',
      activation: 'Code PlayStation Store',
      sku: 'PS5-MSM2-STD-EU',
      imageAsset:
          'assets/licencejeux/dd6821cf467f512c7314c1f33224d6aa-removebg-preview.png'),
  'p-212': DigitalProductSpec(
      name: 'Forza Horizon 5',
      platform: DigitalPlatform.xbox,
      edition: 'Premium · Xbox Series X|S',
      region: 'Mondial',
      activation: 'Code Microsoft Store',
      sku: 'XB-FH5-PRM',
      imageAsset:
          'assets/licencejeux/forza-horizon-5-standard-edition-jeu-xbox-seri-removebg-preview.png'),
  'p-213': DigitalProductSpec(
      name: 'Mario Kart World',
      platform: DigitalPlatform.nintendo,
      edition: 'Standard · Switch 2',
      region: 'EU',
      activation: 'Code Nintendo eShop',
      sku: 'NSW2-MKW-EU',
      imageAsset:
          'assets/licencejeux/8cb64123-mario-kart-world__1200_1200-removebg-preview.png'),
  'p-214': DigitalProductSpec(
      name: 'Zelda: Tears of the Kingdom',
      platform: DigitalPlatform.nintendo,
      edition: 'Standard · Switch',
      region: 'EU',
      activation: 'Code Nintendo eShop',
      sku: 'NSW-TOTK-EU',
      imageAsset: 'assets/licencejeux/512LtDpmtOL-removebg-preview.png'),
  'p-215': DigitalProductSpec(
      name: 'Cyberpunk 2077',
      platform: DigitalPlatform.steam,
      edition: 'Ultimate · PC',
      region: 'Mondial',
      activation: 'Clé Steam',
      sku: 'STM-CP77-ULT',
      imageAsset:
          'assets/licencejeux/Cyberpunk-2077-Ultimate-Edition-ps5-cover-removebg-preview.png'),
};

DigitalProductSpec? digitalSpecFromImage(String url) =>
    url.startsWith(digitalImagePrefix)
        ? digitalCatalog[url.substring(digitalImagePrefix.length)]
        : null;
