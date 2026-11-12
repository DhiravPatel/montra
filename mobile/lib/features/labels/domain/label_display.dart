import 'package:flutter/material.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/core/api/generated/models.dart';

/// English names the server gives the starter categories it creates for
/// every new account (`system_key` → name). A category whose name still
/// equals its starter name is shown in the user's language; a renamed one
/// keeps the user's name.
const Map<String, String> starterCategoryNames = <String, String>{
  'food_dining': 'Food & dining',
  'groceries': 'Groceries',
  'transport': 'Transport',
  'fuel': 'Fuel',
  'housing_rent': 'Housing & rent',
  'utilities': 'Utilities',
  'shopping': 'Shopping',
  'healthcare': 'Healthcare',
  'education': 'Education',
  'entertainment': 'Entertainment',
  'travel': 'Travel',
  'personal_care': 'Personal care',
  'insurance': 'Insurance',
  'taxes_fees': 'Taxes & fees',
  'gifts_donations': 'Gifts & donations',
  'family': 'Family',
  'work_expenses': 'Work expenses',
  'salary': 'Salary',
  'freelance_income': 'Freelance income',
  'interest': 'Interest',
  'refunds': 'Refunds',
  'other': 'Other',
};

/// The localized name of a starter category, or null for other keys.
String? starterCategoryLabel(AppLocalizations l10n, String systemKey) =>
    switch (systemKey) {
      'food_dining' => l10n.starterFoodDining,
      'groceries' => l10n.starterGroceries,
      'transport' => l10n.starterTransport,
      'fuel' => l10n.starterFuel,
      'housing_rent' => l10n.starterHousingRent,
      'utilities' => l10n.starterUtilities,
      'shopping' => l10n.starterShopping,
      'healthcare' => l10n.starterHealthcare,
      'education' => l10n.starterEducation,
      'entertainment' => l10n.starterEntertainment,
      'travel' => l10n.starterTravel,
      'personal_care' => l10n.starterPersonalCare,
      'insurance' => l10n.starterInsurance,
      'taxes_fees' => l10n.starterTaxesFees,
      'gifts_donations' => l10n.starterGiftsDonations,
      'family' => l10n.starterFamily,
      'work_expenses' => l10n.starterWorkExpenses,
      'salary' => l10n.starterSalary,
      'freelance_income' => l10n.starterFreelanceIncome,
      'interest' => l10n.starterInterest,
      'refunds' => l10n.starterRefunds,
      'other' => l10n.starterOther,
      _ => null,
    };

/// Display name for a category called [name] with an optional starter
/// [systemKey].
String categoryDisplayName(
  AppLocalizations l10n, {
  required String name,
  String? systemKey,
}) {
  final String? key = systemKey;
  if (key == null || starterCategoryNames[key] != name) {
    return name;
  }
  return starterCategoryLabel(l10n, key) ?? name;
}

/// Display name of [category].
String categoryName(AppLocalizations l10n, CategoryDto category) =>
    categoryDisplayName(
      l10n,
      name: category.name,
      systemKey: category.systemKey,
    );

/// Display name of a category reference embedded in a transaction.
String categoryRefDisplay(AppLocalizations l10n, CategoryRef ref) =>
    categoryDisplayName(l10n, name: ref.name, systemKey: ref.systemKey);

/// Display name of a dashboard category slice (`uncategorized` included).
String categorySliceName(AppLocalizations l10n, CategorySlice slice) =>
    slice.categoryId == null || slice.systemKey == 'uncategorized'
    ? l10n.categoryUncategorized
    : categoryDisplayName(l10n, name: slice.name, systemKey: slice.systemKey);

/// Material icon for the server's icon name (starter categories use
/// Material Symbols names); a generic icon otherwise.
IconData categoryIcon(String? name) => switch (name) {
  'restaurant' => Icons.restaurant,
  'shopping_cart' => Icons.shopping_cart_outlined,
  'directions_bus' => Icons.directions_bus_outlined,
  'local_gas_station' => Icons.local_gas_station_outlined,
  'home' => Icons.home_outlined,
  'bolt' => Icons.bolt_outlined,
  'shopping_bag' => Icons.shopping_bag_outlined,
  'medical_services' => Icons.medical_services_outlined,
  'school' => Icons.school_outlined,
  'movie' => Icons.movie_outlined,
  'flight' => Icons.flight_outlined,
  'spa' => Icons.spa_outlined,
  'verified_user' => Icons.verified_user_outlined,
  'receipt_long' => Icons.receipt_long_outlined,
  'redeem' => Icons.redeem_outlined,
  'family_restroom' => Icons.family_restroom_outlined,
  'work' => Icons.work_outline,
  'payments' => Icons.payments_outlined,
  'laptop' => Icons.laptop_outlined,
  'savings' => Icons.savings_outlined,
  'undo' => Icons.undo,
  _ => Icons.category_outlined,
};

/// Parses `#RRGGBB`; null for anything else.
Color? parseHexColor(String? hex) {
  if (hex == null) {
    return null;
  }
  final Match? match = RegExp(r'^#([0-9A-Fa-f]{6})$').firstMatch(hex.trim());
  if (match == null) {
    return null;
  }
  return Color(0xFF000000 | int.parse(match.group(1)!, radix: 16));
}

/// A small round category badge: the category icon on its color. Purely
/// decorative; the category name always appears as text next to it.
class CategoryBadge extends StatelessWidget {
  /// Creates the badge.
  const CategoryBadge({this.icon, this.color, this.size = 36, super.key});

  /// Server icon name.
  final String? icon;

  /// Server color (`#RRGGBB`).
  final String? color;

  /// Diameter.
  final double size;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color? base = parseHexColor(color);
    final Color background = base == null
        ? scheme.secondaryContainer
        : Color.alphaBlend(base.withValues(alpha: 0.28), scheme.surface);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: background, shape: BoxShape.circle),
        child: Icon(
          categoryIcon(icon),
          size: size * 0.55,
          color: scheme.onSurface,
        ),
      ),
    );
  }
}
