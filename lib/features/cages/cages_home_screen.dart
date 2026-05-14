// ──────────────────────────────────────────────────────────────
// Écran principal : Module Cages (V2.2 — Phase 2)
// ──────────────────────────────────────────────────────────────
// Vue hiérarchique : Bâtiment → Clapier → grille de cages.
// - Tap sur cage → détail (occupants, historique, actions)
// - Boutons d'ajout à chaque niveau
// - Édition / suppression via menu long-press ou icône
// - Couleur de la cage = statut (vide, occupée, gestante, etc.)
// - Bandeau d'occupation : « 2/3 » lapins
// ──────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../../database/db_helper.dart';
import '../../models/batiment.dart';
import '../../models/clapier.dart';
import '../../models/cage.dart';
import '../../services/pdf_service.dart';
import '../../utils/theme.dart';
import '../../widgets/common_widgets.dart';
import 'batiment_form_screen.dart';
import 'clapier_form_screen.dart';
import 'cage_form_screen.dart';
import 'cage_detail_screen.dart';

class CagesHomeScreen extends StatefulWidget {
  const CagesHomeScreen({super.key});

  @override
  State<CagesHomeScreen> createState() => _CagesHomeScreenState();
}

class _CagesHomeScreenState extends State<CagesHomeScreen> {
  bool _loading = true;
  List<Batiment> _batiments = [];
  Map<int, List<Clapier>> _clapiersByBat = {};
  Map<int, List<Cage>> _cagesByClapier = {};
  Map<int, int> _occByCage = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final repo = await DBHelper.instance.cages;
      final batiments = await repo.getAllBatiments();

      // Charger clapiers et cages en parallèle par bâtiment
      final clapiersByBat = <int, List<Clapier>>{};
      final cagesByClapier = <int, List<Cage>>{};
      for (final b in batiments) {
        if (b.id == null) continue;
        final claps = await repo.getClapiersByBatiment(b.id!);
        clapiersByBat[b.id!] = claps;
        for (final c in claps) {
          if (c.id == null) continue;
          cagesByClapier[c.id!] = await repo.getCagesByClapier(c.id!);
        }
      }
      final occ = await repo.countOccupantsByCage();

      if (!mounted) return;
      setState(() {
        _batiments = batiments;
        _clapiersByBat = clapiersByBat;
        _cagesByClapier = cagesByClapier;
        _occByCage = occ;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showErrorSnackBar(context, 'Chargement impossible. Réessaye.');
    }
  }

  // ── Compteurs globaux ──
  int get _nbCagesTotal =>
      _cagesByClapier.values.fold<int>(0, (s, l) => s + l.length);
  int get _nbCagesOccupees => _occByCage.entries
      .where((e) => (e.value) > 0)
      .length;
  int get _nbLapinsHebergees =>
      _occByCage.values.fold<int>(0, (s, n) => s + n);

  // ── Actions ──

