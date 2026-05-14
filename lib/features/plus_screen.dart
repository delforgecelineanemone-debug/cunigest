// PlusScreen V3 — CuniUI
// Mêmes modules qu'en V2.4, UI redesignée avec CuniUI

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/state_providers.dart';
import '../services/csv_service.dart';
import '../ui/cu_ui.dart';
import '../utils/breakpoints.dart';
import '../utils/theme.dart';
import 'cages/cages_home_screen.dart';
import 'depenses/depenses_screen.dart';
import 'lots/lots_screen.dart';
import 'alimentation/alimentation_screen.dart';
import 'outils/calculatrices_screen.dart';
import 'ventes/ventes_screen.dart';
import 'rapports/rapports_screen.dart';
import 'routine/routine_screen.dart';
import 'reproduction/stats_reproduction_screen.dart';
import 'routine/calendrier_taches_screen.dart';
import 'sync/sync_screen.dart';
import 'reglages/reglages_screen.dart';
import 'auth/users_screen.dart';
import 'qr/qr_scan_screen.dart';

class PlusScreen extends ConsumerWidget {
  const PlusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final session = ref.watch(sessionProvider);
    final reglages = ref.watch(reglagesProvider);
    final estAdmin = session.isAdmin || !session.isAuthenticated;
    final peutVoirFinances =
        session.peutVoirFinances || !session.isAuthenticated;

    // ── Sections ──────────────────────────────────────────────────
    final elevage = <_PlusTileData>[
      _PlusTileData(Icons.grid_view, 'Cages', 'Bâtiments & clapiers',
          CuColors.primary, () => _push(context, const CagesHomeScreen())),
      _PlusTileData(Icons.groups, 'Lots', 'GMQ & IC',
          CuColors.primary, () => _push(context, const LotsScreen())),
      _PlusTileData(Icons.inventory_2, 'Alimentation', 'Stocks & nourriture',
          CuColors.accentFeed, () => _push(context, const AlimentationScreen())),
      _PlusTileData(Icons.bar_chart, 'Stats repro', 'Fertilité & prolificité',
          CuColors.accentRepro, () => _push(context, const StatsReproductionScreen())),
      if (reglages.gamificationActive)
        _PlusTileData(Icons.checklist, 'Ma Routine', 'Checklist quotidienne',
            CuColors.primary, () => _push(context, const RoutineScreen())),
      _PlusTileData(Icons.calendar_month, 'Calendrier', 'Tâches du mois',
          CuColors.primary, () => _push(context, const CalendrierTachesScreen())),
    ];

    final finances = <_PlusTileData>[
      if (peutVoirFinances)
        _PlusTileData(Icons.point_of_sale, 'Ventes', 'Ventes & revenus',
            CuColors.accentFinance, () => _push(context, const VentesScreen())),
      if (peutVoirFinances)
        _PlusTileData(Icons.account_balance_wallet, 'Dépenses', 'Charges & coûts',
            CuColors.accentFinance, () => _push(context, const DepensesScreen())),
      if (peutVoirFinances)
        _PlusTileData(Icons.picture_as_pdf, 'Rapports PDF', 'Mensuel & annuel',
            CuColors.accentFinance, () => _push(context, const RapportsScreen())),
      _PlusTileData(Icons.download, 'Export CSV', 'Lapins, ventes, soins…',
          CuColors.accentFinance, () => _showExportCsvMenu(context)),
    ];

    final outils = <_PlusTileData>[
      _PlusTileData(Icons.calculate, 'Calculatrices', 'Ration, prix, croissance',
          CuColors.accentTools, () => _push(context, const CalculatricesScreen())),
      _PlusTileData(Icons.qr_code_scanner, 'Scanner QR', 'Lapin ou cage',
          CuColors.accentTools, () => _push(context, const QrScanScreen())),
    ];

    final admin = <_PlusTileData>[
      if (estAdmin)
        _PlusTileData(Icons.cloud_sync, 'Sauvegarde cloud', 'Sync automatique',
            CuColors.accentAdmin, () => _push(context, const SyncScreen())),
      if (estAdmin)
        _PlusTileData(Icons.people, 'Utilisateurs', 'Gestion des comptes',
            CuColors.accentAdmin, () => _push(context, const UsersScreen())),
      if (estAdmin)
        _PlusTileData(Icons.settings, 'Réglages', 'Préférences & profil',
            CuColors.accentAdmin, () => _push(context, const ReglagesScreen())),
    ];

    final hPad = context.hPad;

