// CheptelHubScreen — Onglet 2 : Lapins | Lots | Cages
// IndexedStack pour lazy-loading (état conservé entre les tabs)

import 'package:flutter/material.dart';
import '../../ui/tokens/colors.dart';
import '../../ui/tokens/typography.dart';
import '../lapins/lapins_list_screen.dart';
import '../lots/lots_screen.dart';
import '../cages/cages_home_screen.dart';

class CheptelHubScreen extends StatefulWidget {
  const CheptelHubScreen({super.key});

  @override
  State<CheptelHubScreen> createState() => _CheptelHubScreenState();
}

class _CheptelHubScreenState extends State<CheptelHubScreen> {
  int _tab = 0;
  late final List<Widget?> _pages;

  static const _tabs = [
    _TabDef(Icons.pets_outlined, Icons.pets, 'Lapins'),
    _TabDef(Icons.groups_outlined, Icons.groups, 'Lots'),
    _TabDef(Icons.grid_view_outlined, Icons.grid_view, 'Cages'),
  ];

  @override
  void initState() {
    super.initState();
    _pages = List.filled(_tabs.length, null);
    _pages[0] = const LapinsListScreen();
  }

  void _select(int i) {
    if (_tab == i) return;
    setState(() {
      _tab = i;
      _pages[i] ??= switch (i) {
        1 => const LotsScreen(),
        2 => const CagesHomeScreen(),
        _ => const LapinsListScreen(),
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? CuColors.bgDark : CuColors.bgLight;
    final tabBg = isDark ? CuColors.cardDark : CuColors.cardLight;
    final border = isDark ? CuColors.borderDark : CuColors.borderLight;

    return Scaffold(
      backgroundColor: bg,
      body: Column(
        children: [
          // ── Tab bar collé sous la status bar ──
          Container(
            color: tabBg,
            child: SafeArea(
              bottom: false,
              child: Container(
                decoration: BoxDecoration(
                  color: tabBg,
                  border: Border(bottom: BorderSide(color: border)),
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 4),
                child: Row(
                  children: List.generate(_tabs.length, (i) {
                    final selected = _tab == i;
                    final t = _tabs[i];
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => _select(i),
                        behavior: HitTestBehavior.opaque,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: selected
                                    ? CuColors.primary
                                    : Colors.transparent,
                                width: 2.5,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                selected ? t.activeIcon : t.icon,
                                size: 18,
                                color: selected
                                    ? CuColors.primary
                                    : (isDark
                                        ? CuColors.textSecondaryDark
                                        : CuColors.textSecondaryLight),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                t.label,
                                style: CuTypography.textTheme.labelMedium
                                    ?.copyWith(
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: selected
                                      ? CuColors.primary
                                      : (isDark
                                          ? CuColors.textSecondaryDark
                                          : CuColors.textSecondaryLight),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
          // ── Contenu ──
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: [
                for (var i = 0; i < _tabs.length; i++)
                  _pages[i] ?? const SizedBox.shrink(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabDef {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _TabDef(this.icon, this.activeIcon, this.label);
}
