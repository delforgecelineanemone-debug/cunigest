// ──────────────────────────────────────────────────────────────
// Écran : Fiche détaillée d'un lapin
// ──────────────────────────────────────────────────────────────

import 'dart:io';

import 'package:flutter/material.dart';
import '../../database/db_helper.dart';
import '../../models/batiment.dart';
import '../../models/cage.dart';
import '../../models/clapier.dart';
import '../../models/lapin.dart';
import '../../models/mouvement_cage.dart';
import '../../models/pesee_lapin.dart';
import '../../models/saillie.dart';
import '../../models/soin.dart';
import '../../services/pdf_service.dart';
import '../../utils/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/growth_chart.dart';
import '../cages/cage_detail_screen.dart';
import '../sante/soin_form_screen.dart';
import '../qr/qr_display_screen.dart';
import 'lapin_form_screen.dart';

class LapinDetailScreen extends StatefulWidget {
  final Lapin lapin;
  const LapinDetailScreen({super.key, required this.lapin});

  @override
  State<LapinDetailScreen> createState() => _LapinDetailScreenState();
}

class _LapinDetailScreenState extends State<LapinDetailScreen> {
  final db = DBHelper.instance;
  late Lapin lapin;
  List<Soin> _soins = [];
  Lapin? _pere;
  Lapin? _mere;
  Soin? _delaiActif;
  Cage? _cage;
  Clapier? _clapier;
  Batiment? _batiment;
  List<MouvementCage> _mvts = [];
  List<PeseeLapin> _pesees = [];
  List<_TimelineEvent> _timeline = [];
  double _depensesLapin = 0;
  double _ventesLapin = 0;

  @override
  void initState() {
    super.initState();
    lapin = widget.lapin;
    _load();
  }

  Future<void> _load() async {
    final id = lapin.id!;

    // Stage 1 — tout ce qui est indépendant du contenu du lapin
    final (fresh, soins, delai, cagesRepo, peseesRepo, depRepo, venteRepo) =
        await (
      db.getLapinById(id),
      db.getSoinsByLapin(id),
      db.getSoinDelaiAttenteActif(id),
      db.cages,
      db.peseesLapin,
      db.depenses,
      db.ventes,
    ).wait;

    // Stage 2 — chaîne cage (séquentielle interne) et le reste en parallèle
    Future<(Cage?, Clapier?, Batiment?)> cageChain() async {
      if (fresh?.cageId == null) return (null, null, null);
      final cage = await cagesRepo.getCageById(fresh!.cageId!);
      if (cage == null) return (null, null, null);
      final clapier = await cagesRepo.getClapierById(cage.clapierId);
      if (clapier == null) return (cage, null, null);
      final batiment = await cagesRepo.getBatimentById(clapier.batimentId);
      return (cage, clapier, batiment);
    }

    final (cageData, pere, mere, mvts, pesees, saillies, depTotal, venteTotal) =
        await (
      cageChain(),
      fresh?.pereId != null
          ? db.getLapinById(fresh!.pereId!)
          : Future<Lapin?>.value(null),
      fresh?.mereId != null
          ? db.getLapinById(fresh!.mereId!)
          : Future<Lapin?>.value(null),
      cagesRepo.getHistoriqueLapin(id),
      peseesRepo.getByLapin(id),
      (fresh?.sexe ?? lapin.sexe) == 'femelle'
          ? db.getSailliesByMere(id)
          : db.getSailliesByPere(id),
      depRepo.totalParLapin(id),
      venteRepo.totalParLapin(id),
    ).wait;

    final (cage, clapier, batiment) = cageData;

    final timeline = _construireTimeline(
      lapinFrais: fresh ?? lapin,
      soins: soins,
      pesees: pesees,
      mvts: mvts,
      saillies: saillies,
    );

    if (mounted) {
      setState(() {
        if (fresh != null) lapin = fresh;
        _soins = soins;
        _pere = pere;
        _mere = mere;
        _delaiActif = delai;
        _cage = cage;
        _clapier = clapier;
        _batiment = batiment;
        _mvts = mvts;
        _pesees = pesees;
        _timeline = timeline;
        _depensesLapin = depTotal;
        _ventesLapin = venteTotal;
      });
    }
  }

