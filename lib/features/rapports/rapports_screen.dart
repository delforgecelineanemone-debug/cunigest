// ──────────────────────────────────────────────────────────────
// Écran : Rapports — Dashboard du mois + génération PDF
// ──────────────────────────────────────────────────────────────
// V2.5 (Phase 4) : ajout dashboard visuel au-dessus des PDF :
//   - 3 KPI : recettes / dépenses / marge bénéficiaire
//   - Top clients du mois
//   - Area chart évolution cheptel 6 mois (naissances)
// Les PDF mensuel/annuel restent disponibles en bas.
// ──────────────────────────────────────────────────────────────

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../database/db_helper.dart';
import '../../services/pdf_service.dart';
import '../../ui/cu_ui.dart';
import '../../utils/theme.dart';
import '../../widgets/common_widgets.dart';

class RapportsScreen extends StatefulWidget {
  const RapportsScreen({super.key});

  @override
  State<RapportsScreen> createState() => _RapportsScreenState();
}

class _RapportsScreenState extends State<RapportsScreen> {
  bool _busy = false;
  DateTime _moisChoisi = DateTime(DateTime.now().year, DateTime.now().month);
  int _anneeChoisie = DateTime.now().year;

  // Dashboard du mois courant
  bool _loadingDashboard = true;
  double _recettesMois = 0;
  double _depensesMois = 0;
  List<Map<String, dynamic>> _topClients = const [];
  Map<String, int> _naissances6Mois = const {};

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() => _loadingDashboard = true);
    final now = DateTime.now();
    final monthStr = now.month.toString().padLeft(2, '0');
    final from = '${now.year}-$monthStr-01';
    final lastDay = DateTime(now.year, now.month + 1, 0).day;
    final to = '${now.year}-$monthStr-${lastDay.toString().padLeft(2, '0')}';

    final stats = await DBHelper.instance.getStatistiquesVentes();
    final depRepo = await DBHelper.instance.depenses;
    final dep = await depRepo.totalSurPeriode(from, to);
    final clients =
        await DBHelper.instance.getTopClients(from: from, to: to, limit: 5);
    final naissances = await DBHelper.instance.naissancesParMois(6);

    if (!mounted) return;
    setState(() {
      _recettesMois = (stats['chiffre_affaires_mois'] as num).toDouble();
      _depensesMois = dep;
      _topClients = clients;
      _naissances6Mois = naissances;
      _loadingDashboard = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CuAppBar(
        title: 'Rapports',
        emoji: '📄',
        extraActions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Rafraîchir',
            onPressed: _loadingDashboard ? null : _loadDashboard,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Dashboard du mois ──
          _MonthDashboard(
            loading: _loadingDashboard,
            recettes: _recettesMois,
            depenses: _depensesMois,
            topClients: _topClients,
            naissances6Mois: _naissances6Mois,
          ),
          const SizedBox(height: 16),

          // ── Rapport mensuel PDF ──
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.calendar_view_month, color: AppTheme.primary),
                      SizedBox(width: 8),
                      Text('Rapport mensuel PDF',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'KPI du mois : saillies, naissances, ventes, soins, '
                    'reproduction, finances simplifiées.',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today),
                    title: Text('${_nomMoisFr(_moisChoisi.month)} ${_moisChoisi.year}'),
                    trailing: const Icon(Icons.edit),
                    onTap: _choisirMois,
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _busy ? null : _previsualiserMensuel,
                        icon: const Icon(Icons.visibility),
                        label: const Text('Aperçu'),
                      ),
                      ElevatedButton.icon(
                        onPressed: _busy ? null : _partagerMensuel,
                        icon: const Icon(Icons.share),
                        label: const Text('Partager / Imprimer'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accent),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── Bilan annuel PDF ──
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.bar_chart, color: AppTheme.primary),
                      SizedBox(width: 8),
                      Text('Bilan annuel PDF',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Récapitulatif complet de l\'année, avec détail mensuel '
                    'des ventes.',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.event),
                      const SizedBox(width: 16),
                      DropdownButton<int>(
                        value: _anneeChoisie,
                        items: List.generate(5,
                            (i) => DateTime.now().year - i)
                            .map((y) => DropdownMenuItem(
                                value: y, child: Text(y.toString())))
                            .toList(),
                        onChanged: (v) => setState(() => _anneeChoisie = v!),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _busy ? null : _previsualiserAnnuel,
                        icon: const Icon(Icons.visibility),
                        label: const Text('Aperçu'),
                      ),
                      ElevatedButton.icon(
                        onPressed: _busy ? null : _partagerAnnuel,
                        icon: const Icon(Icons.share),
                        label: const Text('Partager / Imprimer'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accent),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          if (_busy)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // PDF (existant)
  // ═══════════════════════════════════════════════════════════

  Future<void> _choisirMois() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _moisChoisi,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() => _moisChoisi = DateTime(date.year, date.month));
    }
  }

  Future<void> _previsualiserMensuel() async {
    setState(() => _busy = true);
    try {
      final bytes = await PdfService.instance.genererRapportMensuel(_moisChoisi);
      if (!mounted) return;
      await PdfService.instance.previsualiser(bytes,
          title: 'Rapport_${_moisChoisi.year}_${_moisChoisi.month}.pdf');
    } catch (e) {
      if (mounted) showErrorSnackBar(context, 'Une erreur est survenue. Réessaye.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _partagerMensuel() async {
    setState(() => _busy = true);
    try {
      final bytes = await PdfService.instance.genererRapportMensuel(_moisChoisi);
      final nom =
          'CuniGest_rapport_${_moisChoisi.year}_${_moisChoisi.month.toString().padLeft(2, '0')}.pdf';
      await PdfService.instance.sauvegarderEtPartager(bytes, nom);
      if (mounted) showSuccessSnackBar(context, 'Rapport généré');
    } catch (e) {
      if (mounted) showErrorSnackBar(context, 'Une erreur est survenue. Réessaye.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _previsualiserAnnuel() async {
    setState(() => _busy = true);
    try {
      final bytes = await PdfService.instance.genererBilanAnnuel(_anneeChoisie);
      if (!mounted) return;
      await PdfService.instance.previsualiser(bytes,
          title: 'Bilan_$_anneeChoisie.pdf');
    } catch (e) {
      if (mounted) showErrorSnackBar(context, 'Une erreur est survenue. Réessaye.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _partagerAnnuel() async {
    setState(() => _busy = true);
    try {
      final bytes = await PdfService.instance.genererBilanAnnuel(_anneeChoisie);
      final nom = 'CuniGest_bilan_$_anneeChoisie.pdf';
      await PdfService.instance.sauvegarderEtPartager(bytes, nom);
      if (mounted) showSuccessSnackBar(context, 'Bilan généré');
    } catch (e) {
      if (mounted) showErrorSnackBar(context, 'Une erreur est survenue. Réessaye.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

}

// ──────────────────────────────────────────────────────────────

class _MonthDashboard extends StatelessWidget {
  final bool loading;
  final double recettes;
  final double depenses;
  final List<Map<String, dynamic>> topClients;
  final Map<String, int> naissances6Mois;

  const _MonthDashboard({
    required this.loading,
    required this.recettes,
    required this.depenses,
    required this.topClients,
    required this.naissances6Mois,
  });

  @override
  Widget build(BuildContext context) {
    final marge = recettes - depenses;
    final margePositive = marge >= 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.dashboard, color: AppTheme.primary),
                const SizedBox(width: 8),
                const Text('Dashboard du mois',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                Text(
                  '${_nomMoisFr(DateTime.now().month)} ${DateTime.now().year}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (loading) ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: CircularProgressIndicator(),
                ),
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: _KpiBox(
                      label: 'Recettes',
                      valeur: formatMontant(recettes),
                      color: AppTheme.moduleFinance,
                      icon: Icons.trending_up,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _KpiBox(
                      label: 'Dépenses',
                      valeur: formatMontant(depenses),
                      color: AppTheme.moduleStock,
                      icon: Icons.trending_down,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _KpiBox(
                      label: 'Marge',
                      valeur: formatMontant(marge),
                      color: margePositive ? AppTheme.primary : AppTheme.error,
                      icon: margePositive ? Icons.check_circle : Icons.warning_amber,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('🥇 Top clients du mois',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 8),
              if (topClients.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Aucune vente avec acheteur ce mois.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                )
              else
                for (var i = 0; i < topClients.length; i++)
                  _TopClientRow(rang: i, client: topClients[i]),
              const SizedBox(height: 16),
              const Text('📈 Naissances — 6 derniers mois',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 8),
              SizedBox(
                height: 160,
                child: _ChartNaissances(naissances6Mois: naissances6Mois),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _KpiBox extends StatelessWidget {
  final String label;
  final String valeur;
  final Color color;
  final IconData icon;

  const _KpiBox({
    required this.label,
    required this.valeur,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 11, color: color, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              valeur,
              maxLines: 1,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopClientRow extends StatelessWidget {
  final int rang;
  final Map<String, dynamic> client;

  const _TopClientRow({required this.rang, required this.client});

  @override
  Widget build(BuildContext context) {
    const medailles = ['🥇', '🥈', '🥉'];
    final medaille = rang < medailles.length ? medailles[rang] : '${rang + 1}.';
    final nbVentes = client['nb_ventes'] as int;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(medaille, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              client['nom'] as String,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            '${formatMontant(client['total'] as double)} • $nbVentes vente${nbVentes > 1 ? "s" : ""}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

class _ChartNaissances extends StatelessWidget {
  final Map<String, int> naissances6Mois;

  const _ChartNaissances({required this.naissances6Mois});

  @override
  Widget build(BuildContext context) {
    if (naissances6Mois.isEmpty) {
      return Center(
        child: Text('Pas de données',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
      );
    }
    final entries = naissances6Mois.entries.toList();
    final spots = <FlSpot>[
      for (var i = 0; i < entries.length; i++)
        FlSpot(i.toDouble(), entries[i].value.toDouble()),
    ];
    final maxY =
        entries.map((e) => e.value).fold<int>(0, (a, b) => a > b ? a : b);
    final chartMax = (maxY == 0 ? 1 : maxY) * 1.25;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gridColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (entries.length - 1).toDouble(),
        minY: 0,
        maxY: chartMax.toDouble(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: gridColor, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (v, _) => Text(
                v.toInt().toString(),
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: 1,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= entries.length) return const SizedBox();
                final mois = int.parse(entries[i].key.split('-')[1]);
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(_nomMoisFrCourt(mois),
                      style: TextStyle(
                          fontSize: 10, color: Colors.grey.shade600)),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.25,
            color: AppTheme.primary,
            barWidth: 2.5,
            dotData: FlDotData(
              show: true,
              getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                radius: 3,
                color: AppTheme.primary,
                strokeWidth: 2,
                strokeColor: isDark ? Colors.black : Colors.white,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: AppTheme.primary.withValues(alpha: 0.18),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────

String _nomMoisFr(int m) {
  const moisFr = [
    '',
    'Janvier',
    'Février',
    'Mars',
    'Avril',
    'Mai',
    'Juin',
    'Juillet',
    'Août',
    'Septembre',
    'Octobre',
    'Novembre',
    'Décembre',
  ];
  return moisFr[m];
}

String _nomMoisFrCourt(int m) {
  const c = [
    '',
    'Jan',
    'Fév',
    'Mar',
    'Avr',
    'Mai',
    'Juin',
    'Juil',
    'Août',
    'Sep',
    'Oct',
    'Nov',
    'Déc',
  ];
  return c[m];
}
