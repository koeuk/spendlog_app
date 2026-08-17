import 'package:flutter/material.dart';

/// The server's CategoryColor / CategoryIcon enums rendered for Flutter.
/// Unknown values fall back rather than crash, so a new server-side color
/// cannot break old app builds.
abstract final class CategoryStyle {
  static const _colors = <String, Color>{
    'slate': Color(0xFF64748B),
    'red': Color(0xFFEF4444),
    'orange': Color(0xFFF97316),
    'amber': Color(0xFFF59E0B),
    'green': Color(0xFF22C55E),
    'teal': Color(0xFF14B8A6),
    'blue': Color(0xFF3B82F6),
    'indigo': Color(0xFF6366F1),
    'purple': Color(0xFFA855F7),
    'pink': Color(0xFFEC4899),
  };

  static const _icons = <String, IconData>{
    'utensils': Icons.restaurant_outlined,
    'car': Icons.directions_car_outlined,
    'receipt': Icons.receipt_long_outlined,
    'shopping-bag': Icons.shopping_bag_outlined,
    'circle-dashed': Icons.category_outlined,
    'house': Icons.home_outlined,
    'coffee': Icons.local_cafe_outlined,
    'plane': Icons.flight_outlined,
    'gift': Icons.card_giftcard_outlined,
    'heart': Icons.favorite_outline,
    'book': Icons.menu_book_outlined,
    'dumbbell': Icons.fitness_center_outlined,
    'smartphone': Icons.smartphone_outlined,
    'zap': Icons.bolt_outlined,
    'piggy-bank': Icons.savings_outlined,
    'fuel': Icons.local_gas_station_outlined,
    'shopping-cart': Icons.shopping_cart_outlined,
    'pill': Icons.medication_outlined,
    'stethoscope': Icons.medical_services_outlined,
    'file-text': Icons.description_outlined,
    'film': Icons.movie_outlined,
    'music': Icons.music_note_outlined,
    'gamepad-2': Icons.sports_esports_outlined,
    'paw-print': Icons.pets_outlined,
    'bus': Icons.directions_bus_outlined,
    'train-front': Icons.train_outlined,
    'hotel': Icons.hotel_outlined,
    'briefcase': Icons.work_outline,
    'landmark': Icons.account_balance_outlined,
    'credit-card': Icons.credit_card_outlined,
  };

  static Color color(String? name) => _colors[name] ?? _colors['slate']!;

  static IconData icon(String? name) => _icons[name] ?? Icons.category_outlined;

  /// Budget status → the color its bar and label render in.
  static Color statusColor(String status) => switch (status) {
        'over' => const Color(0xFFDC2626),
        'warning' => const Color(0xFFF59E0B),
        'ok' => const Color(0xFF22C55E),
        _ => const Color(0xFF9CA3AF),
      };
}