  List<_TimelineEvent> _construireTimeline({
    required Lapin lapinFrais,
    required List<Soin> soins,
    required List<PeseeLapin> pesees,
    required List<MouvementCage> mvts,
    required List<Saillie> saillies,
  }) {
    final events = <_TimelineEvent>[];

    if (lapinFrais.dateNaissance != null) {
      final d = DateTime.tryParse(lapinFrais.dateNaissance!);
      if (d != null) {
        events.add(_TimelineEvent(date: d, icon: Icons.cake,
            color: Colors.pink.shade300, title: 'Naissance',
            subtitle: lapinFrais.race ?? ''));
      }
    }

    for (final p in pesees) {
      final d = DateTime.tryParse(p.datePesee);
      if (d == null) continue;
      events.add(_TimelineEvent(date: d, icon: Icons.scale,
          color: AppTheme.primary,
          title: 'Pesée — ${p.poids.toStringAsFixed(2)} kg',
          subtitle: p.notes ?? ''));
    }

    for (final s in soins) {
      final d = DateTime.tryParse(s.dateSoin);
      if (d == null) continue;
      events.add(_TimelineEvent(date: d, icon: Icons.health_and_safety,
          color: Colors.blue, title: s.typeSoin, subtitle: s.produit ?? ''));
    }

    for (final m in mvts) {
      final d = DateTime.tryParse(m.date);
      if (d == null) continue;
      final isSortie = m.cageDestinationId == null;
      events.add(_TimelineEvent(
        date: d,
        icon: isSortie ? Icons.logout : Icons.move_to_inbox,
        color: isSortie ? Colors.orange : Colors.teal,
        title: isSortie ? 'Sortie de cage'
            : (m.cageOrigineId == null ? 'Premier placement' : 'Déplacement de cage'),
        subtitle: m.motif ?? '',
      ));
    }

    final estFemelle = lapinFrais.sexe == 'femelle';
    for (final s in saillies) {
      final dSaillie = DateTime.tryParse(s.dateSaillie);
      if (dSaillie != null) {
        events.add(_TimelineEvent(date: dSaillie, icon: Icons.favorite,
            color: const Color(0xFF7F77DD),
            title: estFemelle ? 'Saillie' : 'Saillie (père)',
            subtitle: s.statutLabel));
      }

      if (!estFemelle) continue;

      if (s.dateMiseBasReelle != null) {
        final d = DateTime.tryParse(s.dateMiseBasReelle!);
        if (d != null) {
          final nb = s.nbVivants;
          events.add(_TimelineEvent(
            date: d, icon: Icons.child_care, color: Colors.purple,
            title: 'Mise bas${nb != null ? " — $nb vivants" : ""}',
            subtitle: s.nbMorts != null && s.nbMorts! > 0 ? '${s.nbMorts} mort-né(s)' : '',
          ));
        }
      }

      if (s.dateSevrage != null) {
        final d = DateTime.tryParse(s.dateSevrage!);
        if (d != null) {
          events.add(_TimelineEvent(
            date: d, icon: Icons.free_breakfast, color: Colors.brown,
            title: 'Sevrage',
            subtitle: s.nbSevres != null ? '${s.nbSevres} sevrés' : '',
          ));
        }
      }
    }

    events.sort((a, b) => b.date.compareTo(a.date));
    return events;
  }

