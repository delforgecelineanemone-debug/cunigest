// ──────────────────────────────────────────────────────────────
// Écran : Détail d'un lot d'engraissement
// ──────────────────────────────────────────────────────────────
// Vue principale du lot :
// - KPI : nombre, jours d'élevage, GMQ, IC, aliment total
// - Historique des pesées (avec courbe simple)
// - Historique des distributions d'aliment
// - Actions : ajouter pesée, distribuer aliment, terminer lot
// ──────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../../database/db_helper.dart';
import '../../models/lot.dart';
import '../../utils/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/growth_chart.dart';
import 'lot_form_screen.dart';
import 'lot_individualisation_screen.dart';
import '../../ui/cu_ui.dart';

class LotDetailScreen extends StatefulWidget {
  final Lot lot;
  const LotDetailScreen({super.key, required this.lot});

  @override
  State<LotDetailScreen> createState() => _LotDetailScreenState();
}

class _LotDetailScreenState extends State<LotDetailScreen> {
  late Lot _lot;
  LotStats? _stats;
  List<Pesee> _pesees = [];
  List<DistributionAliment> _distributions = [];
  bool _loading = true;

  // V2.5 — Rentabilité (Phase 4)
  double _depensesLot = 0;
  double _ventesLot = 0;

  @override
  void initState() {
    super.initState();
    _lot = widget.lot;
    _load();
  }

