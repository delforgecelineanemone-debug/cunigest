// LotsScreen V3 — CuniUI
// Logique DB inchangée · UI redesignée avec GMQ coloré + barre J+

import 'package:flutter/material.dart';
import '../../database/db_helper.dart';
import '../../models/lot.dart';
import '../../ui/cu_ui.dart';
import '../../utils/breakpoints.dart';
import 'lot_detail_screen.dart';
import 'lot_form_screen.dart';

class LotsScreen extends StatefulWidget {
  const LotsScreen({super.key});

  @override
  State<LotsScreen> createState() => _LotsScreenState();
}

class _LotsScreenState extends State<LotsScreen> {
  List<Lot> _lots = [];
  Map<int, LotStats> _stats = {};
  bool _loading = true;
  String _filtre = 'tous';

  static const _filtres = [
    ('tous', 'Tous'),
    ('en_cours', 'En cours'),
    ('termine', 'Terminés'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final repo = await DBHelper.instance.lots;
    final lots = await repo.getAll();
    final stats = <int, LotStats>{};
    for (final l in lots) {
      if (l.id != null) stats[l.id!] = await repo.getStats(l.id!);
    }
    if (!mounted) return;
    setState(() {
      _lots = lots;
      _stats = stats;
      _loading = false;
    });
  }

  List<Lot> get _filtered =>
      _filtre == 'tous' ? _lots : _lots.where((l) => l.statut == _filtre).toList();

  int get _enCours => _lots.where((l) => l.statut == 'en_cours').length;
  int get _termines => _lots.where((l) => l.statut == 'termine').length;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hPad = context.hPad;

    return Scaffold(
      backgroundColor: isDark ? CuColors.bgDark : CuColors.bgLight,
      appBar: AppBar(title: const Text('Lots d\'engraissement')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _ajouter,
        icon: const Icon(Icons.add),
        label: const Text('Lot'),
        backgroundColor: CuColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // ── Résumé ──
          Padding(
            padding: EdgeInsets.fromLTRB(hPad, CuSpacing.lg, hPad, 0),
            child: Row(
              children: [
                Expanded(
                  child: _MiniKpi(
                    label: 'En cours',
                    count: _enCours,
                    color: CuColors.primary,
                  ),
                ),
                const SizedBox(width: CuSpacing.sm),
                Expanded(
                  child: _MiniKpi(
                    label: 'Terminés',
                    count: _termines,
                    color: CuColors.accentAdmin,
                  ),
                ),
              ],
            ),
          ),

          // ── Filtres ──
          Padding(
            padding: EdgeInsets.symmetric(
                horizontal: hPad, vertical: CuSpacing.md),
            child: Row(
              children: _filtres.map((f) {
                return Padding(
                  padding: const EdgeInsets.only(right: CuSpacing.sm),
                  child: CuChipFilter(
                    label: f.$2,
                    selected: _filtre == f.$1,
                    onTap: () => setState(() => _filtre = f.$1),
                  ),
                );
              }).toList(),
            ),
          ),

          // ── Liste ──
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: CuColors.primary))
                : _filtered.isEmpty
                    ? CuEmptyState(
                        title: 'Aucun lot d\'engraissement',
                        hint:
                            'Créez un lot après un sevrage pour suivre la croissance.',
                        icon: Icons.groups_outlined,
                        actionLabel: 'Créer un lot',
                        onAction: _ajouter,
                      )
                    : RefreshIndicator(
                        color: CuColors.primary,
                        onRefresh: _load,
                        child: ListView.builder(
                          padding:
                              EdgeInsets.symmetric(horizontal: hPad),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) => _LotCard(
                            lot: _filtered[i],
                            stats: _stats[_filtered[i].id],
                            onTap: () => _ouvrir(_filtered[i]),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _ouvrir(Lot l) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LotDetailScreen(lot: l)),
    );
    _load();
  }

  Future<void> _ajouter() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const LotFormScreen()),
    );
    if (result == true) _load();
  }
}

// ── KPI mini ──────────────────────────────────────────────────

class _MiniKpi extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _MiniKpi(
      {required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: CuSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.18 : 0.10),
        borderRadius: CuRadius.mdAll,
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
          ),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

// ── Carte lot ─────────────────────────────────────────────────