    return Scaffold(
      backgroundColor: isDark ? CuColors.bgDark : CuColors.bgLight,
      appBar: AppBar(title: const Text('Plus')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(hPad, CuSpacing.lg, hPad, CuSpacing.x3l),
        children: [
          if (elevage.isNotEmpty) ...[
            _SectionHeader(label: 'Élevage', icon: Icons.pets),
            _TileGrid(tiles: elevage),
            const SizedBox(height: CuSpacing.xl),
          ],
          if (finances.isNotEmpty) ...[
            _SectionHeader(label: 'Finances', icon: Icons.euro_outlined),
            _TileGrid(tiles: finances),
            const SizedBox(height: CuSpacing.xl),
          ],
          _SectionHeader(label: 'Outils', icon: Icons.build_outlined),
          _TileGrid(tiles: outils),
          if (admin.isNotEmpty) ...[
            const SizedBox(height: CuSpacing.xl),
            _SectionHeader(label: 'Administration', icon: Icons.admin_panel_settings_outlined),
            _TileGrid(tiles: admin),
          ],
        ],
      ),
    );
  }

  static void _push(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  static void _showExportCsvMenu(BuildContext context) {
    final csv = CsvService.instance;
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Row(
                children: [
                  const Icon(Icons.download, color: CuColors.accentFinance),
                  const SizedBox(width: CuSpacing.md),
                  Text('Exporter en CSV',
                      style: Theme.of(ctx).textTheme.titleMedium),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.pets, color: CuColors.primary),
              title: const Text('Cheptel (lapins)'),
              subtitle: const Text('Tous les lapins de l\'élevage'),
              onTap: () { Navigator.pop(ctx); csv.exporterLapins(context); },
            ),
            ListTile(
              leading: const Icon(Icons.point_of_sale, color: CuColors.accentFinance),
              title: const Text('Ventes'),
              subtitle: const Text('Historique des ventes'),
              onTap: () { Navigator.pop(ctx); csv.exporterVentes(context); },
            ),
            ListTile(
              leading: const Icon(Icons.health_and_safety, color: CuColors.accentHealth),
              title: const Text('Soins & vaccinations'),
              subtitle: const Text('Historique sanitaire'),
              onTap: () { Navigator.pop(ctx); csv.exporterSoins(context); },
            ),
            ListTile(
              leading: const Icon(Icons.account_balance_wallet, color: CuColors.accentFinance),
              title: const Text('Dépenses'),
              subtitle: const Text('Charges et coûts'),
              onTap: () { Navigator.pop(ctx); csv.exporterDepenses(context); },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── Section header ─────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  const _SectionHeader({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: CuSpacing.md),
      child: Row(
        children: [
          Icon(icon, size: 16,
              color: isDark ? CuColors.textSecondaryDark : CuColors.textSecondaryLight),
          const SizedBox(width: CuSpacing.xs),
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 1.1,
              fontWeight: FontWeight.w700,
              color: isDark ? CuColors.textSecondaryDark : CuColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Grille de tuiles ──────────────────────────────────────────

class _TileGrid extends StatelessWidget {
  final List<_PlusTileData> tiles;
  const _TileGrid({required this.tiles});

  @override
  Widget build(BuildContext context) {
    final columns = context.moduleColumns;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: CuSpacing.md,
        mainAxisSpacing: CuSpacing.md,
        childAspectRatio: 1.0,
      ),
      itemCount: tiles.length,
      itemBuilder: (_, i) => _PlusTile(data: tiles[i]),
    );
  }
}

// ── Tuile ─────────────────────────────────────────────────────

class _PlusTile extends StatelessWidget {
  final _PlusTileData data;
  const _PlusTile({required this.data});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final d = data;

    return GestureDetector(
      onTap: d.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? CuColors.cardDark : CuColors.cardLight,
          borderRadius: CuRadius.mdAll,
          boxShadow: isDark ? CuShadows.none : CuShadows.level1,
        ),
        child: Padding(
          padding: const EdgeInsets.all(CuSpacing.md),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(CuSpacing.md),
                decoration: BoxDecoration(
                  color: d.color.withValues(alpha: 0.12),
                  borderRadius: CuRadius.smAll,
                ),
                child: Icon(d.icon, color: d.color, size: 26),
              ),
              const SizedBox(height: CuSpacing.sm),
              Text(
                d.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                d.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isDark
                          ? CuColors.textSecondaryDark
                          : CuColors.textSecondaryLight,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlusTileData {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _PlusTileData(
      this.icon, this.label, this.subtitle, this.color, this.onTap);
}
