// MainScaffold — Navigation V4
// Mobile  : 5 onglets (barre standard, sans FAB central)
// Tablette : NavigationRail compact
// Desktop  : NavigationRail étendu
//
// Onglets : Accueil | Cheptel | Reproduction | Tâches | Plus

import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../ui/tokens/colors.dart';
import '../utils/breakpoints.dart';
import '../utils/cu_page_route.dart';
import '../utils/theme.dart';
import 'cheptel/cheptel_hub_screen.dart';
import 'dashboard_screen.dart';
import 'lapins/lapin_form_screen.dart';
import 'reproduction/reproduction_screen.dart';
import 'reproduction/saillie_form_screen.dart';
import 'sante/soin_form_screen.dart';
import 'routine/routine_screen.dart';
import 'plus_screen.dart';
import 'qr/qr_scan_screen.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  late int _index;

  // 5 onglets : Accueil | Cheptel | Reproduction | Tâches | Plus
  static const int _tabCount = 5;
  late final List<Widget?> _tabs;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, _tabCount - 1);
    _tabs = List<Widget?>.filled(_tabCount, null);
    _tabs[_index] = _buildTab(_index);
  }

  void _onSelect(int i) {
    if (i == _index) return;
    setState(() {
      _index = i;
      _tabs[i] ??= _buildTab(i);
    });
  }

  // ── Destinations ──────────────────────────────────────────────

  static const _destinations = [
    _NavItem(
      label: 'Accueil',
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
    ),
    _NavItem(
      label: 'Cheptel',
      icon: Icons.pets_outlined,
      activeIcon: Icons.pets,
    ),
    _NavItem(
      label: 'Repro',
      icon: Icons.favorite_outline,
      activeIcon: Icons.favorite,
    ),
    _NavItem(
      label: 'Tâches',
      icon: Icons.checklist_outlined,
      activeIcon: Icons.checklist,
    ),
    _NavItem(
      label: 'Plus',
      icon: Icons.apps_outlined,
      activeIcon: Icons.apps,
    ),
  ];

  // ── Build ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final stack = IndexedStack(
      index: _index,
      children: [
        for (var i = 0; i < _tabCount; i++)
          _tabs[i] ?? const SizedBox.shrink(),
      ],
    );

    if (context.isWide) return _wideLayout(stack);
    return _mobileLayout(stack);
  }

  // ── Layout mobile (< 600 px) ───────────────────────────────────

  Widget _mobileLayout(Widget content) {
    return Scaffold(
      body: content,
      bottomNavigationBar: _BottomBar(
        index: _index,
        onSelect: _onSelect,
      ),
    );
  }

  // ── Layout large (≥ 600 px) ────────────────────────────────────

  Widget _wideLayout(Widget content) {
    final isDesktop = context.isDesktop;

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: _onSelect,
              extended: isDesktop,
              labelType: isDesktop
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
              leading: isDesktop
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: FloatingActionButton.small(
                        onPressed: _showActionsDesktop,
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        child: const Icon(Icons.add),
                      ),
                    )
                  : null,
              destinations: _destinations.map((d) {
                return NavigationRailDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.activeIcon),
                  label: Text(d.label),
                );
              }).toList(),
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }

  // ── Actions rapides desktop ────────────────────────────────────

  void _showActionsDesktop() {
    showModalBottomSheet(
      context: context,
      builder: (_) => _QuickActionsSheet(),
    );
  }

  // ── Tabs ──────────────────────────────────────────────────────

  Widget _buildTab(int i) => switch (i) {
        0 => const DashboardScreen(),
        1 => const CheptelHubScreen(),
        2 => const ReproductionScreen(),
        3 => const RoutineScreen(),
        _ => const PlusScreen(),
      };
}

// ── Barre de navigation 5 onglets ─────────────────────────────

class _BottomBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onSelect;

  const _BottomBar({required this.index, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? CuColors.navBgDark : CuColors.navBgLight;
    final border = isDark ? CuColors.borderDark : CuColors.borderLight;
    final unsel =
        isDark ? CuColors.textDisabledDark : CuColors.textDisabledLight;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(
              _MainScaffoldState._destinations.length,
              (i) => _tab(
                context,
                i,
                _MainScaffoldState._destinations[i],
                index == i,
                unsel,
                onSelect,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tab(
    BuildContext context,
    int i,
    _NavItem d,
    bool selected,
    Color unsel,
    ValueChanged<int> onSelect,
  ) {
    // L'onglet Reproduction (index 2) prend la couleur accent repro
    final activeColor =
        i == 2 ? CuColors.accentRepro : AppTheme.primary;
    final color = selected ? activeColor : unsel;

    return Expanded(
      child: GestureDetector(
        onTap: () => onSelect(i),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? d.activeIcon : d.icon, size: 22, color: color),
            const SizedBox(height: 3),
            Text(
              d.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Chargement lapins + navigation saillie ─────────────────────

Future<void> _openSaillieForm(BuildContext context) async {
  final lapins = await DBHelper.instance.getAllLapins();
  final map = {for (final l in lapins) l.id!: l};
  if (!context.mounted) return;
  Navigator.push(
    context,
    CuPageRoute(
      builder: (_) => SaillieFormScreen(lapinsMap: map),
    ),
  );
}

// ── Feuille actions rapides desktop ───────────────────────────

class _QuickActionsSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final items = [
      _QuickItem(Icons.pets, 'Nouveau lapin', CuColors.primary,
          (_) => const LapinFormScreen()),
      _QuickItem(Icons.favorite, 'Nouvelle saillie', CuColors.accentRepro,
          null),
      _QuickItem(Icons.medical_services, 'Nouveau soin', CuColors.accentHealth,
          (_) => const SoinFormScreen()),
      _QuickItem(Icons.qr_code_scanner, 'Scanner QR', CuColors.accentTools,
          (_) => const QrScanScreen()),
    ];

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Actions rapides',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          ...items.map(
            (item) => ListTile(
              leading: CircleAvatar(
                backgroundColor: item.color.withValues(alpha: 0.14),
                child: Icon(item.icon, color: item.color),
              ),
              title: Text(item.label),
              onTap: () async {
                Navigator.pop(context);
                if (item.builder != null) {
                  Navigator.push(
                    context,
                    CuPageRoute(builder: item.builder!),
                  );
                } else {
                  await _openSaillieForm(context);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickItem {
  final IconData icon;
  final String label;
  final Color color;
  final WidgetBuilder? builder;

  const _QuickItem(this.icon, this.label, this.color, this.builder);
}

// ── Modèle item navigation ─────────────────────────────────────

class _NavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}
