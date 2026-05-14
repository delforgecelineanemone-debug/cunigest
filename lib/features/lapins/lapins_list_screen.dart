// LapinsListScreen V3 — « Field-Premium »
// Pagination 80/page · CuSearchBar · CuChipFilter · CuLapinTile

import 'package:flutter/material.dart';
import '../../database/db_helper.dart';
import '../../models/lapin.dart';
import '../../ui/cu_ui.dart';
import '../../utils/breakpoints.dart';
import '../../utils/cu_page_route.dart';
import '../../utils/theme.dart';
import '../qr/qr_scan_screen.dart';
import 'lapin_detail_screen.dart';
import 'lapin_form_screen.dart';

class LapinsListScreen extends StatefulWidget {
  const LapinsListScreen({super.key});

  @override
  State<LapinsListScreen> createState() => _LapinsListScreenState();
}

class _LapinsListScreenState extends State<LapinsListScreen> {
  final _db = DBHelper.instance;

  List<Lapin> _lapins = [];
  List<Lapin> _filtered = [];
  Map<int, String> _cageNumero = {};

  String _search = '';
  String _filtreStatut = 'tous';
  String _filtreSexe = 'tous';

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;

  static const int _pageSize = 80;

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

  // ── Chargement ─────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final lapins = await _db.getAllLapins(limit: _pageSize);
    final cagesRepo = await _db.cages;
    final cages = await cagesRepo.getAllCages();
    final cageMap = {for (final c in cages) if (c.id != null) c.id!: c.numero};
    if (!mounted) return;
    setState(() {
      _lapins = lapins;
      _cageNumero = cageMap;
      _hasMore = lapins.length == _pageSize;
      _loading = false;
      _applyFilter();
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _search.isNotEmpty) return;
    setState(() => _loadingMore = true);
    final next =
        await _db.getAllLapins(limit: _pageSize, offset: _lapins.length);
    if (!mounted) return;
    setState(() {
      _lapins.addAll(next);
      _hasMore = next.length == _pageSize;
      _loadingMore = false;
      _applyFilter();
    });
  }

  void _applyFilter() {
    _filtered = _lapins.where((l) {
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
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

  // ── Résumé cheptel ─────────────────────────────────────────

  int get _totalActifs =>
      _lapins.where((l) => l.statut == 'actif').length;
  int get _totalMales =>
      _lapins.where((l) => l.sexe == 'male' && l.statut == 'actif').length;
  int get _totalFemelles =>
      _lapins.where((l) => l.sexe == 'femelle' && l.statut == 'actif').length;

  // ── Actions ────────────────────────────────────────────────

  Future<void> _ajouterLapin() async {
    final result = await Navigator.push<bool>(
      context,
      CuPageRoute(builder: (_) => const LapinFormScreen()),
    );
    if (result == true) _load();
  }

  Future<void> _ouvrirFiche(Lapin lapin) async {
    await Navigator.push(
      context,
      CuPageRoute(builder: (_) => LapinDetailScreen(lapin: lapin)),
    );
    _load();
  }

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hPad = context.hPad;

    return Scaffold(
      backgroundColor: isDark ? CuColors.bgDark : CuColors.bgLight,
      appBar: AppBar(
        title: const Text('Cheptel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Scanner un QR',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const QrScanScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _ajouterLapin,
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
        backgroundColor: CuColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // ── Barre de recherche + filtres ──
          _FiltersBar(
            hPad: hPad,
            filtreStatut: _filtreStatut,
            filtreSexe: _filtreSexe,
            onSearch: (v) => setState(() {
              _search = v;
              _applyFilter();
            }),
            onStatutChanged: (v) => setState(() {
              _filtreStatut = v;
              _applyFilter();
            }),
            onSexeChanged: (v) => setState(() {
              _filtreSexe = v;
              _applyFilter();
            }),
          ),

          // ── Résumé rapide ──
          _SummaryRow(
            total: _filtered.length,
            actifs: _totalActifs,
            males: _totalMales,
            femelles: _totalFemelles,
            hPad: hPad,
          ),

          const SizedBox(height: CuSpacing.sm),

          // ── Liste ──
          Expanded(
            child: _loading
                ? _SkeletonList()
                : _filtered.isEmpty
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
                        onRefresh: _load,
                        child: ListView.builder(
                          itemCount: _filtered.length +
                              (_hasMore && _search.isEmpty ? 1 : 0),
                          itemBuilder: (_, i) {
                            if (i >= _filtered.length) {
                              _loadMore();
                              return const Padding(
                                padding: EdgeInsets.all(CuSpacing.lg),
                                child: Center(
                                  child: CircularProgressIndicator(
                                      color: CuColors.primary),
                                ),
                              );
                            }
                            final l = _filtered[i];
                            final cageNum = l.cageId != null
                                ? _cageNumero[l.cageId]
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
          _dot(const Color(0xFF1565C0), '♂ $males'),
          const SizedBox(width: CuSpacing.md),
          _dot(const Color(0xFFEC407A), '♀ $femelles'),
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
