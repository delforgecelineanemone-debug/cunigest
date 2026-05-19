// ──────────────────────────────────────────────────────────────
// Écran : Suivi des Dépenses (V2.4 — Phase 4 — Finances)
// ──────────────────────────────────────────────────────────────
// Liste des dépenses, total mensuel, graphique 6 derniers mois,
// répartition par catégorie. CRUD via DepenseFormScreen.
// ──────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../database/db_helper.dart';
import '../../models/depense.dart';
import '../../services/data_bus.dart';
import '../../ui/cu_ui.dart';
import '../../utils/reactive_state_mixin.dart';
import '../../utils/theme.dart';
import '../../widgets/common_widgets.dart';
import 'depense_form_screen.dart';

class DepensesScreen extends StatefulWidget {
  const DepensesScreen({super.key});

  @override
  State<DepensesScreen> createState() => _DepensesScreenState();
}

class _DepensesScreenState extends State<DepensesScreen>
    with ReactiveStateMixin<DepensesScreen> {
  static const int _pageSize = 80;

  @override
  List<String> get watchedTopics => const [DataTopics.depenses];

  @override
  Future<void> onReactiveRefresh() => _load();

  List<Depense> _depenses = [];
  double _totalMois = 0;
  double _totalAnnee = 0;
  Map<String, double> _parCategorie = {};
  Map<String, double> _parMois = {};
  bool _loading = true;
  bool _hasMore = true;
  bool _loadingMore = false;

  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    final repo = await DBHelper.instance.depenses;
    final now = DateTime.now();
    final isoNow = now.toIso8601String().substring(0, 10);
    final isoM = DateTime(now.year, now.month, 1).toIso8601String().substring(0, 10);
    final isoY = DateTime(now.year, 1, 1).toIso8601String().substring(0, 10);

    final (all, tMois, tAnnee, cat, mens) = await (
      repo.getAll(limit: _pageSize),
      repo.totalSurPeriode(isoM, isoNow),
      repo.totalSurPeriode(isoY, isoNow),
      repo.totalParCategorie(isoM, isoNow),
      repo.totalMensuel(6),
    ).wait;

    if (mounted) {
      setState(() {
        _depenses = all;
        _totalMois = tMois;
        _totalAnnee = tAnnee;
        _parCategorie = cat;
        _parMois = mens;
        _hasMore = all.length == _pageSize;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    final repo = await DBHelper.instance.depenses;
    final next = await repo.getAll(limit: _pageSize, offset: _depenses.length);
    if (mounted) {
      setState(() {
        _depenses.addAll(next);
        _hasMore = next.length == _pageSize;
        _loadingMore = false;
      });
    }
  }

  Future<void> _ajouter() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const DepenseFormScreen()),
    );
    if (ok == true) _load();
  }

  Future<void> _modifier(Depense d) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => DepenseFormScreen(depense: d)),
    );
    if (ok == true) _load();
  }

  Future<void> _supprimer(Depense d) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Supprimer cette dépense ?',
      message:
          '${formatMontant(d.montant)} — ${depenseCategorieLabel(d.categorie)}\n\n'
          'Vous aurez 5 secondes pour annuler après confirmation.',
    );
    if (!ok || !mounted) return;
    final repo = await DBHelper.instance.depenses;
    // V2.5 — UX Sprint 2 : undo SnackBar 5s.
    if (!mounted) return;
    await UndoHelper.deleteWithUndo(
      context: context,
      label: 'Dépense ${formatMontant(d.montant)}',
      delete: () => repo.delete(d.id!).then((_) {}),
      restore: () => repo.insert(d).then((_) {}),
      onUndone: _load,
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CuAppBar(
        title: 'Dépenses',
        emoji: '💰',
        accent: CuColors.accentFinance,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _depenses.isEmpty
              ? EmptyState(
                  message: 'Aucune dépense enregistrée',
                  icon: Icons.receipt_long,
                  hint:
                      'Suivez vos dépenses (aliment, soins, matériel…) pour calculer votre coût de production.',
                  onAction: _ajouter,
                  actionLabel: 'Ajouter une dépense',
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    children: [
                      _kpiHeader(),
                      const SizedBox(height: 12),
                      _chartMois(),
                      const SizedBox(height: 12),
                      _categorieBreakdown(),
                      const SizedBox(height: 12),
                      const SectionHeader(title: '📋 Toutes les dépenses'),
                      ..._depenses.map(_depenseTile),
                      if (_loadingMore)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      const SizedBox(height: 80),
                    ],
                  ),
                ).responsive(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _ajouter,
        icon: const Icon(Icons.add),
        label: const Text('Dépense'),
      ),
    );
  }

  Widget _kpiHeader() {
    return Row(
      children: [
        Expanded(
          child: CuKpiCard(
            label: 'Ce mois',
            value: formatMontant(_totalMois),
            icon: Icons.calendar_today,
            color: CuColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: CuKpiCard(
            label: 'Cette année',
            value: formatMontant(_totalAnnee),
            icon: Icons.calendar_view_month,
            color: CuColors.accentFinance,
          ),
        ),
      ],
    );
  }

  Widget _chartMois() {
    if (_parMois.isEmpty) return const SizedBox.shrink();
    final keys = _parMois.keys.toList();
    final maxV = _parMois.values.fold<double>(
        0, (acc, v) => v > acc ? v : acc);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('📊 6 derniers mois',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxV * 1.2,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.05),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        getTitlesWidget: (v, _) => Text(
                          v >= 1000
                              ? '${(v / 1000).toStringAsFixed(1)}k'
                              : v.toStringAsFixed(0),
                          style: TextStyle(
                              fontSize: 10,
                              color: context.cuTextSecondary),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i < 0 || i >= keys.length) {
                            return const SizedBox.shrink();
                          }
                          final mois = keys[i].split('-')[1];
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '$mois/${keys[i].substring(2, 4)}',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: context.cuTextSecondary),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < keys.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: _parMois[keys[i]] ?? 0,
                            color: AppTheme.primary,
                            width: 24,
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4)),
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

  Widget _categorieBreakdown() {
    if (_parCategorie.isEmpty) return const SizedBox.shrink();
    final entries = _parCategorie.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<double>(0, (acc, e) => acc + e.value);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🏷️ Répartition du mois',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            ...entries.map((e) {
              final pct = total > 0 ? e.value / total : 0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(depenseCategorieLabel(e.key),
                              style: const TextStyle(fontSize: 13)),
                        ),
                        Text(formatMontant(e.value),
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct.toDouble(),
                        minHeight: 6,
                        backgroundColor:
                            AppTheme.primary.withValues(alpha: 0.1),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            AppTheme.primary),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _depenseTile(Depense d) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
          child: Text(
            depenseCategorieLabel(d.categorie).split(' ')[0],
            style: const TextStyle(fontSize: 16),
          ),
        ),
        title: Text(d.description ?? depenseCategorieLabel(d.categorie),
            style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(
            '${formatDate(d.dateDepense)} • ${depenseCategorieLabel(d.categorie)}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(formatMontant(d.montant),
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14)),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: Colors.red, size: 20),
              tooltip: 'Supprimer cette dépense', // V2.5 — Sprint 5 a11y
              onPressed: () => _supprimer(d),
            ),
          ],
        ),
        onTap: () => _modifier(d),
      ),
    );
  }
}
