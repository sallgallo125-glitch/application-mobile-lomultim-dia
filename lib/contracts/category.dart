/// Mirrors ../mobile-app/src/contracts/category.ts
class Category {
  final String id;
  final String name;
  final String icon;

  /// Picture shown in the home "Nos rayons" circles (asset path or URL).
  final String? imageUrl;

  const Category(
      {required this.id, required this.name, required this.icon, this.imageUrl});

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String,
      imageUrl: json['imageUrl'] as String?,
    );
  }
}
