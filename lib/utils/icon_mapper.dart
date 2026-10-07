import 'package:flutter/material.dart';

/// Mock data (see lib/mocks/data) stores icon keys as the original Ionicons
/// names from the RN app (e.g. "laptop-outline"), so both apps' mock data
/// stay literally identical. This maps those keys to Material equivalents
/// for rendering here.
const Map<String, IconData> _iconByKey = {
  // categories
  'laptop-outline': Icons.laptop_outlined,
  'phone-portrait-outline': Icons.smartphone_outlined,
  'film-outline': Icons.movie_outlined,
  'wifi-outline': Icons.wifi,
  'shield-checkmark-outline': Icons.shield_outlined,
  'snow-outline': Icons.ac_unit_outlined,
  'book-outline': Icons.menu_book_outlined,
  'game-controller-outline': Icons.sports_esports_outlined,
  // banners
  'wifi': Icons.wifi,
  'laptop': Icons.laptop,
  'diamond': Icons.diamond,
  'book': Icons.menu_book,
  // services
  'build-outline': Icons.build_outlined,
  'diamond-outline': Icons.diamond_outlined,
  'location-outline': Icons.location_on_outlined,
  'chatbubble-ellipses-outline': Icons.chat_bubble_outline,
};

IconData iconForKey(String key) => _iconByKey[key] ?? Icons.circle_outlined;