  Future<void> _ajouterBatiment() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const BatimentFormScreen()),
    );
    if (ok == true) await _load();
  }

  Future<void> _editerBatiment(Batiment b) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => BatimentFormScreen(batiment: b)),
    );
    if (ok == true) await _load();
  }

  Future<void> _supprimerBatiment(Batiment b) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Supprimer ce bâtiment ?',
      message:
          'Tous ses clapiers et cages seront aussi supprimés. Les lapins associés seront simplement détachés (cage_id mis à NULL).',
      confirmColor: AppTheme.error,
    );
    if (!ok) return;
    try {
      final repo = await DBHelper.instance.cages;
      await repo.deleteBatiment(b.id!);
      await _load();
    } catch (e) {
      if (mounted) showErrorSnackBar(context, 'Une erreur est survenue. Réessaye.');
    }
  }

  Future<void> _ajouterClapier(Batiment b) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ClapierFormScreen(batimentId: b.id!, batimentNom: b.nom),
      ),
    );
    if (ok == true) await _load();
  }

  Future<void> _editerClapier(Batiment b, Clapier c) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ClapierFormScreen(
          batimentId: b.id!,
          batimentNom: b.nom,
          clapier: c,
        ),
      ),
    );
    if (ok == true) await _load();
  }

  Future<void> _supprimerClapier(Clapier c) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Supprimer ce clapier ?',
      message:
          'Toutes ses cages seront aussi supprimées. Les lapins associés seront détachés.',
      confirmColor: AppTheme.error,
    );
    if (!ok) return;
    try {
      final repo = await DBHelper.instance.cages;
      await repo.deleteClapier(c.id!);
      await _load();
    } catch (e) {
      if (mounted) showErrorSnackBar(context, 'Une erreur est survenue. Réessaye.');
    }
  }

  Future<void> _ajouterCage(Clapier c) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CageFormScreen(clapierId: c.id!, clapierNom: c.nom),
      ),
    );
    if (ok == true) await _load();
  }

  Future<void> _imprimerToutesEtiquettes() async {
    final allCages =
        _cagesByClapier.values.expand((l) => l).toList(growable: false);
    if (allCages.isEmpty) {
      showErrorSnackBar(context, 'Aucune cage à imprimer.');
      return;
    }
    try {
      final clapiers = <int, Clapier>{};
      final batiments = <int, Batiment>{};
      for (final list in _clapiersByBat.values) {
        for (final c in list) {
          if (c.id != null) clapiers[c.id!] = c;
        }
      }
      for (final b in _batiments) {
        if (b.id != null) batiments[b.id!] = b;
      }
      final bytes = await PdfService.instance.genererCartesCagesPDF(
        cages: allCages,
        clapiersById: clapiers,
        batimentsById: batiments,
      );
      await PdfService.instance
          .previsualiser(bytes, title: 'Etiquettes_cages');
    } catch (e) {
      if (mounted) showErrorSnackBar(context, 'Génération PDF impossible. Réessaye.');
    }
  }

  Future<void> _ouvrirCage(Cage cage) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => CageDetailScreen(cageId: cage.id!)),
    );
    if (ok == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cages'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Imprimer toutes les étiquettes',
            onPressed: _imprimerToutesEtiquettes,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Rafraîchir',
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _batiments.isEmpty
              ? EmptyState(
                  icon: Icons.home_work,
                  message:
                      'Aucun bâtiment.\nCommencez par créer un bâtiment, puis un clapier, puis vos cages.',
                  actionLabel: 'Créer mon premier bâtiment',
                  onAction: _ajouterBatiment,
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      _statsHeader(),
                      const SizedBox(height: 8),
                      ..._batiments.map(_buildBatimentTile),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
      floatingActionButton: _batiments.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _ajouterBatiment,
              icon: const Icon(Icons.add),
              label: const Text('Bâtiment'),
            ),
    );
  }

  Widget _statsHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            MiniStatBadge(
                label: 'Cages', count: _nbCagesTotal, color: AppTheme.primary),
            const SizedBox(width: 8),
            MiniStatBadge(
                label: 'Occupées',
                count: _nbCagesOccupees,
                color: const Color(0xFF1976D2)),
            const SizedBox(width: 8),
            MiniStatBadge(
                label: 'Lapins',
                count: _nbLapinsHebergees,
                color: AppTheme.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildBatimentTile(Batiment b) {
    final clapiers = _clapiersByBat[b.id] ?? [];
    final nbCages = clapiers.fold<int>(
        0, (s, c) => s + (_cagesByClapier[c.id]?.length ?? 0));
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: const Icon(Icons.home_work, color: AppTheme.primary),
        title: Text(b.nom,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text(
          '${clapiers.length} clapier${clapiers.length > 1 ? "s" : ""} • $nbCages cage${nbCages > 1 ? "s" : ""}',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'edit') _editerBatiment(b);
            if (v == 'add_clapier') _ajouterClapier(b);
            if (v == 'delete') _supprimerBatiment(b);
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
                value: 'add_clapier',
                child: ListTile(
                    leading: Icon(Icons.add),
                    title: Text('Ajouter un clapier'))),
            PopupMenuItem(
                value: 'edit',
                child: ListTile(
                    leading: Icon(Icons.edit), title: Text('Modifier'))),
            PopupMenuItem(
                value: 'delete',
                child: ListTile(
                    leading: Icon(Icons.delete, color: Colors.red),
                    title: Text('Supprimer',
                        style: TextStyle(color: Colors.red)))),
          ],
        ),
        children: [
          if (clapiers.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    'Aucun clapier dans ce bâtiment.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Ajouter un clapier'),
                    onPressed: () => _ajouterClapier(b),
                  ),
                ],
              ),
            )
          else
            ...clapiers.map((c) => _buildClapierTile(b, c)),
        ],
      ),
    );
  }

  Widget _buildClapierTile(Batiment b, Clapier c) {
    final cages = _cagesByClapier[c.id] ?? [];
    final occCount = cages
        .where((cg) => (_occByCage[cg.id] ?? 0) > 0)
        .length;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: const Icon(Icons.shelves, color: Colors.indigo),
        title: Text(c.nom,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(
          '${cages.length} cage${cages.length > 1 ? "s" : ""} • $occCount occupée${occCount > 1 ? "s" : ""}',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'edit') _editerClapier(b, c);
            if (v == 'add_cage') _ajouterCage(c);
            if (v == 'delete') _supprimerClapier(c);
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
                value: 'add_cage',
                child: ListTile(
                    leading: Icon(Icons.add),
                    title: Text('Ajouter une cage'))),
            PopupMenuItem(
                value: 'edit',
                child: ListTile(
                    leading: Icon(Icons.edit), title: Text('Modifier'))),
            PopupMenuItem(
                value: 'delete',
                child: ListTile(
                    leading: Icon(Icons.delete, color: Colors.red),
                    title: Text('Supprimer',
                        style: TextStyle(color: Colors.red)))),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: cages.isEmpty
                ? Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text('Aucune cage.',
                            style: TextStyle(color: Colors.grey.shade600)),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Ajouter une cage'),
                        onPressed: () => _ajouterCage(c),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      GridView.count(
                        crossAxisCount: 3,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 1.0,
                        children: cages.map(_buildCageCell).toList(),
                      ),
                      const SizedBox(height: 6),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Cage'),
                        onPressed: () => _ajouterCage(c),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCageCell(Cage cage) {
    final color = cageStatutColor(cage.statut);
    final occ = _occByCage[cage.id] ?? 0;
    final cap = cage.capaciteMax;
    final pleine = occ >= cap;
    return InkWell(
      onTap: () => _ouvrirCage(cage),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.all(6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(cageStatutIcon(cage.statut), color: color, size: 16),
                if (pleine)
                  const Icon(Icons.lock, size: 12, color: Colors.redAccent),
              ],
            ),
            Text(
              cage.numero,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: color,
              ),
            ),
            Text(
              '$occ/$cap',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }
}
