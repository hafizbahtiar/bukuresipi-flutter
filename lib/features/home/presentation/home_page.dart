import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../auth/presentation/pages/account_page.dart';
import '../../family/presentation/family_controller.dart';
import '../../places/presentation/pages/places_list_page.dart';
import '../../places/presentation/pages/places_map_page.dart';
import '../../places/presentation/places_controller.dart';
import '../../recipes/presentation/pages/recipes_page.dart';
import '../../recipes/presentation/recipes_controller.dart';
import '../../shopping/presentation/pages/shopping_page.dart';
import '../../shopping/presentation/shopping_controller.dart';
import '../../shares/presentation/recent_shares.dart';

/// Signed-in home: Book, Recipes, Map, Shopping and Account tabs. Rebuilt after every share (the share page goes back to '/'), so it
/// reloads the places.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _mapTab = 2;
  int _tab = 0;
  bool _mapOpened = false;

  @override
  void initState() {
    super.initState();
    // After the first frame: load() notifies at once (spinner), which is not allowed while this page is building.
    final places = context.read<PlacesController>();
    final recipes = context.read<RecipesController>();
    final shared = context.read<RecentShares>();
    final shopping = context.read<ShoppingController>();
    final family = context.read<FamilyController?>(); // optional: the app works without a family
    void refresh() {
      family?.load();
      places.load();
      recipes.load();
      shopping.load();
      shared.load();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => refresh());
    // Back from TikTok after sharing: the post may be read by now.
    _life = AppLifecycleListener(onResume: refresh);
  }

  late final AppLifecycleListener _life;

  @override
  void dispose() {
    _life.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          const PlacesListPage(),
          const RecipesPage(),
          // The map (a native view, network tiles) is built only once the tab is opened.
          _mapOpened
              ? PlacesMapPage(active: _tab == _mapTab)
              : const SizedBox.shrink(),
          const ShoppingPage(),
          const AccountPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() {
          _tab = i;
          _mapOpened |= i == _mapTab;
        }),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.menu_book_outlined),
            selectedIcon: const Icon(Icons.menu_book),
            label: l.navBook,
          ),
          NavigationDestination(
            icon: const Icon(Icons.restaurant_menu_outlined),
            selectedIcon: const Icon(Icons.restaurant_menu),
            label: l.navRecipes,
          ),
          NavigationDestination(
            icon: const Icon(Icons.map_outlined),
            selectedIcon: const Icon(Icons.map),
            label: l.navMap,
          ),
          NavigationDestination(
            icon: const Icon(Icons.shopping_basket_outlined),
            selectedIcon: const Icon(Icons.shopping_basket),
            label: l.navShopping,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: l.navAccount,
          ),
        ],
      ),
    );
  }
}
