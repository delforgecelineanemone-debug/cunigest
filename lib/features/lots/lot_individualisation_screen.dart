// ──────────────────────────────────────────────────────────────
// Écran : Individualisation d'un lot (V2.5 — Phase 4.5)
// ──────────────────────────────────────────────────────────────
// Étape déclenchée à J+60 (sexage). Crée N fiches Lapin individuelles
// à partir d'un lot agrégé issu d'une mise bas.
//
// Pour chaque lapereau :
//   - Bague auto LP-AAAA-MM-XXX (modifiable)
//   - Sexe (mâle/femelle) — obligatoire
//   - Cage (héritée de la cage par défaut, modifiable)
//   - Poids (optionnel)
//   - Nom (optionnel)
//
// Au save : crée N Lapin avec mereId/pereId hérités de la saillie
// d'origine, dateNaissance = lot.dateCreation. Le lot passe en statut
// 'individualise' et son nombre_initial est mis à jour si l'éleveur a
// décrémenté (mortalités saisies en bloc).
// ──────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../../database/db_helper.dart';
import '../../models/batiment.dart';
import '../../models/cage.dart';
import '../../models/clapier.dart';
import '../../models/lapin.dart';
import '../../models/lot.dart';
import '../../models/saillie.dart';
import '../../services/id_generator_service.dart';
import '../../utils/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../ui/cu_ui.dart';

class LotIndividualisationScreen extends StatefulWidget {
  final Lot lot;
  const LotIndividualisationScreen({super.key, required this.lot});

  @override
  State<LotIndividualisationScreen> createState() =>
      _LotIndividualisationScreenState();
}

