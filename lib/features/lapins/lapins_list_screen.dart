// LapinsListScreen V3.5 — ConsumerWidget + AsyncNotifier (P1.8)
// Pagination 80/page · CuSearchBar · CuChipFilter · CuLapinTile
// Réactivité auto via LapinsListNotifier (DataBus subscribe).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/lapin.dart';
import '../../providers/lapins_list_notifier.dart';
import '../../ui/cu_ui.dart';
import '../../utils/breakpoints.dart';
import '../../utils/cu_page_route.dart';
import 'lapin_detail_screen.dart';
import 'lapin_form_screen.dart';

class LapinsListScreen extends ConsumerStatefulWidget {
  /// Quand true, l'écran est intégré dans le Cheptel Hub :
  /// pas de Scaffold appBar (le hub fournit le sien).
  final bool embedded;

  const LapinsListScreen({super.key, this.embedded = false});

  @override
  ConsumerState<LapinsListScreen> createState() => _LapinsListScreenState();
}

class _LapinsListScreenState extends ConsumerState<LapinsListScreen> {
  // Filtres UI purement locaux — pas besoin de re-fetch DB.
  String _search = '';
  String _filtreStatut = 'tous';
  String _filtreSexe = 'tous';

  // ── Filtres disponibles ────────────────────────────────────

  static const _statutFilters = [
    ('tous', 'Tous', null),
    ('actif', 'Actifs', null),
    ('sevrage', 'Sevrage', null),
    ('quarantaine', 'Quarantaine', null),
    ('vendu', 'Vendus', null),
    ('mort', 'Morts', null),
  ];

  static const _sexeFilters = [
    ('tous', 'Tous', null),
    ('male', '♂ Mâles', Icons.male),
    ('femelle', '♀ Femelles', Icons.female),
  ];

  // ── Filtrage local ─────────────────────────────────────────

  List<Lapin> _applyFilter(List<Lapin> lapins) {
    final q = _search.toLowerCase();
    return lapins.where((l) {
      if (q.isNotEmpty) {
        final matchBague = l.numeroBague.toLowerCase().contains(q);
        final matchNom = l.nom?.toLowerCase().contains(q) ?? false;
        final matchRace = l.race?.toLowerCase().contains(q) ?? false;
        if (!matchBague && !matchNom && !matchRace) return false;
      }
      if (_filtreStatut != 'tous' && l.statut != _filtreStatut) return false;
      if (_filtreSexe != 'tous' && l.sexe != _filtreSexe) return false;
      return true;
    }).toList();
  }

  // ── Actions ────────────────────────────────────────────────

  Future<void> _ajouterLapin() async {
    await Navigator.push<bool>(
      context,
      CuPageRoute(builder: (_) => const LapinFormScreen()),
    );
    // Pas de _load() : le DataBus s'en charge via LapinsListNotifier.
  }

  Future<void> _ouvrirFiche(Lapin lapin) async {
    await Navigator.push(
      context,
      CuPageRoute(builder: (_) => LapinDetailScreen(lapin: lapin)),
    );
  }

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hPad = context.hPad;
    final listAsync = ref.watch(lapinsListProvider);
    final notifier = ref.read(lapinsListProvider.notifier);

