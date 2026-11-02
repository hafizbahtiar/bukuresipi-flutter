import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../places/presentation/pages/places_list_page.dart';
import '../../places/presentation/pages/places_map_page.dart';
import '../../places/presentation/places_controller.dart';

/// Signed-in home: Book and Map tabs. Rebuilt after every share (the share page goes back to '/'), so it reloads.
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
    context.read<PlacesController>().load();
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
        ],
      ),
    );
  }
}