class _LotIndividualisationScreenState
    extends State<LotIndividualisationScreen> {
  final db = DBHelper.instance;
  late int _nbAIndividualiser;
  Saillie? _saillie;
  Lapin? _mere;
  Lapin? _pere;
  bool _loading = true;
  bool _saving = false;

  int? _cageDefautId;
  String? _cageDefautLabel;

  final List<_LigneLapereau> _lignes = [];

  @override
  void initState() {
    super.initState();
    _nbAIndividualiser = widget.lot.nombreInitial;
    _load();
  }

  Future<void> _load() async {
    // Charger saillie d'origine pour récupérer parents
    if (widget.lot.saillieId != null) {
      final saillies = await db.getAllSaillies();
      try {
        _saillie =
            saillies.firstWhere((s) => s.id == widget.lot.saillieId);
        final lapins = await db.getAllLapins();
        try {
          _mere = lapins.firstWhere((l) => l.id == _saillie!.mereId);
        } catch (_) {/* mère supprimée */}
        try {
          _pere = lapins.firstWhere((l) => l.id == _saillie!.pereId);
        } catch (_) {/* père supprimé */}
      } catch (_) {/* saillie supprimée */}
    }
    await _regenererLignes();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _regenererLignes() async {
    _lignes.clear();
    // Pré-générer N bagues séquentiellement
    final base = await IdGeneratorService.nextLapinId();
    final baseParts = base.split('-');
    final basePrefix = baseParts.sublist(0, baseParts.length - 1).join('-');
    final baseNum = int.tryParse(baseParts.last) ?? 1;

    for (int i = 0; i < _nbAIndividualiser; i++) {
      final num = (baseNum + i).toString().padLeft(3, '0');
      _lignes.add(_LigneLapereau(
        bague: '$basePrefix-$num',
        sexe: null,
        cageId: _cageDefautId,
        cageLabel: _cageDefautLabel,
      ));
    }
  }

  Future<void> _changerNombre() async {
    final ctrl = TextEditingController(text: _nbAIndividualiser.toString());
    final res = await showDialog<int>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Nombre à individualiser'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                'Lot initial : ${widget.lot.nombreInitial} lapereaux.\nSi certains sont morts depuis, baissez ce nombre.',
                style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                  labelText: 'Nombre actuel', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              final v = int.tryParse(ctrl.text);
              if (v != null && v > 0 && v <= widget.lot.nombreInitial) {
                Navigator.pop(dialogCtx, v);
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (res == null || res == _nbAIndividualiser) return;
    setState(() => _nbAIndividualiser = res);
    await _regenererLignes();
    if (mounted) setState(() {});
  }

  Future<void> _pickCageDefaut() async {
    final result = await _ouvrirCagePicker();
    if (result == null) return;
    setState(() {
      _cageDefautId = result.cageId;
      _cageDefautLabel = result.label;
      // Appliquer aux lignes qui n'ont pas encore de cage explicite
      for (final l in _lignes) {
        l.cageId = result.cageId;
        l.cageLabel = result.label;
      }
    });
  }

  Future<void> _pickCageLigne(_LigneLapereau ligne) async {
    final result = await _ouvrirCagePicker();
    if (result == null) return;
    setState(() {
      ligne.cageId = result.cageId;
      ligne.cageLabel = result.label;
    });
  }

  Future<_CagePickResult?> _ouvrirCagePicker() {
    return showModalBottomSheet<_CagePickResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CagePickerSheet(),
    );
  }

  Future<void> _save() async {
    // Validation : chaque ligne doit avoir un sexe
    final sansSexe = _lignes.where((l) => l.sexe == null).toList();
    if (sansSexe.isNotEmpty) {
      showErrorSnackBar(context,
          '${sansSexe.length} lapereau(x) sans sexe. Renseigne tous les sexes avant de valider.');
      return;
    }
    // Validation : bagues uniques entre elles
    final bagues = _lignes.map((l) => l.bague.trim()).toList();
    if (bagues.toSet().length != bagues.length) {
      showErrorSnackBar(
          context, 'Certaines bagues sont en double. Régénère ou corrige.');
      return;
    }

    final ok = await showConfirmDialog(
      context,
      title: 'Créer ${_lignes.length} fiches lapin ?',
      message:
          'Le lot ${widget.lot.code} passera en statut "individualisé" et ne pourra plus être modifié comme un lot agrégé.',
      confirmLabel: 'Valider',
    );
    if (!ok) return;

    setState(() => _saving = true);
    try {
      // Créer les N fiches Lapin
      for (final l in _lignes) {
        final lapin = Lapin(
          numeroBague: l.bague.trim(),
          nom: l.nom?.trim().isEmpty ?? true ? null : l.nom!.trim(),
          sexe: l.sexe!,
          dateNaissance: widget.lot.dateCreation,
          poids: l.poids,
          statut: 'actif',
          cageId: l.cageId,
          pereId: _saillie?.pereId,
          mereId: _saillie?.mereId,
          notes: 'Issu du lot ${widget.lot.code}',
        );
        await db.insertLapin(lapin);
      }

      // Mettre à jour le lot
      final lotsRepo = await db.lots;
      final lotMaj = widget.lot.copyWith(
        statut: 'individualise',
        nombreInitial: _lignes.length,
        dateFin: DateTime.now().toIso8601String().substring(0, 10),
      );
      await lotsRepo.update(lotMaj);

      // Marquer comme traitées les alertes sexage_j60 liées
      await _marquerAlertesSexageTraitees();

      if (mounted) {
        showSuccessSnackBar(context,
            '${_lignes.length} fiche(s) lapin créée(s) ! Lot ${widget.lot.code} individualisé.');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showErrorSnackBar(context, 'Erreur : $e');
      }
    }
  }

  Future<void> _marquerAlertesSexageTraitees() async {
    final dbInstance = await db.database;
    final lotId = widget.lot.id;
    final saillieId = widget.lot.saillieId;
    if (lotId != null) {
      await dbInstance.update(
        'alertes',
        {'est_traitee': 1, 'est_lue': 1},
        where: "type LIKE 'sexage_%' AND reference_type = 'lot' AND reference_id = ?",
        whereArgs: [lotId],
      );
    }
    if (saillieId != null) {
      await dbInstance.update(
        'alertes',
        {'est_traitee': 1, 'est_lue': 1},
        where: "type LIKE 'sexage_%' AND reference_type = 'saillie' AND reference_id = ?",
        whereArgs: [saillieId],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ageJours = _calculerAge();
    return Scaffold(
      appBar: CuAppBar(title: 'Individualiser ${widget.lot.code}', showActions: false),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Bandeau d'info
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  color: AppTheme.moduleRepro.withValues(alpha: 0.08),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('🐰 Lot ${widget.lot.code}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text(
                        '${_mere?.displayName ?? "?"} × ${_pere?.displayName ?? "?"} • Né le ${formatDate(widget.lot.dateCreation)}${ageJours != null ? " • $ageJours j" : ""}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),

                // Réglages globaux
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.numbers, size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                    'Nombre à individualiser : $_nbAIndividualiser',
                                    style: const TextStyle(fontSize: 13)),
                              ),
                              TextButton(
                                onPressed: _saving ? null : _changerNombre,
                                child: const Text('Modifier'),
                              ),
                            ],
                          ),
                          if (_nbAIndividualiser < widget.lot.nombreInitial)
                            Text(
                              '${widget.lot.nombreInitial - _nbAIndividualiser} mortalité(s) déclarée(s)',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.error,
                                  fontStyle: FontStyle.italic),
                            ),
                          const Divider(height: 16),
                          InkWell(
                            onTap: _saving ? null : _pickCageDefaut,
                            child: Row(
                              children: [
                                const Icon(Icons.grid_view, size: 18),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _cageDefautLabel != null
                                        ? 'Cage par défaut : $_cageDefautLabel'
                                        : 'Définir une cage par défaut (optionnel)',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: _cageDefautLabel != null
                                            ? Colors.black87
                                            : Colors.grey),
                                  ),
                                ),
                                const Icon(Icons.chevron_right, size: 18),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Liste des lapereaux
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
                    itemCount: _lignes.length,
                    itemBuilder: (_, i) => _LapereauLineWidget(
                      ligne: _lignes[i],
                      position: i + 1,
                      saving: _saving,
                      onSexeChanged: (sexe) =>
                          setState(() => _lignes[i].sexe = sexe),
                      onCageTap: () => _pickCageLigne(_lignes[i]),
                    ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: _loading
          ? null
          : Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check),
                label: Text(_saving
                    ? 'Création en cours...'
                    : 'Créer ${_lignes.length} fiches lapin'),
              ),
            ),
    );
  }

  int? _calculerAge() {
    final d = DateTime.tryParse(widget.lot.dateCreation);
    if (d == null) return null;
    return DateTime.now().difference(d).inDays;
  }
}

