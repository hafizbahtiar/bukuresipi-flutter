import 'package:flutter/material.dart';

import '../../../../l10n/gen/app_localizations.dart';

/// A place's icon: its subcategory's when set, else its category's. Unknown (a newer server's) = a plain pin.
IconData placeCategoryIcon(String category, [String? subcategory]) =>
    switch (subcategory) {
      'restaurant' => Icons.restaurant,
      'cafe' => Icons.local_cafe_outlined,
      'stall' => Icons.storefront_outlined,
      'mamak' => Icons.ramen_dining_outlined,
      'kopitiam' => Icons.coffee_outlined,
      'food_court' => Icons.food_bank_outlined,
      'bakery' => Icons.bakery_dining_outlined,
      'dessert' => Icons.icecream_outlined,
      'fast_food' => Icons.fastfood_outlined,
      'grocery' => Icons.local_grocery_store_outlined,
      'market' => Icons.storefront_outlined,
      'mall' => Icons.local_mall_outlined,
      'museum' => Icons.museum_outlined,
      'theme_park' => Icons.attractions_outlined,
      'landmark' => Icons.account_balance_outlined,
      'hotel' => Icons.hotel_outlined,
      'homestay' => Icons.house_outlined,
      'resort' => Icons.pool_outlined,
      'park' => Icons.park_outlined,
      'beach' => Icons.beach_access_outlined,
      'waterfall' => Icons.water_outlined,
      'hiking' => Icons.hiking,
      _ => switch (category) {
        'food' => Icons.restaurant,
        'shop' => Icons.shopping_bag_outlined,
        'attraction' => Icons.attractions_outlined,
        'stay' => Icons.hotel_outlined,
        'outdoor' => Icons.park_outlined,
        _ => Icons.place_outlined,
      },
    };

/// A category's name in the app's language; an unknown one shows as "Other".
String placeCategoryLabel(AppLocalizations l, String category) =>
    switch (category) {
      'food' => l.placeCategoryFood,
      'shop' => l.placeCategoryShop,
      'attraction' => l.placeCategoryAttraction,
      'stay' => l.placeCategoryStay,
      'outdoor' => l.placeCategoryOutdoor,
      _ => l.placeCategoryOther,
    };

/// A subcategory's name; '' (the picker's "not set") or an unknown one = "Not set".
String placeSubcategoryLabel(AppLocalizations l, String subcategory) =>
    switch (subcategory) {
      'restaurant' => l.placeSubRestaurant,
      'cafe' => l.placeSubCafe,
      'stall' => l.placeSubStall,
      'mamak' => l.placeSubMamak,
      'kopitiam' => l.placeSubKopitiam,
      'food_court' => l.placeSubFoodCourt,
      'bakery' => l.placeSubBakery,
      'dessert' => l.placeSubDessert,
      'fast_food' => l.placeSubFastFood,
      'grocery' => l.placeSubGrocery,
      'market' => l.placeSubMarket,
      'mall' => l.placeSubMall,
      'museum' => l.placeSubMuseum,
      'theme_park' => l.placeSubThemePark,
      'landmark' => l.placeSubLandmark,
      'hotel' => l.placeSubHotel,
      'homestay' => l.placeSubHomestay,
      'resort' => l.placeSubResort,
      'park' => l.placeSubPark,
      'beach' => l.placeSubBeach,
      'waterfall' => l.placeSubWaterfall,
      'hiking' => l.placeSubHiking,
      _ => l.placeSubcategoryNone,
    };