    return Scaffold(
      backgroundColor: isDark ? CuColors.bgDark : CuColors.bgLight,
      appBar: widget.embedded
          ? null
          // V2.5 — Sprint 4 : emoji thématique pour cohérence visuelle.
          : const CuAppBar(title: 'Lapins', emoji: '🐇'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _ajouterLapin,
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
        backgroundColor: CuColors.primary,
        foregroundColor: Colors.white,
      ),
      body: listAsync.when(
        skipLoadingOnRefresh: true,
        loading: () => _SkeletonList(),
        error: (e, _) => _ErrorBody(message: '$e', onRetry: notifier.refresh),
        data: (data) {
          final filtered = _applyFilter(data.lapins);
          final totalActifs = data.lapins.where((l) => l.statut == 'actif').length;
          final totalMales =
              data.lapins.where((l) => l.sexe == 'male' && l.statut == 'actif').length;
          final totalFemelles = data.lapins
              .where((l) => l.sexe == 'femelle' && l.statut == 'actif')
              .length;

          return Column(
            children: [
              _FiltersBar(
                hPad: hPad,
                filtreStatut: _filtreStatut,
                filtreSexe: _filtreSexe,
                onSearch: (v) => setState(() => _search = v),
                onStatutChanged: (v) => setState(() => _filtreStatut = v),
                onSexeChanged: (v) => setState(() => _filtreSexe = v),
              ),
              _SummaryRow(
                total: filtered.length,
                actifs: totalActifs,
                males: totalMales,
                femelles: totalFemelles,
                hPad: hPad,
              ),
              const SizedBox(height: CuSpacing.sm),
              Expanded(
                child: filtered.isEmpty
                    ? CuEmptyState(
                        title: _search.isNotEmpty
                            ? 'Aucun résultat pour "$_search"'
                            : 'Aucun lapin dans cet élevage',
                        hint: _search.isEmpty
                            ? 'Ajoutez votre premier lapin avec le bouton ci-dessous'
                            : null,
                        icon: Icons.pets,
                        actionLabel: _search.isEmpty ? 'Ajouter un lapin' : null,
                        onAction: _search.isEmpty ? _ajouterLapin : null,
                      )
                    : RefreshIndicator(
                        color: CuColors.primary,
                        onRefresh: notifier.refresh,
                        child: ListView.builder(
                          itemCount: filtered.length +
                              (data.hasMore && _search.isEmpty ? 1 : 0),
                          itemBuilder: (_, i) {
                            if (i >= filtered.length) {
                              notifier.loadMore();
                              return const Padding(
                                padding: EdgeInsets.all(CuSpacing.lg),
                                child: Center(
                                  child: CircularProgressIndicator(
                                      color: CuColors.primary),
                                ),
                              );
                            }
                            final l = filtered[i];
                            final cageNum = l.cageId != null
                                ? data.cageNumero[l.cageId]
                                : l.cageLegacy;
                            return CuLapinTile(
                              bague: l.numeroBague,
                              sexe: l.sexe,
                              statut: l.statut,
                              race: l.race,
                              poids: l.poids,
                              cage: cageNum,
                              photoPath: l.photoPath,
                              heroTag: 'lapin_${l.id}',
                              onTap: () => _ouvrirFiche(l),
                              onSoin: () => _ouvrirFiche(l),
                              onVente: () => _ouvrirFiche(l),
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Barre recherche + filtres ──────────────────────────────────

class _FiltersBar extends StatelessWidget {
  final double hPad;
  final String filtreStatut;
  final String filtreSexe;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onStatutChanged;
  final ValueChanged<String> onSexeChanged;

  const _FiltersBar({
    required this.hPad,
    required this.filtreStatut,
    required this.filtreSexe,
    required this.onSearch,
    required this.onStatutChanged,
    required this.onSexeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: EdgeInsets.fromLTRB(hPad, CuSpacing.md, hPad, CuSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Recherche
          CuSearchBar(
            hint: 'Rechercher par bague, nom, race…',
            onChanged: onSearch,
          ),
          const SizedBox(height: CuSpacing.sm),
          // Filtres sexe
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _LapinsListScreenState._sexeFilters.map((f) {
                return Padding(
                  padding: const EdgeInsets.only(right: CuSpacing.sm),
                  child: CuChipFilter(
                    label: f.$2,
                    selected: filtreSexe == f.$1,
                    icon: f.$3,
                    onTap: () => onSexeChanged(f.$1),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: CuSpacing.xs),
          // Filtres statut
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _LapinsListScreenState._statutFilters.map((f) {
                return Padding(
                  padding: const EdgeInsets.only(right: CuSpacing.sm),
                  child: CuChipFilter(
                    label: f.$2,
                    selected: filtreStatut == f.$1,
                    onTap: () => onStatutChanged(f.$1),
                    color: switch (f.$1) {
                      'actif' => CuColors.primary,
                      'sevrage' => CuColors.accentRepro,
                      'quarantaine' => CuColors.warning,
                      'vendu' => CuColors.accentFinance,
                      'mort' => CuColors.danger,
                      _ => null,
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Résumé rapide ──────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final int total;
  final int actifs;
  final int males;
  final int femelles;
  final double hPad;

  const _SummaryRow({
    required this.total,
    required this.actifs,
    required this.males,
    required this.femelles,
    required this.hPad,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondary = isDark
        ? CuColors.textSecondaryDark
        : CuColors.textSecondaryLight;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: CuSpacing.xs),
      child: Row(
        children: [
          Text(
            '$total résultat${total > 1 ? 's' : ''}',
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: secondary),
          ),
          const Spacer(),
          _dot(CuColors.sexeMale, '♂ $males'),
          const SizedBox(width: CuSpacing.md),
          _dot(CuColors.sexeFemelle, '♀ $femelles'),
        ],
      ),
    );
  }

  Widget _dot(Color c, String label) {
    return Row(
      children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: c)),
      ],
    );
  }
}

// ── Erreur ─────────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBody({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(CuSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                size: 48, color: CuColors.danger),
            const SizedBox(height: CuSpacing.md),
            Text(
              'Impossible de charger la liste',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: CuSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: CuSpacing.lg),
            CuButton(
              label: 'Réessayer',
              icon: Icons.refresh,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Skeleton liste ─────────────────────────────────────────────

class _SkeletonList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shimmer = isDark ? CuColors.raisedDark : CuColors.raisedLight;

    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 8,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: CuSpacing.lg, vertical: CuSpacing.sm),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: shimmer,
                borderRadius: CuRadius.mdAll,
              ),
            ),
            const SizedBox(width: CuSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                      height: 14,
                      width: 120,
                      decoration: BoxDecoration(
                          color: shimmer, borderRadius: CuRadius.smAll)),
                  const SizedBox(height: 6),
                  Container(
                      height: 11,
                      width: 180,
                      decoration: BoxDecoration(
                          color: shimmer, borderRadius: CuRadius.smAll)),
                ],
              ),
            ),
            Container(
                height: 22,
                width: 48,
                decoration: BoxDecoration(
                    color: shimmer, borderRadius: CuRadius.smAll)),
          ],
        ),
      ),
    );
  }
}