  Future<void> _load() async {
    final id = _lot.id!;
    final (repo, depRepo, venteRepo) = await (
      DBHelper.instance.lots,
      DBHelper.instance.depenses,
      DBHelper.instance.ventes,
    ).wait;

    final (fresh, stats, pesees, distributions, dep, v) = await (
      repo.getById(id),
      repo.getStats(id),
      repo.getPeseesByLot(id),
      repo.getDistributionsByLot(id),
      depRepo.totalParLot(id),
      venteRepo.totalParLot(id),
    ).wait;

    if (mounted) {
      setState(() {
        if (fresh != null) _lot = fresh;
        _stats = stats;
        _pesees = pesees;
        _distributions = distributions;
        _depensesLot = dep;
        _ventesLot = v;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CuAppBar(
        title: _lot.code,
        showActions: false,
        extraActions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final r = await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => LotFormScreen(lot: _lot)));
              if (r == true) _load();
            },
          ),
          if (_lot.statut == 'en_cours' && _lot.saillieId != null)
            IconButton(
              icon: const Icon(Icons.label_outline),
              tooltip: 'Individualiser le lot',
              onPressed: _individualiser,
            ),
          if (_lot.statut == 'en_cours')
            IconButton(
              icon: const Icon(Icons.check_circle_outline),
              tooltip: 'Terminer le lot',
              onPressed: _terminerLot,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _kpiSection(),
                  const SizedBox(height: 20),
                  _rentabiliteSection(),
                  const SizedBox(height: 20),
                  _peseesSection(),
                  const SizedBox(height: 20),
                  _distributionsSection(),
                  const SizedBox(height: 80),
                ],
              ),
            ),
      floatingActionButton: _lot.statut == 'en_cours'
          ? FloatingActionButton.extended(
              onPressed: _menuAction,
              icon: const Icon(Icons.add),
              label: const Text('Ajouter'),
            )
          : null,
    );
  }

  Widget _kpiSection() => _LotKpiCard(lot: _lot, stats: _stats!);
  Widget _rentabiliteSection() => _LotRentabiliteCard(
      lot: _lot, depenses: _depensesLot, ventes: _ventesLot);

  Widget _peseesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('⚖️ Pesées',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const Spacer(),
                if (_lot.statut == 'en_cours')
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Pesée'),
                    onPressed: _ajouterPesee,
                  ),
              ],
            ),
            if (_pesees.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                    child: Text('Aucune pesée enregistrée',
                        style: TextStyle(color: Colors.grey))),
              )
            else ...[
              if (_pesees.length >= 2) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: GrowthChart(
                    title: '📈 Poids moyen par lapin',
                    unit: 'kg',
                    points: [
                      for (final p in _pesees)
                        (DateTime.parse(p.datePesee), p.poidsMoyen),
                    ]..sort((a, b) => a.$1.compareTo(b.$1)),
                  ),
                ),
                const Divider(height: 12),
              ],
              ..._pesees.reversed.map((p) => ListTile(
                    leading: const Icon(Icons.scale, color: AppTheme.primary),
                    title: Text(
                        '${p.poidsTotal.toStringAsFixed(2)} kg pour ${p.nombre} lap.'),
                    subtitle: Text(
                        '${formatDate(p.datePesee)} — ${p.poidsMoyen.toStringAsFixed(2)} kg/lap'),
                    trailing: _lot.statut == 'en_cours'
                        ? IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red),
                            onPressed: () => _supprimerPesee(p),
                          )
                        : null,
                  )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _distributionsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('🌾 Distributions d\'aliment',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const Spacer(),
                if (_lot.statut == 'en_cours')
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Aliment'),
                    onPressed: _ajouterDistribution,
                  ),
              ],
            ),
            if (_distributions.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                    child: Text('Aucune distribution',
                        style: TextStyle(color: Colors.grey))),
              )
            else
              ..._distributions.reversed.map((d) => ListTile(
                    leading: const Icon(Icons.eco, color: Colors.brown),
                    title: Text('${d.quantiteKg.toStringAsFixed(2)} kg'),
                    subtitle: Text(formatDate(d.dateDistribution)),
                    trailing: _lot.statut == 'en_cours'
                        ? IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red),
                            onPressed: () => _supprimerDistribution(d),
                          )
                        : null,
                  )),
          ],
        ),
      ),
    );
  }

  void _menuAction() {
    showModalBottomSheet(
      context: context,
      builder: (_) => Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.scale, color: AppTheme.primary),
            title: const Text('Nouvelle pesée'),
            onTap: () {
              Navigator.pop(context);
              _ajouterPesee();
            },
          ),
          ListTile(
            leading: const Icon(Icons.eco, color: Colors.brown),
            title: const Text('Distribuer de l\'aliment'),
            onTap: () {
              Navigator.pop(context);
              _ajouterDistribution();
            },
          ),
          ListTile(
            leading: const Icon(Icons.check_circle, color: Colors.green),
            title: const Text('Terminer le lot'),
            onTap: () {
              Navigator.pop(context);
              _terminerLot();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _ajouterPesee() async {
    final poidsCtrl = TextEditingController();
    final nombreCtrl = TextEditingController(text: _stats?.nombreActuel.toString() ?? '');
    String date = DateTime.now().toIso8601String().substring(0, 10);

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setD) => AlertDialog(
          title: const Text('Nouvelle pesée'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () async {
                  final p = await showDatePicker(
                      context: context,
                      initialDate: DateTime.parse(date),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now());
                  if (p != null) setD(() => date = p.toIso8601String().substring(0, 10));
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                      labelText: 'Date',
                      prefixIcon: Icon(Icons.calendar_today)),
                  child: Text(formatDate(date)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: poidsCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Poids total (kg) *', suffixText: 'kg'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nombreCtrl,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Nombre pesés *'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler')),
            ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Enregistrer')),
          ],
        ),
      ),
    );

    if (ok != true) return;
    final poids = double.tryParse(poidsCtrl.text);
    final nb = int.tryParse(nombreCtrl.text);
    if (poids == null || nb == null) {
      if (mounted) showErrorSnackBar(context, 'Valeurs invalides');
      return;
    }
    final repo = await DBHelper.instance.lots;
    await repo.insertPesee(Pesee(
      lotId: _lot.id!,
      datePesee: date,
      poidsTotal: poids,
      nombre: nb,
    ));
    _load();
  }

  Future<void> _ajouterDistribution() async {
    final qteCtrl = TextEditingController();
    String date = DateTime.now().toIso8601String().substring(0, 10);

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setD) => AlertDialog(
          title: const Text('Distribuer de l\'aliment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () async {
                  final p = await showDatePicker(
                      context: context,
                      initialDate: DateTime.parse(date),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now());
                  if (p != null) setD(() => date = p.toIso8601String().substring(0, 10));
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                      labelText: 'Date',
                      prefixIcon: Icon(Icons.calendar_today)),
                  child: Text(formatDate(date)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: qteCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Quantité (kg) *', suffixText: 'kg'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler')),
            ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Enregistrer')),
          ],
        ),
      ),
    );

    if (ok != true) return;
    final qte = double.tryParse(qteCtrl.text);
    if (qte == null || qte <= 0) {
      if (mounted) showErrorSnackBar(context, 'Quantité invalide');
      return;
    }
    final repo = await DBHelper.instance.lots;
    await repo.insertDistribution(DistributionAliment(
      lotId: _lot.id!,
      dateDistribution: date,
      quantiteKg: qte,
    ));
    _load();
  }

  Future<void> _supprimerPesee(Pesee p) async {
    final ok = await showConfirmDialog(context,
        title: 'Supprimer cette pesée ?',
        message: 'Le calcul du GMQ sera affecté.',
        confirmColor: AppTheme.error);
    if (!ok) return;
    final repo = await DBHelper.instance.lots;
    await repo.deletePesee(p.id!);
    _load();
  }

  Future<void> _supprimerDistribution(DistributionAliment d) async {
    final ok = await showConfirmDialog(context,
        title: 'Supprimer cette distribution ?',
        message: 'Le calcul de l\'IC sera affecté.',
        confirmColor: AppTheme.error);
    if (!ok) return;
    final repo = await DBHelper.instance.lots;
    await repo.deleteDistribution(d.id!);
    _load();
  }

  Future<void> _terminerLot() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Terminer le lot ?',
      message:
          'Le lot ne pourra plus recevoir de pesées ni de distributions. Cette action est réversible (modifier le statut dans le formulaire).',
      confirmLabel: 'Terminer',
      cancelLabel: 'Annuler',
    );
    if (!ok) return;
    final repo = await DBHelper.instance.lots;
    await repo.terminer(_lot.id!, DateTime.now().toIso8601String().substring(0, 10));
    _load();
  }

  Future<void> _individualiser() async {
    final r = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => LotIndividualisationScreen(lot: _lot)),
    );
    if (r == true) _load();
  }
}