// ──────────────────────────────────────────────────────────────

class _LapereauLineWidget extends StatelessWidget {
  final _LigneLapereau ligne;
  final int position;
  final bool saving;
  final void Function(String?) onSexeChanged;
  final VoidCallback onCageTap;

  const _LapereauLineWidget({
    required this.ligne,
    required this.position,
    required this.saving,
    required this.onSexeChanged,
    required this.onCageTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                  child: Text(
                    '$position',
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    initialValue: ligne.bague,
                    decoration: const InputDecoration(
                      labelText: 'Bague',
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                    onChanged: (v) => ligne.bague = v,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Text('Sexe :', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 10),
                Expanded(
                  child: SegmentedButton<String>(
                    style: SegmentedButton.styleFrom(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    segments: const [
                      ButtonSegment(value: 'male', label: Text('♂')),
                      ButtonSegment(value: 'femelle', label: Text('♀')),
                    ],
                    emptySelectionAllowed: true,
                    selected: ligne.sexe == null ? {} : {ligne.sexe!},
                    onSelectionChanged: (s) =>
                        onSexeChanged(s.isEmpty ? null : s.first),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: saving ? null : onCageTap,
              child: Row(
                children: [
                  const Icon(Icons.grid_view, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ligne.cageLabel ?? 'Aucune cage',
                      style: TextStyle(
                          fontSize: 12,
                          color: ligne.cageLabel != null
                              ? Colors.black87
                              : Colors.grey),
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 16),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Poids (kg)',
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                    onChanged: (v) => ligne.poids = double.tryParse(v),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Nom (optionnel)',
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                    onChanged: (v) => ligne.nom = v,
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

class _LigneLapereau {
  String bague;
  String? sexe; // 'male' / 'femelle' / null
  int? cageId;
  String? cageLabel;
  double? poids;
  String? nom;
  _LigneLapereau({
    required this.bague,
    this.sexe,
    this.cageId,
    this.cageLabel,
  });
}

// ──────────────────────────────────────────────────────────────
// Bottom-sheet : sélection hiérarchique d'une cage
// (version simplifiée — pas de check capacité strict, plusieurs
//  lapereaux peuvent être assignés à la même cage)
// ──────────────────────────────────────────────────────────────

class _CagePickResult {
  final int cageId;
  final String label;
  _CagePickResult(this.cageId, this.label);
}

class _CagePickerSheet extends StatefulWidget {
  const _CagePickerSheet();

  @override
  State<_CagePickerSheet> createState() => _CagePickerSheetState();
}

class _CagePickerSheetState extends State<_CagePickerSheet> {
  bool _loading = true;
  List<Batiment> _batiments = [];
  Map<int, List<Clapier>> _clapiersByBat = {};
  Map<int, List<Cage>> _cagesByClapier = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = await DBHelper.instance.cages;
    final bs = await repo.getAllBatiments();
    final clapiersByBat = <int, List<Clapier>>{};
    final cagesByClapier = <int, List<Cage>>{};
    for (final b in bs) {
      if (b.id == null) continue;
      final cls = await repo.getClapiersByBatiment(b.id!);
      clapiersByBat[b.id!] = cls;
      for (final cl in cls) {
        if (cl.id == null) continue;
        cagesByClapier[cl.id!] = await repo.getCagesByClapier(cl.id!);
      }
    }
    if (!mounted) return;
    setState(() {
      _batiments = bs;
      _clapiersByBat = clapiersByBat;
      _cagesByClapier = cagesByClapier;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (ctx, scroll) => Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 10),
            const Text('Sélectionner une cage',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _batiments.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Aucune cage configurée.\nCréez d\'abord un bâtiment, un clapier et des cages depuis le module Cages.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        )
                      : ListView(
                          controller: scroll,
                          children: _batiments.map(_buildBat).toList(),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBat(Batiment b) {
    return ExpansionTile(
      initiallyExpanded: true,
      leading: const Icon(Icons.home_work, color: AppTheme.primary),
      title:
          Text(b.nom, style: const TextStyle(fontWeight: FontWeight.bold)),
      children: (_clapiersByBat[b.id] ?? []).map((cl) {
        return Padding(
          padding: const EdgeInsets.only(left: 16),
          child: ExpansionTile(
            initiallyExpanded: true,
            leading:
                const Icon(Icons.shelves, color: Colors.indigo, size: 20),
            title: Text(cl.nom, style: const TextStyle(fontSize: 14)),
            children: (_cagesByClapier[cl.id] ?? []).map((cg) {
              return ListTile(
                leading: const Icon(Icons.grid_view, size: 18),
                title: Text(cg.numero),
                subtitle: Text(cg.statutLabel),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () => Navigator.pop(
                  context,
                  _CagePickResult(
                      cg.id!, '${b.nom} • ${cl.nom} • ${cg.numero}'),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}
