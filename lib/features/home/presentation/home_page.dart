import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../auth/presentation/pages/account_page.dart';
import '../../family/presentation/family_controller.dart';
import '../../places/presentation/pages/places_list_page.dart';
import '../../places/presentation/places_controller.dart';
import '../../recipes/presentation/recipes_controller.dart';
import '../../shopping/presentation/pages/shopping_page.dart';
import '../../shopping/presentation/shopping_controller.dart';
import '../../shares/presentation/recent_shares.dart';
import 'add_sheet.dart';
import 'feed_page.dart';

/// Signed-in home: Home (feed, with the map button), Book, Shopping and Account tabs, and "+" in the middle (add
/// anything: [showAddSheet]; it is a button, not a tab). Rebuilt after every share (the share page goes back to '/'), so it
/// reloads the places.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    // After the first frame: load() notifies at once (spinner), which is not allowed while this page is building.
    final places = context.read<PlacesController>();
    final recipes = context.read<RecipesController>();
    final shared = context.read<RecentShares>();
    final shopping = context.read<ShoppingController>();
    final family = context
        .read<FamilyController?>(); // optional: the app works without a family
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
        children: const [
          FeedPage(),
          PlacesListPage(),
          ShoppingPage(),
          AccountPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        // Index 2 is "+": the tabs after it sit one place to the right.
        selectedIndex: _tab < 2 ? _tab : _tab + 1,
        onDestinationSelected: (i) {
          if (i == 2) {
            showAddSheet(context);
          } else {
            setState(() => _tab = i < 2 ? i : i - 1);
          }
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: l.navHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.menu_book_outlined),
            selectedIcon: const Icon(Icons.menu_book),
            label: l.navBook,
          ),
          NavigationDestination(
            key: const ValueKey('nav-add'),
            icon: const Icon(Icons.add_circle, size: 36),
            label: l.navAdd,
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
