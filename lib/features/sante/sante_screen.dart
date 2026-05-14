// SanteScreen V3 — CuniUI
// Logique DB inchangée · UI redesignée

import 'package:flutter/material.dart';
import '../../database/db_helper.dart';
import '../../models/soin.dart';
import '../../models/lapin.dart';
import '../../ui/cu_ui.dart';
import '../../utils/theme.dart';
import '../../widgets/common_widgets.dart';
import 'soin_form_screen.dart';

class SanteScreen extends StatefulWidget {
  const SanteScreen({super.key});
  @override
  State<SanteScreen> createState() => _SanteScreenState();
}

class _SanteScreenState extends State<SanteScreen> {
  final db = DBHelper.instance;
  List<Soin> _soins = [];
  Map<int, Lapin> _lapinsMap = {};
  List<Soin> _rappels = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String _filtre = 'tous'; // 'tous' | 'rappels' | 'vaccin' | 'soin'
  static const int _pageSize = 80;

  static const _filtres = [
    ('tous', 'Tous'),
    ('rappels', '🔔 Rappels'),
    ('vaccin', '💉 Vaccins'),
    ('soin', '💊 Soins'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final (soins, rappels) = await (
      db.getAllSoins(limit: _pageSize),
      db.getRappelsProchains(14),
    ).wait;
    final map = await db.getLapinsByIds([
      ...soins.where((s) => s.lapinId != null).map((s) => s.lapinId!),
      ...rappels.where((s) => s.lapinId != null).map((s) => s.lapinId!),
    ]);
    for (var s in soins) {
      s.lapinNom = s.lapinId != null
          ? (map[s.lapinId]?.displayName ?? '?')
          : 'Tout l\'élevage';
    }
    for (var s in rappels) {
      s.lapinNom = s.lapinId != null
          ? (map[s.lapinId]?.displayName ?? '?')
          : 'Tout l\'élevage';
    }
    if (!mounted) return;
    setState(() {
      _soins = soins;
      _lapinsMap = map;
      _rappels = rappels;
      _hasMore = soins.length == _pageSize;
      _loading = false;
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _filtre != 'tous') return;
    setState(() => _loadingMore = true);
    final next = await db.getAllSoins(limit: _pageSize, offset: _soins.length);
    final map = await db.getLapinsByIds(
        next.where((s) => s.lapinId != null).map((s) => s.lapinId!));
    for (var s in next) {
      s.lapinNom = s.lapinId != null
          ? (map[s.lapinId]?.displayName ?? '?')
          : 'Tout l\'élevage';
    }
    if (!mounted) return;
    setState(() {
      _lapinsMap.addAll(map);
      _soins.addAll(next);
      _hasMore = next.length == _pageSize;
      _loadingMore = false;
    });
  }

  List<Soin> get _filtered {
    if (_filtre == 'rappels') return _rappels;
    if (_filtre == 'vaccin') {
      return _soins.where((s) => s.typeSoin.toLowerCase().contains('vacc')).toList();
    }
    if (_filtre == 'soin') {
      return _soins.where((s) => !s.typeSoin.toLowerCase().contains('vacc')).toList();
    }
    return _soins;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? CuColors.bgDark : CuColors.bgLight,
      appBar: const CuAppBar(
        title: 'Santé & Soins',
        accent: CuColors.accentHealth,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _ajouter,
        icon: const Icon(Icons.add),
        label: const Text('Soin'),
        backgroundColor: CuColors.accentHealth,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // ── Alerte rappels ──
          if (_rappels.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  CuSpacing.lg, CuSpacing.md, CuSpacing.lg, 0),
              child: CuAlertBanner(
                message:
                    '${_rappels.length} rappel(s) dans les 14 prochains jours',
                level: CuAlertLevel.warning,
                icon: Icons.alarm,
                actionLabel: 'Voir',
                onAction: () => setState(() => _filtre = 'rappels'),
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
                      color: CuColors.accentHealth,
                      count: f.$1 == 'rappels' ? _rappels.length : null,
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
                        color: CuColors.accentHealth))
                : _filtered.isEmpty
                    ? CuEmptyState(
                        title: _filtre == 'rappels'
                            ? 'Aucun rappel prévu ✅'
                            : 'Aucun soin enregistré',
                        hint: _filtre == 'rappels'
                            ? 'Tout est à jour !'
                            : 'Enregistrez traitements et vaccinations.',
                        icon: Icons.health_and_safety_outlined,
                        color: CuColors.accentHealth,
                        actionLabel:
                            _filtre == 'tous' ? 'Ajouter un soin' : null,
                        onAction: _filtre == 'tous' ? _ajouter : null,
                      )
                    : RefreshIndicator(
                        color: CuColors.accentHealth,
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: CuSpacing.lg),
                          itemCount: _filtered.length +
                              (_hasMore && _filtre == 'tous' ? 1 : 0),
                          itemBuilder: (_, i) {
                            if (i >= _filtered.length) {
                              _loadMore();
                              return const Padding(
                                padding: EdgeInsets.all(CuSpacing.lg),
                                child: Center(
                                    child: CircularProgressIndicator(
                                        color: CuColors.accentHealth)),
                              );
                            }
                            return _SoinCard(
                              soin: _filtered[i],
                              onEdit: () => _modifier(_filtered[i]),
                              onDelete: () => _supprimer(_filtered[i]),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _ajouter() async {
    final formMap = await _lapinsActifsMap();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => SoinFormScreen(lapinsMap: formMap)),
    );
    _load();
  }

  Future<void> _modifier(Soin s) async {
    final formMap = await _lapinsActifsMap();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => SoinFormScreen(soin: s, lapinsMap: formMap)),
    );
    _load();
  }

  Future<void> _supprimer(Soin s) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Supprimer ce soin ?',
      message: 'Ce soin sera supprimé définitivement.',
      confirmColor: CuColors.danger,
    );
    if (ok) {
      await db.deleteSoin(s.id!);
      _load();
    }
  }

  Future<Map<int, Lapin>> _lapinsActifsMap() async {
    final lapins = await db.getLapinsByStatut('actif');
    return {for (final l in lapins) if (l.id != null) l.id!: l};
  }
}