class _LotCard extends StatelessWidget {
  final Lot lot;
  final LotStats? stats;
  final VoidCallback onTap;

  const _LotCard(
      {required this.lot, required this.stats, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l = lot;
    final s = stats;
    final estTermine = l.statut == 'termine';
    final color = estTermine ? CuColors.accentAdmin : CuColors.primary;
    final dateCreation = DateTime.tryParse(l.dateCreation) ?? DateTime.now();
    final jours = DateTime.now().difference(dateCreation).inDays;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: CuSpacing.md),
        decoration: BoxDecoration(
          color: isDark ? CuColors.cardDark : CuColors.cardLight,
          borderRadius: CuRadius.mdAll,
          boxShadow: isDark ? CuShadows.none : CuShadows.level1,
        ),
        child: Padding(
          padding: const EdgeInsets.all(CuSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── En-tête ──
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.14),
                      borderRadius: CuRadius.smAll,
                    ),
                    child: Icon(
                      estTermine ? Icons.check_circle_outline : Icons.groups,
                      color: color,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: CuSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.code,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          'Créé le ${l.dateCreation.split("-").reversed.join("/")}${l.cage != null ? " · Cage ${l.cage}" : ""}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: isDark
                                    ? CuColors.textSecondaryDark
                                    : CuColors.textSecondaryLight,
                              ),
                        ),
                      ],
                    ),
                  ),
                  CuBadge(
                    label: estTermine ? 'Terminé' : 'En cours',
                    color: color,
                    filled: !estTermine,
                  ),
                ],
              ),

              const SizedBox(height: CuSpacing.md),

              // ── KPIs ──
              Row(
                children: [
                  _KpiChip(
                    label: 'Lapins',
                    value: '${s?.nombreActuel ?? l.nombreInitial}/${l.nombreInitial}',
                  ),
                  const SizedBox(width: CuSpacing.md),
                  _KpiChip(
                    label: 'Jours',
                    value: 'J+$jours',
                  ),
                  if (s?.gmq != null) ...[
                    const SizedBox(width: CuSpacing.md),
                    _KpiChip(
                      label: 'GMQ',
                      value: '${s!.gmq!.toStringAsFixed(0)} g/j',
                      color: _couleurGmq(s.gmq),
                    ),
                  ],
                  if (s?.ic != null) ...[
                    const SizedBox(width: CuSpacing.md),
                    _KpiChip(
                      label: 'IC',
                      value: s!.ic!.toStringAsFixed(2),
                      color: _couleurIc(s.ic),
                    ),
                  ],
                ],
              ),

              // ── Barre de progression jours ──
              if (!estTermine && jours > 0) ...[
                const SizedBox(height: CuSpacing.sm),
                _JoursProgressBar(jours: jours),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _couleurGmq(double? gmq) {
    if (gmq == null) return CuColors.accentAdmin;
    if (gmq >= 35) return CuColors.success;
    if (gmq >= 25) return CuColors.warning;
    return CuColors.danger;
  }

  Color _couleurIc(double? ic) {
    if (ic == null) return CuColors.accentAdmin;
    if (ic <= 3.5) return CuColors.success;
    if (ic <= 4.0) return CuColors.warning;
    return CuColors.danger;
  }
}

class _KpiChip extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _KpiChip({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = color ??
        (isDark ? CuColors.textPrimaryDark : CuColors.textPrimaryLight);
    final secondary =
        isDark ? CuColors.textSecondaryDark : CuColors.textSecondaryLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: secondary)),
        Text(value,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: fg,
                )),
      ],
    );
  }
}

class _JoursProgressBar extends StatelessWidget {
  final int jours;
  const _JoursProgressBar({required this.jours});

  @override
  Widget build(BuildContext context) {
    // Durée cible typique engraissement lapin : 70 jours
    const cible = 70;
    final progress = (jours / cible).clamp(0.0, 1.0);
    final color = progress >= 1.0
        ? CuColors.success
        : (progress >= 0.7 ? CuColors.warning : CuColors.primary);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'J+$jours',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: CuColors.textSecondaryLight,
                  ),
            ),
            Text(
              'Objectif J+$cible',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: CuColors.textSecondaryLight,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: CuRadius.fullAll,
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: color.withValues(alpha: 0.15),
            color: color,
            minHeight: 5,
          ),
        ),
      ],
    );
  }
}
