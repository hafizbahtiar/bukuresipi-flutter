import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../auth/presentation/pages/account_page.dart';
import '../../places/presentation/pages/places_list_page.dart';
import '../../places/presentation/pages/places_map_page.dart';
import '../../places/presentation/places_controller.dart';

/// Signed-in home: Book, Map and Account tabs. Rebuilt after every share (the share page goes back to '/'), so it
/// reloads the places.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tab = 0;
  bool _mapOpened = false;

  @override
  void initState() {
    super.initState();
    // After the first frame: load() notifies at once (spinner), which is not allowed while this page is building.
    final places = context.read<PlacesController>();
    WidgetsBinding.instance.addPostFrameCallback((_) => places.load());
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          const PlacesListPage(),
          // The map (a native view, network tiles) is built only once the tab is opened.
          _mapOpened ? const PlacesMapPage() : const SizedBox.shrink(),
          const AccountPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() {
          _tab = i;
          _mapOpened |= i == 1;
        }),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.menu_book_outlined),
            selectedIcon: const Icon(Icons.menu_book),
            label: l.navBook,
          ),
          NavigationDestination(
            icon: const Icon(Icons.map_outlined),
            selectedIcon: const Icon(Icons.map),
            label: l.navMap,
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