// ── Carte soin ─────────────────────────────────────────────────

class _SoinCard extends StatelessWidget {
  final Soin soin;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SoinCard(
      {required this.soin, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final s = soin;
    final isVaccin = s.typeSoin.toLowerCase().contains('vacc');
    final urgence = s.rappelUrgent;
    final accentColor = urgence ? CuColors.warning : CuColors.accentHealth;

    return Container(
      margin: const EdgeInsets.only(bottom: CuSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? CuColors.cardDark : CuColors.cardLight,
        borderRadius: CuRadius.mdAll,
        border: urgence
            ? Border.all(color: CuColors.warning, width: 1.5)
            : null,
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
                Icon(
                  isVaccin ? Icons.vaccines_outlined : Icons.medical_services_outlined,
                  color: accentColor,
                  size: 18,
                ),
                const SizedBox(width: CuSpacing.sm),
                Expanded(
                  child: Text(
                    s.typeSoin,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                CuBadge(
                  label: isVaccin ? '💉 Vaccin' : '💊 Soin',
                  color: isVaccin ? CuColors.accentTools : CuColors.success,
                ),
              ],
            ),

            const SizedBox(height: CuSpacing.sm),

            // ── Lapin ──
            Row(
              children: [
                Icon(Icons.pets, size: 13,
                    color: isDark
                        ? CuColors.textSecondaryDark
                        : CuColors.textSecondaryLight),
                const SizedBox(width: 4),
                Text(
                  s.lapinNom ?? '-',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),

            const SizedBox(height: CuSpacing.sm),

            // ── Infos ──
            Wrap(
              spacing: CuSpacing.lg,
              runSpacing: CuSpacing.xs,
              children: [
                _InfoTag(
                    icon: Icons.calendar_today,
                    text: 'Le ${formatDate(s.dateSoin)}'),
                if (s.produit != null)
                  _InfoTag(icon: Icons.medication_outlined, text: s.produit!),
                if (s.dose != null)
                  _InfoTag(icon: Icons.colorize_outlined, text: s.dose!),
                if (s.cout != null)
                  _InfoTag(
                      icon: Icons.euro_outlined,
                      text: formatMontant(s.cout)),
              ],
            ),

            // ── Rappel ──
            if (s.dateRappel != null) ...[
              const SizedBox(height: CuSpacing.sm),
              _RappelBadge(date: s.dateRappel!, urgent: urgence),
            ],

            // ── Délai d'attente ──
            if (s.delaiAttenteJours != null && s.delaiAttenteJours! > 0) ...[
              const SizedBox(height: CuSpacing.sm),
              _DelaiAttenteIndicator(
                  dateSoin: s.dateSoin,
                  delaiJours: s.delaiAttenteJours!),
            ],

            // ── Actions ──
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.edit_outlined, size: 15),
                  label: const Text('Modifier'),
                  onPressed: onEdit,
                  style: TextButton.styleFrom(
                    foregroundColor: CuColors.primary,
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(
                        horizontal: CuSpacing.sm, vertical: 4),
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline, size: 15),
                  label: const Text('Supprimer'),
                  onPressed: onDelete,
                  style: TextButton.styleFrom(
                    foregroundColor: CuColors.danger,
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(
                        horizontal: CuSpacing.sm, vertical: 4),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTag extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoTag({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color =
        isDark ? CuColors.textSecondaryDark : CuColors.textSecondaryLight;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color)),
      ],
    );
  }
}

class _RappelBadge extends StatelessWidget {
  final String date;
  final bool urgent;
  const _RappelBadge({required this.date, required this.urgent});

  @override
  Widget build(BuildContext context) {
    final color = urgent ? CuColors.warning : CuColors.success;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: CuSpacing.md, vertical: CuSpacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: CuRadius.smAll,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.alarm, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            'Rappel: ${formatDate(date)}',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _DelaiAttenteIndicator extends StatelessWidget {
  final String dateSoin;
  final int delaiJours;
  const _DelaiAttenteIndicator(
      {required this.dateSoin, required this.delaiJours});

  @override
  Widget build(BuildContext context) {
    final soinDate = DateTime.tryParse(dateSoin);
    if (soinDate == null) return const SizedBox.shrink();
    final fin = soinDate.add(Duration(days: delaiJours));
    final restants = fin.difference(DateTime.now()).inDays;
    final passe = restants <= 0;

    if (passe) {
      return CuBadge(
        label: '✓ Délai d\'attente écoulé',
        color: CuColors.success,
      );
    }

    final progress = 1 - (restants / delaiJours).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '⏳ Délai d\'attente : $restants j restants',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: CuColors.warning,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: CuRadius.fullAll,
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: CuColors.warning.withValues(alpha: 0.18),
            color: CuColors.warning,
            minHeight: 5,
          ),
        ),
      ],
    );
  }
}