  Future<void> _ajouterPesee() async {
    final ctrl = TextEditingController(text: lapin.poids?.toStringAsFixed(2) ?? '');
    final notesCtrl = TextEditingController();
    DateTime selDate = DateTime.now();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (_, setSt) => AlertDialog(
          title: const Text('Nouvelle pesée'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Poids (kg)', prefixIcon: Icon(Icons.scale)),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: Text('${selDate.day}/${selDate.month}/${selDate.year}'),
                onTap: () async {
                  final d = await showDatePicker(context: ctx,
                      initialDate: selDate, firstDate: DateTime(2020),
                      lastDate: DateTime.now());
                  if (d != null) setSt(() => selDate = d);
                },
              ),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(labelText: 'Notes (optionnel)'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enregistrer')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final poids = double.tryParse(ctrl.text.replaceAll(',', '.'));
    if (poids == null || poids <= 0) {
      if (mounted) showErrorSnackBar(context, 'Poids invalide');
      return;
    }
    final repo = await db.peseesLapin;
    await repo.insert(PeseeLapin(
      lapinId: lapin.id!, datePesee: selDate.toIso8601String().substring(0, 10),
      poids: poids, notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
    ));
    await _load();
  }

  Future<void> _supprimerPesee(PeseeLapin p) async {
    final ok = await showConfirmDialog(context,
        title: 'Supprimer cette pesée ?',
        message: '${p.poids} kg le ${formatDate(p.datePesee)}');
    if (!ok) return;
    final repo = await db.peseesLapin;
    await repo.delete(p.id!);
    await _load();
  }

  Future<void> _genererPedigree() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final pdf = await PdfService.instance.genererPedigreePDF(lapin);
      await PdfService.instance.previsualiser(pdf);
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(
          content: Text('Génération PDF impossible. Réessaye.'),
          backgroundColor: AppTheme.error));
    }
  }

  Future<void> _confirmerSuppression() async {
    final ok = await showConfirmDialog(context,
        title: 'Supprimer ce lapin ?',
        message: 'Êtes-vous sûr de vouloir supprimer ${lapin.displayName} ? Cette action est irréversible.',
        confirmColor: AppTheme.error);
    if (ok && mounted) {
      try {
        await db.deleteLapin(lapin.id!);
        if (mounted) Navigator.pop(context, true);
      } catch (_) {
        if (mounted) showErrorSnackBar(context, 'Suppression impossible.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = lapin.sexe == 'male' ? Colors.blue : Colors.pink;
    return Scaffold(
      appBar: AppBar(
        title: Text(lapin.displayName),
        actions: [
          IconButton(icon: const Icon(Icons.qr_code), tooltip: 'QR code',
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => QrDisplayScreen(lapin: lapin)))),
          IconButton(icon: const Icon(Icons.account_tree), tooltip: 'Pedigree PDF (4 gén.)',
              onPressed: _genererPedigree),
          IconButton(icon: const Icon(Icons.edit),
              onPressed: () async {
                final r = await Navigator.push(context,
                    MaterialPageRoute(builder: (_) => LapinFormScreen(lapin: lapin)));
                if (r == true) _load();
              }),
          IconButton(icon: const Icon(Icons.delete_outline),
              onPressed: _confirmerSuppression),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _LapinHeaderCard(lapin: lapin, color: color),
          if (_delaiActif != null) ...[
            const SizedBox(height: 12),
            _DelaiAttenteBanner(delai: _delaiActif!),
          ],
          const SizedBox(height: 12),
          _InfoCard(lapin: lapin, cage: _cage, clapier: _clapier,
              batiment: _batiment, onCageTap: () async {
                await Navigator.push(context,
                    MaterialPageRoute(builder: (_) => CageDetailScreen(cageId: _cage!.id!)));
                _load();
              }),
          const SizedBox(height: 12),
          if (_timeline.isNotEmpty) ...[
            _TimelineCard(events: _timeline),
            const SizedBox(height: 12),
          ],
          _GenealogieCard(pere: _pere, mere: _mere,
              onNavigate: (parent) async {
                await Navigator.push(context,
                    MaterialPageRoute(builder: (_) => LapinDetailScreen(lapin: parent)));
                _load();
              }),
          const SizedBox(height: 12),
          _PeseesCard(pesees: _pesees,
              onAjouter: _ajouterPesee,
              onSupprimer: _supprimerPesee),
          const SizedBox(height: 12),
          _RentabiliteCard(lapin: lapin, soins: _soins,
              depenses: _depensesLapin, ventes: _ventesLapin),
          const SizedBox(height: 12),
          if (_mvts.isNotEmpty) ...[
            _HistoriqueCagesSection(mvts: _mvts),
            const SizedBox(height: 12),
          ],
          _SoinsSection(soins: _soins, lapin: lapin, onRefresh: _load),
          const SizedBox(height: 80),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(context,
              MaterialPageRoute(builder: (_) => SoinFormScreen(lapinPreselect: lapin)));
          _load();
        },
        icon: const Icon(Icons.health_and_safety),
        label: const Text('Ajouter un soin'),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Widgets privés — sections de la fiche lapin
// ─────────────────────────────────────────────

class _LapinHeaderCard extends StatelessWidget {
  const _LapinHeaderCard({required this.lapin, required this.color});
  final Lapin lapin;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = lapin.photoPath != null && File(lapin.photoPath!).existsSync();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Hero(
              tag: 'lapin_${lapin.id}',
              child: CircleAvatar(
                radius: 36,
                backgroundColor: hasPhoto ? null : color.withValues(alpha: 0.15),
                backgroundImage: hasPhoto ? FileImage(File(lapin.photoPath!)) : null,
                child: hasPhoto ? null : Text(
                  lapin.sexe == 'male' ? '♂' : '♀',
                  style: TextStyle(fontSize: 36, color: color),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lapin.displayName,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Text(lapin.numeroBague,
                      style: TextStyle(color: Colors.grey.shade600)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 8, runSpacing: 4, children: [
                    _Badge(label: lapin.statutLabel, color: statutColor(lapin.statut)),
                    _Badge(label: lapin.sexeLabel, color: color),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DelaiAttenteBanner extends StatelessWidget {
  const _DelaiAttenteBanner({required this.delai});
  final Soin delai;

  @override
  Widget build(BuildContext context) {
    final fin = delai.finDelaiAttente;
    final finStr = fin != null ? formatDate(fin.toIso8601String().substring(0, 10)) : '?';
    final restant = fin != null ? fin.difference(DateTime.now()).inDays : 0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.medication_liquid, color: Colors.orange),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('⏱️ Délai d\'attente médicament en cours',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                Text("Jusqu'au $finStr (${restant > 0 ? '$restant jours restants' : "expire aujourd'hui"})"),
                Text('Soin : ${delai.typeSoin} le ${formatDate(delai.dateSoin)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 4),
                const Text('Vente pour consommation INTERDITE pendant ce délai.',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.red)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.lapin, this.cage, this.clapier, this.batiment,
    required this.onCageTap,
  });
  final Lapin lapin;
  final Cage? cage;
  final Clapier? clapier;
  final Batiment? batiment;
  final VoidCallback onCageTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Informations',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const Divider(),
            _InfoRow(icon: Icons.category, label: 'Race', value: lapin.race ?? 'Non renseigné'),
            _InfoRow(icon: Icons.palette, label: 'Couleur', value: lapin.couleur ?? 'Non renseigné'),
            _buildCageRow(context),
            _InfoRow(icon: Icons.monitor_weight, label: 'Poids',
                value: lapin.poids != null ? '${lapin.poids!.toStringAsFixed(2)} kg' : 'Non renseigné'),
            _InfoRow(icon: Icons.cake, label: 'Naissance',
                value: lapin.dateNaissance != null ? formatDate(lapin.dateNaissance) : 'Non renseigné'),
            _InfoRow(icon: Icons.access_time, label: 'Âge', value: lapin.ageDisplay),
            if (lapin.notes != null) ...[
              const Divider(),
              _InfoRow(icon: Icons.notes, label: 'Notes', value: lapin.notes!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCageRow(BuildContext context) {
    if (cage != null) {
      final color = cageStatutColor(cage!.statut);
      return InkWell(
        onTap: onCageTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Icon(cageStatutIcon(cage!.statut), size: 18, color: color),
              const SizedBox(width: 10),
              Text('Cage : ', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              Expanded(
                child: Text(
                  '${cage!.numero} (${batiment?.nom ?? "?"} • ${clapier?.nom ?? "?"})',
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13,
                      color: color, decoration: TextDecoration.underline),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
            ],
          ),
        ),
      );
    }
    return _InfoRow(
      icon: Icons.grid_view, label: 'Cage',
      value: lapin.cageLegacy != null && lapin.cageLegacy!.isNotEmpty
          ? '${lapin.cageLegacy} (texte libre — non liée)'
          : 'Aucune cage assignée',
    );
  }
}

class _GenealogieCard extends StatelessWidget {
  const _GenealogieCard({this.pere, this.mere, required this.onNavigate});
  final Lapin? pere;
  final Lapin? mere;
  final void Function(Lapin) onNavigate;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🌳 Généalogie',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const Divider(),
            _parentRow(context, 'Père', pere, Colors.blue, Icons.male),
            _parentRow(context, 'Mère', mere, Colors.pink, Icons.female),
          ],
        ),
      ),
    );
  }

  Widget _parentRow(BuildContext ctx, String label, Lapin? parent, Color color, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Text('$label : ', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          Expanded(
            child: parent != null
                ? InkWell(
                    onTap: () => onNavigate(parent),
                    child: Text(
                      '${parent.displayName} (${parent.numeroBague})',
                      style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13,
                          color: color, decoration: TextDecoration.underline),
                    ),
                  )
                : const Text('Inconnu',
                    style: TextStyle(fontStyle: FontStyle.italic, fontSize: 13, color: Colors.grey)),
          ),
        ],
      ),
    );
  }
}

class _PeseesCard extends StatelessWidget {
  const _PeseesCard({
    required this.pesees, required this.onAjouter, required this.onSupprimer,
  });
  final List<PeseeLapin> pesees;
  final VoidCallback onAjouter;
  final void Function(PeseeLapin) onSupprimer;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('⚖️ Pesées',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Pesée'),
                  onPressed: onAjouter,
                ),
              ],
            ),
            if (pesees.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                    child: Text('Aucune pesée enregistrée pour ce lapin.',
                        style: TextStyle(color: Colors.grey))),
              )
            else ...[
              if (pesees.length >= 2) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: GrowthChart(
                    title: '📈 Croissance', unit: 'kg',
                    points: [for (final p in pesees) (DateTime.parse(p.datePesee), p.poids)],
                  ),
                ),
                const Divider(height: 12),
              ],
              ...pesees.reversed.take(5).map((p) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.scale, color: AppTheme.primary),
                    title: Text('${p.poids.toStringAsFixed(2)} kg'),
                    subtitle: Text(formatDate(p.datePesee)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => onSupprimer(p),
                    ),
                  )),
              if (pesees.length > 5)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 8),
                  child: Text('+ ${pesees.length - 5} pesée(s) plus anciennes',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RentabiliteCard extends StatelessWidget {
  const _RentabiliteCard({
    required this.lapin, required this.soins,
    required this.depenses, required this.ventes,
  });
  final Lapin lapin;
  final List<Soin> soins;
  final double depenses;
  final double ventes;

  @override
  Widget build(BuildContext context) {
    final coutSoins = soins.fold<double>(0, (s, x) => s + (x.cout ?? 0));
    final prixAchat = lapin.prixAchat ?? 0.0;
    final coutTotal = prixAchat + coutSoins + depenses;
    final marge = ventes - coutTotal;
    final aucuneDonnee = coutTotal == 0 && ventes == 0;
    final positif = marge >= 0;
    final couleur = positif ? AppTheme.primary : AppTheme.error;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.account_balance_wallet, color: AppTheme.moduleFinance),
              SizedBox(width: 8),
              Text('💰 Rentabilité', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ]),
            const SizedBox(height: 10),
            if (aucuneDonnee)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  'Aucun coût ni vente enregistré pour ce lapin. Renseigne le prix d\'achat (formulaire) ou impute des dépenses pour voir la rentabilité.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              )
            else ...[
              _Ligne('Prix d\'achat', prixAchat, prixAchat > 0 ? null : Colors.grey.shade500),
              _Ligne('Coût des soins', coutSoins, coutSoins > 0 ? null : Colors.grey.shade500),
              _Ligne('Dépenses imputées', depenses, depenses > 0 ? null : Colors.grey.shade500),
              const Divider(height: 16),
              _Ligne('Coût total', coutTotal, AppTheme.moduleStock, bold: true),
              _Ligne('Recettes', ventes, AppTheme.moduleFinance, bold: true),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: couleur.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: couleur.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Icon(positif ? Icons.check_circle : Icons.warning_amber,
                        size: 16, color: couleur),
                    const SizedBox(width: 8),
                    const Text('Marge nette',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    const Spacer(),
                    Text(formatMontant(marge),
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: couleur)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _Ligne(String label, double valeur, Color? color, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(fontSize: 12, color: color ?? Colors.black87,
                    fontWeight: bold ? FontWeight.w600 : FontWeight.normal)),
          ),
          Text(formatMontant(valeur),
              style: TextStyle(fontSize: 13,
                  fontWeight: bold ? FontWeight.bold : FontWeight.w500, color: color)),
        ],
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.events});
  final List<_TimelineEvent> events;

  static const _maxItems = 15;

  @override
  Widget build(BuildContext context) {
    final items = events.take(_maxItems).toList();
    final reste = events.length - items.length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('📅 Historique',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            for (var i = 0; i < items.length; i++)
              _buildRow(items[i], isLast: i == items.length - 1 && reste == 0),
            if (reste > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 30),
                child: Text(
                  '+ $reste événement${reste > 1 ? "s" : ""} plus ancien${reste > 1 ? "s" : ""}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(_TimelineEvent e, {required bool isLast}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: e.color.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: Icon(e.icon, size: 14, color: e.color),
              ),
              if (!isLast)
                Expanded(child: Container(
                    width: 1, color: Colors.grey.withValues(alpha: 0.25))),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.title,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  if (e.subtitle.isNotEmpty)
                    Text(e.subtitle,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  Text(formatDate(e.date.toIso8601String().substring(0, 10)),
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoriqueCagesSection extends StatelessWidget {
  const _HistoriqueCagesSection({required this.mvts});
  final List<MouvementCage> mvts;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('📜 Historique des cages',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 6),
        ...mvts.take(10).map((m) {
          final isSortie = m.cageDestinationId == null;
          return Card(
            margin: const EdgeInsets.only(bottom: 4),
            child: ListTile(
              dense: true,
              leading: Icon(isSortie ? Icons.logout : Icons.move_to_inbox,
                  color: isSortie ? Colors.orange : AppTheme.primary, size: 20),
              title: Text(
                isSortie ? 'Sortie de cage'
                    : (m.cageOrigineId == null ? 'Premier placement' : 'Déplacement entre cages'),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                '${formatDate(m.date)}${m.motif != null ? " • ${m.motif}" : ""}',
                style: const TextStyle(fontSize: 11),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _SoinsSection extends StatelessWidget {
  const _SoinsSection({
    required this.soins, required this.lapin, required this.onRefresh,
  });
  final List<Soin> soins;
  final Lapin lapin;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('🏥 Soins & Vaccinations',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const Spacer(),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Ajouter'),
              onPressed: () async {
                await Navigator.push(context,
                    MaterialPageRoute(builder: (_) => SoinFormScreen(lapinPreselect: lapin)));
                onRefresh();
              },
            ),
          ],
        ),
        if (soins.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                  child: Text('Aucun soin enregistré',
                      style: TextStyle(color: Colors.grey.shade500))),
            ),
          )
        else
          ...soins.map((s) => Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  leading: Icon(Icons.health_and_safety,
                      color: s.rappelUrgent ? AppTheme.warning : AppTheme.primary),
                  title: Text(s.typeSoin,
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text(
                    '${formatDate(s.dateSoin)}${s.produit != null ? " • ${s.produit}" : ""}'
                    '${s.delaiAttenteJours != null ? " • Délai ${s.delaiAttenteJours}j" : ""}',
                  ),
                  trailing: s.dateRappel != null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Rappel', style: TextStyle(fontSize: 10)),
                            Text(formatDate(s.dateRappel),
                                style: TextStyle(fontSize: 12,
                                    color: s.rappelUrgent ? AppTheme.warning : Colors.grey)),
                          ],
                        )
                      : null,
                ),
              )),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Micro-widgets réutilisables
// ─────────────────────────────────────────────

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade500),
          const SizedBox(width: 10),
          Text('$label : ', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          Expanded(child: Text(value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Modèle de données interne
// ─────────────────────────────────────────────

class _TimelineEvent {
  final DateTime date;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  _TimelineEvent({
    required this.date, required this.icon, required this.color,
    required this.title, required this.subtitle,
  });
}