// ─────────────────────────────────────────────
// Widgets privés
// ─────────────────────────────────────────────

class _LotKpiCard extends StatelessWidget {
  const _LotKpiCard({required this.lot, required this.stats});
  final Lot lot;
  final LotStats stats;

  static Color _couleurGmq(double gmq) {
    if (gmq >= 35) return Colors.green;
    if (gmq >= 25) return Colors.orange;
    return Colors.red;
  }

  static Color _couleurIc(double ic) {
    if (ic <= 3.5) return Colors.green;
    if (ic <= 4.0) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final s = stats;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('📊 Indicateurs',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                Text(
                    lot.statut == 'termine'
                        ? '✅ Terminé'
                        : lot.statut == 'individualise'
                            ? '🏷️ Individualisé'
                            : '🟢 En cours',
                    style: TextStyle(
                        color: lot.statut == 'termine'
                            ? Colors.grey
                            : lot.statut == 'individualise'
                                ? AppTheme.moduleRepro
                                : Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(),
            Row(children: [
              _Kpi('🐇 Lapereaux', '${s.nombreActuel} / ${lot.nombreInitial}', null),
              _Kpi('⏱️ Jours', '${s.joursElevage}', null),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              _Kpi('📈 GMQ',
                s.gmq != null ? '${s.gmq!.toStringAsFixed(0)} g/j' : '— Pesée requise',
                s.gmq != null ? _couleurGmq(s.gmq!) : null),
              _Kpi('🌾 IC',
                s.ic != null ? s.ic!.toStringAsFixed(2) : '— Aliment requis',
                s.ic != null ? _couleurIc(s.ic!) : null),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              _Kpi('🌾 Aliment total', '${s.alimentTotalKg.toStringAsFixed(1)} kg', null),
              _Kpi('⚖️ Poids actuel',
                s.poidsActuel != null ? '${s.poidsActuel!.toStringAsFixed(1)} kg' : '—', null),
            ]),
            if (lot.poidsInitial != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Poids initial : ${lot.poidsInitial!.toStringAsFixed(1)} kg',
                    style: TextStyle(fontSize: 12, color: context.cuTextSecondary)),
              ),
          ],
        ),
      ),
    );
  }
}

class _LotRentabiliteCard extends StatelessWidget {
  const _LotRentabiliteCard(
      {required this.lot, required this.depenses, required this.ventes});
  final Lot lot;
  final double depenses;
  final double ventes;

  @override
  Widget build(BuildContext context) {
    final marge = ventes - depenses;
    final positif = marge >= 0;
    final aucuneDonnee = ventes == 0 && depenses == 0;
    final couleur = positif ? AppTheme.primary : AppTheme.error;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.account_balance_wallet, color: AppTheme.moduleFinance),
              SizedBox(width: 8),
              Text('💰 Rentabilité du lot',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ]),
            const SizedBox(height: 12),
            if (aucuneDonnee)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  'Aucune dépense ou vente n\'est imputée à ce lot. '
                  'Va dans Dépenses / Ventes et coche "Imputer au lot ${lot.code}".',
                  style: TextStyle(fontSize: 12, color: context.cuTextSecondary),
                ),
              )
            else ...[
              Row(children: [
                Expanded(child: _RentaTile('Recettes', formatMontant(ventes),
                    AppTheme.moduleFinance, Icons.trending_up)),
                const SizedBox(width: 8),
                Expanded(child: _RentaTile('Dépenses', formatMontant(depenses),
                    AppTheme.moduleStock, Icons.trending_down)),
              ]),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: couleur.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: couleur.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Icon(positif ? Icons.check_circle : Icons.warning_amber,
                        color: couleur, size: 18),
                    const SizedBox(width: 8),
                    const Text('Marge nette',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    const Spacer(),
                    Text(formatMontant(marge),
                        style: TextStyle(fontSize: 16,
                            fontWeight: FontWeight.bold, color: couleur)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: context.cuTextSecondary)),
            Text(value, style: TextStyle(fontSize: 16,
                fontWeight: FontWeight.bold, color: color ?? Colors.black87)),
          ],
        ),
      ),
    );
  }
}

class _RentaTile extends StatelessWidget {
  const _RentaTile(this.label, this.valeur, this.color, this.icon);
  final String label;
  final String valeur;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
          ]),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
            child: Text(valeur, maxLines: 1,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
          ),
        ],
      ),
    );
  }
}
