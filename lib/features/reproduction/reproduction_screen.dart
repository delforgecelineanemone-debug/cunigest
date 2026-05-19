// ReproductionScreen V4 — CuniUI
// Logique DB inchangée · Cartes overflow-proof · Wrap dates & résultats

import 'package:flutter/material.dart';
import '../../database/db_helper.dart';
import '../../models/saillie.dart';
import '../../models/lapin.dart';
import '../../services/data_bus.dart';
import '../../ui/cu_ui.dart';
import '../../utils/cu_page_route.dart';
import '../../utils/reactive_state_mixin.dart';
import '../../utils/theme.dart';
import '../../widgets/common_widgets.dart';
import 'saillie_form_screen.dart';

class ReproductionScreen extends StatefulWidget {
  const ReproductionScreen({super.key});

  @override
  State<ReproductionScreen> createState() => _ReproductionScreenState();
}

class _ReproductionScreenState extends State<ReproductionScreen>
    with ReactiveStateMixin<ReproductionScreen> {
  final db = DBHelper.instance;

  @override
  List<String> get watchedTopics =>
      const [DataTopics.saillies, DataTopics.lapins];

  @override
  Future<void> onReactiveRefresh() => _load();
  List<Saillie> _saillies = [];
  Map<int, Lapin> _lapinsMap = {};
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String _filtre = 'tous';
  static const int _pageSize = 60;

  static const _filtres = [
    ('tous', 'Tous'),
    ('en_attente', 'En attente'),
    ('mise_bas', 'Mise bas'),
    ('sevrage', 'Sevrage'),
    ('termine', 'Terminées'),
    ('echec', 'Échecs'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final saillies = await db.getAllSaillies(limit: _pageSize);
    final map = await _lapinsForSaillies(saillies);
    for (var s in saillies) {
      s.mereNom = map[s.mereId]?.displayName ?? '?';
      s.pereNom = map[s.pereId]?.displayName ?? '?';
    }
    if (!mounted) return;
    setState(() {
      _saillies = saillies;
      _lapinsMap = map;
      _hasMore = saillies.length == _pageSize;
      _loading = false;
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _filtre != 'tous') return;
    setState(() => _loadingMore = true);
    final next =
        await db.getAllSaillies(limit: _pageSize, offset: _saillies.length);
    final map = await _lapinsForSaillies(next);
    for (var s in next) {
      s.mereNom = map[s.mereId]?.displayName ?? '?';
      s.pereNom = map[s.pereId]?.displayName ?? '?';
    }
    if (!mounted) return;
    setState(() {
      _lapinsMap.addAll(map);
      _saillies.addAll(next);
      _hasMore = next.length == _pageSize;
      _loadingMore = false;
    });
  }

  Future<Map<int, Lapin>> _lapinsForSaillies(List<Saillie> saillies) =>
      db.getLapinsByIds(saillies.expand((s) => [s.mereId, s.pereId]));

  List<Saillie> get _filtered => _filtre == 'tous'
      ? _saillies
      : _saillies.where((s) => s.statut == _filtre).toList();

  int _count(String statut) =>
      _saillies.where((s) => s.statut == statut).length;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? CuColors.bgDark : CuColors.bgLight,
      appBar: const CuAppBar(
        title: 'Reproduction',
        accent: CuColors.accentRepro,
        automaticallyImplyLeading: false,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _ajouter,
        icon: const Icon(Icons.add),
        label: const Text('Saillie'),
        backgroundColor: CuColors.accentRepro,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // ── KPIs rapides ──
          Padding(
            padding: const EdgeInsets.fromLTRB(
                CuSpacing.lg, CuSpacing.lg, CuSpacing.lg, 0),
            child: Row(
              children: [
                Expanded(
                  child: _MiniKpi(
                    label: 'En attente',
                    count: _count('en_attente'),
                    color: CuColors.warning,
                  ),
                ),
                const SizedBox(width: CuSpacing.sm),
                Expanded(
                  child: _MiniKpi(
                    label: 'Mise bas',
                    count: _count('mise_bas'),
                    color: CuColors.accentTools,
                  ),
                ),
                const SizedBox(width: CuSpacing.sm),
                Expanded(
                  child: _MiniKpi(
                    label: 'Sevrage',
                    count: _count('sevrage'),
                    color: CuColors.accentRepro,
                  ),
                ),
              ],
            ),
          ),

          // ── Filtres ──
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: CuSpacing.lg, vertical: CuSpacing.md),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filtres.map((f) {
                  return Padding(
                    padding: const EdgeInsets.only(right: CuSpacing.sm),
                    child: CuChipFilter(
                      label: f.$2,
                      selected: _filtre == f.$1,
                      color: CuColors.accentRepro,
                      onTap: () => setState(() => _filtre = f.$1),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // ── Liste ──
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: CuColors.accentRepro),
                  )
                : _filtered.isEmpty
                    ? CuEmptyState(
                        title: 'Aucune saillie',
                        hint: 'Enregistrez votre premier accouplement.',
                        icon: Icons.favorite_outline,
                        color: CuColors.accentRepro,
                        actionLabel: 'Enregistrer une saillie',
                        onAction: _ajouter,
                      )
                    : RefreshIndicator(
                        color: CuColors.accentRepro,
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(
                              CuSpacing.lg, 0, CuSpacing.lg, 88),
                          itemCount: _filtered.length +
                              (_hasMore && _filtre == 'tous' ? 1 : 0),
                          itemBuilder: (_, i) {
                            if (i >= _filtered.length) {
                              _loadMore();
                              return const Padding(
                                padding: EdgeInsets.all(CuSpacing.lg),
                                child: Center(
                                  child: CircularProgressIndicator(
                                      color: CuColors.accentRepro),
                                ),
                              );
                            }
                            return _SaillieCard(
                              saillie: _filtered[i],
                              onEdit: () => _modifier(_filtered[i]),
                              onDelete: () => _supprimer(_filtered[i]),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ).responsive(),
    );
  }

  Future<void> _ajouter() async {
    final formMap = await _lapinsActifsMap();
    if (!mounted) return;
    final result = await Navigator.push(
      context,
      CuPageRoute(builder: (_) => SaillieFormScreen(lapinsMap: formMap)),
    );
    if (result == true) _load();
  }

  Future<void> _modifier(Saillie s) async {
    final formMap = await _lapinsActifsMap();
    if (!mounted) return;
    await Navigator.push(
      context,
      CuPageRoute(
          builder: (_) => SaillieFormScreen(saillie: s, lapinsMap: formMap)),
    );
    _load();
  }

  Future<void> _supprimer(Saillie s) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Supprimer cette saillie ?',
      message:
          'Vous aurez 5 secondes pour annuler après confirmation.',
      confirmColor: CuColors.danger,
    );
    if (!ok || !mounted) return;
    // V2.5 — UX Sprint 2 : undo SnackBar 5s.
    await UndoHelper.deleteWithUndo(
      context: context,
      label: 'Saillie du ${s.dateSaillie}',
      delete: () => db.deleteSaillie(s.id!).then((_) {}),
      restore: () => db.insertSaillie(s).then((_) {}),
      onUndone: _load,
    );
    _load();
  }

  Future<Map<int, Lapin>> _lapinsActifsMap() async {
    final lapins = await db.getLapinsByStatut('actif');
    return {for (final l in lapins) if (l.id != null) l.id!: l};
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
            style:
                Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

// ── Carte saillie ──────────────────────────────────────────────
// V4 : bande colorée gauche + Wrap dates + Wrap résultats

class _SaillieCard extends StatelessWidget {
  final Saillie saillie;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SaillieCard({
    required this.saillie,
    required this.onEdit,
    required this.onDelete,
  });

  Color _statutColor(String statut) => switch (statut) {
        'en_attente' => CuColors.warning,
        'mise_bas' => CuColors.accentTools,
        'sevrage' => CuColors.accentRepro,
        'termine' => CuColors.success,
        'echec' => CuColors.danger,
        _ => CuColors.accentAdmin,
      };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final s = saillie;
    final jours = s.joursRestants;
    final urgente = jours != null && jours <= 3 && s.statut == 'en_attente';
    final accentColor = urgente ? CuColors.warning : _statutColor(s.statut);

    return Container(
      margin: const EdgeInsets.only(bottom: CuSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? CuColors.cardDark : CuColors.cardLight,
        borderRadius: CuRadius.mdAll,
        boxShadow: isDark ? CuShadows.none : CuShadows.level1,
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Bande colorée gauche ──
            Container(width: 4, color: accentColor),

            // ── Contenu ──
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    CuSpacing.md, CuSpacing.md, CuSpacing.md, CuSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── En-tête : parents + badge ──
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.favorite,
                            color: CuColors.accentRepro, size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '♀ ${s.mereNom}  ×  ♂ ${s.pereNom}',
                            style: Theme.of(context).textTheme.titleSmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: CuSpacing.xs),
                        _StatutBadge(statut: s.statut),
                      ],
                    ),

                    const SizedBox(height: CuSpacing.sm),
                    Divider(
                      height: 1,
                      thickness: 0.5,
                      color: isDark ? CuColors.borderDark : CuColors.borderLight,
                    ),
                    const SizedBox(height: CuSpacing.sm),

                    // ── Dates — Wrap = jamais d'overflow ──
                    Wrap(
                      spacing: CuSpacing.sm,
                      runSpacing: CuSpacing.xs,
                      children: [
                        _DateChip(
                          icon: Icons.calendar_today_outlined,
                          label: 'Saillie',
                          date: s.dateSaillie,
                        ),
                        if (s.dateMiseBasPrevue != null)
                          _DateChip(
                            icon: Icons.child_care_outlined,
                            label: 'Mise bas',
                            date: s.dateMiseBasPrevue!,
                            highlight: urgente,
                          ),
                      ],
                    ),

                    // ── Compte à rebours ──
                    if (jours != null && s.statut == 'en_attente') ...[
                      const SizedBox(height: CuSpacing.sm),
                      _CountdownBar(jours: jours),
                    ],

                    // ── Résultats naissance — Wrap = jamais d'overflow ──
                    if (s.nbNes != null) ...[
                      const SizedBox(height: CuSpacing.sm),
                      Wrap(
                        spacing: CuSpacing.sm,
                        runSpacing: CuSpacing.xs,
                        children: [
                          _NaissancePill(
                              icon: Icons.egg_outlined,
                              label: 'Nés',
                              val: s.nbNes!),
                          if (s.nbVivants != null)
                            _NaissancePill(
                                icon: Icons.pets,
                                label: 'Vivants',
                                val: s.nbVivants!),
                          if (s.nbSevres != null)
                            _NaissancePill(
                                icon: Icons.free_breakfast_outlined,
                                label: 'Sevrés',
                                val: s.nbSevres!),
                        ],
                      ),
                    ],

                    // ── Actions ──
                    const SizedBox(height: CuSpacing.xs),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.edit_outlined, size: 14),
                          label: const Text('Modifier'),
                          onPressed: onEdit,
                          style: TextButton.styleFrom(
                            foregroundColor: CuColors.primary,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: const EdgeInsets.symmetric(
                                horizontal: CuSpacing.sm, vertical: 4),
                          ),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.delete_outline, size: 14),
                          label: const Text('Supprimer'),
                          onPressed: onDelete,
                          style: TextButton.styleFrom(
                            foregroundColor: CuColors.danger,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: const EdgeInsets.symmetric(
                                horizontal: CuSpacing.sm, vertical: 4),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Badge statut ───────────────────────────────────────────────

class _StatutBadge extends StatelessWidget {
  final String statut;
  const _StatutBadge({required this.statut});

  @override
  Widget build(BuildContext context) {
    final (color, emoji) = switch (statut) {
      'en_attente' => (CuColors.warning, '⏳'),
      'mise_bas' => (CuColors.accentTools, '🐣'),
      'sevrage' => (CuColors.accentRepro, '🍼'),
      'termine' => (CuColors.success, '✅'),
      'echec' => (CuColors.danger, '✗'),
      _ => (CuColors.accentAdmin, statut),
    };
    final label = switch (statut) {
      'en_attente' => 'En attente',
      'mise_bas' => 'Mise bas',
      'sevrage' => 'Sevrage',
      'termine' => 'Terminée',
      'echec' => 'Échec',
      _ => statut,
    };
    return CuBadge(label: '$emoji $label', color: color);
  }
}

// ── Chip date (conteneur autonome, wrappable) ─────────────────

class _DateChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String date;
  final bool highlight;

  const _DateChip({
    required this.icon,
    required this.label,
    required this.date,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = highlight
        ? CuColors.warning
        : (isDark ? CuColors.textSecondaryDark : CuColors.textSecondaryLight);
    final bg = highlight
        ? CuColors.warning.withValues(alpha: 0.10)
        : (isDark ? CuColors.raisedDark : CuColors.raisedLight);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: CuRadius.smAll,
        border: highlight
            ? Border.all(color: CuColors.warning.withValues(alpha: 0.4))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            '$label · ${formatDate(date)}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight:
                      highlight ? FontWeight.w600 : FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}

// ── Compte à rebours ───────────────────────────────────────────

class _CountdownBar extends StatelessWidget {
  final int jours;
  const _CountdownBar({required this.jours});

  @override
  Widget build(BuildContext context) {
    final retard = jours < 0;
    final color = retard
        ? CuColors.danger
        : (jours <= 3 ? CuColors.warning : CuColors.success);
    final label = retard
        ? 'En retard de ${-jours} jour${(-jours) > 1 ? 's' : ''}'
        : '$jours jour${jours > 1 ? 's' : ''} avant la mise bas';

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: CuSpacing.md, vertical: CuSpacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: CuRadius.smAll,
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            retard ? Icons.warning_amber_outlined : Icons.timer_outlined,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pill résultat naissance (conteneur autonome, wrappable) ───

class _NaissancePill extends StatelessWidget {
  final IconData icon;
  final String label;
  final int val;

  const _NaissancePill(
      {required this.icon, required this.label, required this.val});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg =
        isDark ? CuColors.textSecondaryDark : CuColors.textSecondaryLight;
    final bg = isDark ? CuColors.raisedDark : CuColors.raisedLight;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: CuRadius.smAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            '$label ',
            style:
                Theme.of(context).textTheme.labelSmall?.copyWith(color: fg),
          ),
          Text(
            '$val',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
