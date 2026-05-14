// ──────────────────────────────────────────────────────────────
// Écran : Détail d'une cage (V2.2 — Phase 2 cages)
// ──────────────────────────────────────────────────────────────
// Vue complète d'une cage :
// - Identité (numéro, clapier, bâtiment)
// - Statut + capacité + occupation visuelle (occ / cap)
// - Liste des occupants (lapins présents, tap → fiche lapin)
// - Bouton « Déplacer un lapin ici » (sélection lapin externe)
// - Bouton « Sortir » sur chaque occupant (déplacement vers NULL)
// - Historique des mouvements (entrée/sortie)
// - Actions : Modifier, Supprimer, Voir le QR
// ──────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../database/db_helper.dart';
import '../../models/batiment.dart';
import '../../models/cage.dart';
import '../../models/clapier.dart';
import '../../models/lapin.dart';
import '../../models/mouvement_cage.dart';
import '../../providers/state_providers.dart';
import '../../services/pdf_service.dart';
import '../../utils/theme.dart';
import '../../widgets/common_widgets.dart';
import '../lapins/lapin_detail_screen.dart';
import 'cage_form_screen.dart';

class CageDetailScreen extends ConsumerStatefulWidget {
  final int cageId;
  const CageDetailScreen({super.key, required this.cageId});

  @override
  ConsumerState<CageDetailScreen> createState() => _CageDetailScreenState();
}

class _CageDetailScreenState extends ConsumerState<CageDetailScreen> {
  bool _loading = true;
  Cage? _cage;
  Clapier? _clapier;
  Batiment? _batiment;
  List<Lapin> _occupants = [];
  List<MouvementCage> _historique = [];
  Map<int, Lapin> _lapinsCache = {}; // id → lapin (pour résoudre les noms dans l'historique)

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final repo = await DBHelper.instance.cages;
      final cage = await repo.getCageById(widget.cageId);
      if (cage == null) {
        if (mounted) Navigator.pop(context);
        return;
      }
      final clapier = await repo.getClapierById(cage.clapierId);
      final batiment =
          clapier != null ? await repo.getBatimentById(clapier.batimentId) : null;
      final occupants = await repo.getOccupants(cage.id!);
      final hist = await repo.getHistoriqueCage(cage.id!);

      // Cache les lapins référencés dans l'historique pour afficher leur nom
      final ids = <int>{
        ...occupants.where((l) => l.id != null).map((l) => l.id!),
        ...hist.map((h) => h.lapinId),
      };
      final cache = <int, Lapin>{};
      for (final id in ids) {
        final l = await DBHelper.instance.getLapinById(id);
        if (l != null) cache[id] = l;
      }

      if (!mounted) return;
      setState(() {
        _cage = cage;
        _clapier = clapier;
        _batiment = batiment;
        _occupants = occupants;
        _historique = hist;
        _lapinsCache = cache;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showErrorSnackBar(context, 'Chargement impossible. Réessaye.');
    }
  }

  Future<void> _editer() async {
    if (_cage == null || _clapier == null) return;
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CageFormScreen(
          clapierId: _clapier!.id!,
          clapierNom: _clapier!.nom,
          cage: _cage,
        ),
      ),
    );
    if (ok == true) await _load();
  }

  Future<void> _supprimer() async {
    if (_cage == null) return;
    if (_occupants.isNotEmpty) {
      showErrorSnackBar(context,
          'Impossible : la cage contient ${_occupants.length} lapin(s). Sortez-les d\'abord.');
      return;
    }
    final ok = await showConfirmDialog(
      context,
      title: 'Supprimer cette cage ?',
      message: 'Numéro ${_cage!.numero}. Action irréversible.',
      confirmColor: AppTheme.error,
    );
    if (!ok) return;
    try {
      final repo = await DBHelper.instance.cages;
      await repo.deleteCage(_cage!.id!);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showErrorSnackBar(context, 'Une erreur est survenue. Réessaye.');
    }
  }

  Future<void> _imprimerEtiquette() async {
    if (_cage == null) return;
    try {
      final clapiers = <int, Clapier>{};
      final batiments = <int, Batiment>{};
      if (_clapier != null) clapiers[_clapier!.id!] = _clapier!;
      if (_batiment != null) batiments[_batiment!.id!] = _batiment!;
      final bytes = await PdfService.instance.genererCartesCagesPDF(
        cages: [_cage!],
        clapiersById: clapiers,
        batimentsById: batiments,
      );
      await PdfService.instance.previsualiser(bytes,
          title: 'Etiquette_${_cage!.numero}');
    } catch (e) {
      if (mounted) showErrorSnackBar(context, 'Génération PDF impossible. Réessaye.');
    }
  }

  Future<void> _voirQr() async {
    if (_cage?.qrPayload() == null) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('QR — Cage ${_cage!.numero}'),
        content: SizedBox(
          width: 240,
          height: 280,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              QrImageView(
                data: _cage!.qrPayload()!,
                size: 220,
                backgroundColor: Colors.white,
              ),
              const SizedBox(height: 8),
              Text(_cage!.numero,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              if (_clapier != null && _batiment != null)
                Text('${_batiment!.nom} • ${_clapier!.nom}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Future<void> _deplacerLapinIci() async {
    if (_cage == null) return;
    final occMax = _cage!.capaciteMax;
    if (_occupants.length >= occMax) {
      showErrorSnackBar(context,
          'Cage pleine ($occMax/$occMax). Sortez un lapin avant d\'en ajouter un.');
      return;
    }
    final lapins = await DBHelper.instance.getAllLapins();
    final disponibles = lapins
        .where((l) =>
            l.id != null &&
            l.statut != 'mort' &&
            l.statut != 'vendu' &&
            l.cageId != _cage!.id)
        .toList();
    if (!mounted) return;
    if (disponibles.isEmpty) {
      showErrorSnackBar(context, 'Aucun lapin disponible à déplacer.');
      return;
    }
    final selected = await showModalBottomSheet<Lapin>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _LapinPickerSheet(lapins: disponibles),
    );
    if (selected == null || !mounted) return;

    final motif = await _demanderMotif();
    if (!mounted) return;

    try {
      final repo = await DBHelper.instance.cages;
      await repo.deplacerLapin(
        lapinId: selected.id!,
        cageDestinationId: _cage!.id,
        motif: motif,
      );
      // Refresh global state pour que la liste lapins soit à jour
      if (mounted) {
        await ref.read(lapinsProvider.notifier).refresh();
      }
      await _load();
      if (mounted) {
        showSuccessSnackBar(context,
            'Lapin ${selected.displayName} déplacé dans ${_cage!.numero}.');
      }
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _sortirLapin(Lapin l) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Sortir ce lapin ?',
      message:
          '${l.displayName} sera retiré de la cage ${_cage!.numero} (cage_id mise à NULL).',
      confirmLabel: 'Sortir',
      confirmColor: AppTheme.warning,
    );
    if (!ok) return;
    final motif = await _demanderMotif();
    if (!mounted) return;
    try {
      final repo = await DBHelper.instance.cages;
      await repo.deplacerLapin(
        lapinId: l.id!,
        cageDestinationId: null,
        motif: motif,
      );
      if (mounted) {
        await ref.read(lapinsProvider.notifier).refresh();
      }
      await _load();
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<String?> _demanderMotif() async {
    final ctrl = TextEditingController();
    return await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Motif du déplacement'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            hintText: 'Ex : sevrage, quarantaine, vente…',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Aucun'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(
                ctx, ctrl.text.trim().isEmpty ? null : ctrl.text.trim()),
            child: const Text('Valider'),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_cage == null) {
      return const Scaffold(body: Center(child: Text('Cage introuvable')));
    }
    final cage = _cage!;
    final color = cageStatutColor(cage.statut);
    final occ = _occupants.length;
    final cap = cage.capaciteMax;

    return Scaffold(
      appBar: AppBar(
        title: Text('Cage ${cage.numero}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_2),
            tooltip: 'Voir le QR',
            onPressed: _voirQr,
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'edit') _editer();
              if (v == 'delete') _supprimer();
              if (v == 'print') _imprimerEtiquette();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                  value: 'print',
                  child: ListTile(
                      leading: Icon(Icons.print),
                      title: Text('Imprimer l\'étiquette'))),
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
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            // ── En-tête statut/capacité ──
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(cageStatutIcon(cage.statut),
                          color: color, size: 30),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(cage.statutLabel,
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: color)),
                          const SizedBox(height: 2),
                          Text('Occupation : $occ / $cap',
                              style: TextStyle(
                                  fontSize: 13, color: Colors.grey.shade700)),
                          if (_batiment != null && _clapier != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '${_batiment!.nom} • ${_clapier!.nom}',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (cage.notes != null && cage.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Card(
                color: Colors.amber.shade50,
                child: ListTile(
                  leading: const Icon(Icons.notes, color: Colors.amber),
                  title: Text(cage.notes!),
                ),
              ),
            ],

            const SizedBox(height: 16),
            const SectionHeader(title: '🐇 Occupants'),
            if (_occupants.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Text('Cage vide.',
                        style: TextStyle(color: Colors.grey.shade600)),
                  ),
                ),
              )
            else
              Column(
                children: _occupants
                    .map((l) => _OccupantTile(
                          lapin: l,
                          onNavigate: () => Navigator.push(context,
                              MaterialPageRoute(
                                  builder: (_) => LapinDetailScreen(lapin: l))),
                          onSortir: () => _sortirLapin(l),
                        ))
                    .toList(),
              ),

            const SizedBox(height: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.move_to_inbox),
              label: const Text('Déplacer un lapin ici'),
              onPressed: _deplacerLapinIci,
            ),

            const SizedBox(height: 24),
            const SectionHeader(title: '📜 Historique des mouvements'),
            if (_historique.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Text('Aucun mouvement enregistré.',
                        style: TextStyle(color: Colors.grey.shade600)),
                  ),
                ),
              )
            else
              Column(
                children: _historique
                    .map((m) => _HistoriqueTile(
                          mvt: m,
                          lapinsCache: _lapinsCache,
                          cageId: _cage!.id!,
                        ))
                    .toList(),
              ),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

}

// ──────────────────────────────────────────────────────────────

class _OccupantTile extends StatelessWidget {
  final Lapin lapin;
  final VoidCallback onNavigate;
  final VoidCallback onSortir;

  const _OccupantTile({
    required this.lapin,
    required this.onNavigate,
    required this.onSortir,
  });

  @override
  Widget build(BuildContext context) {
    final l = lapin;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: l.sexe == 'male' ? Colors.blue : Colors.pink,
          child: Icon(
            l.sexe == 'male' ? Icons.male : Icons.female,
            color: Colors.white,
            size: 18,
          ),
        ),
        title: Text(l.displayName,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${l.numeroBague} • ${l.sexeLabel} • ${l.ageDisplay}'),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'open') onNavigate();
            if (v == 'out') onSortir();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
                value: 'open',
                child: ListTile(
                    leading: Icon(Icons.open_in_new),
                    title: Text('Voir la fiche'))),
            PopupMenuItem(
                value: 'out',
                child: ListTile(
                    leading: Icon(Icons.logout, color: Colors.orange),
                    title: Text('Sortir de la cage'))),
          ],
        ),
        onTap: onNavigate,
      ),
    );
  }
}

class _HistoriqueTile extends StatelessWidget {
  final MouvementCage mvt;
  final Map<int, Lapin> lapinsCache;
  final int cageId;

  const _HistoriqueTile({
    required this.mvt,
    required this.lapinsCache,
    required this.cageId,
  });

  @override
  Widget build(BuildContext context) {
    final lapin = lapinsCache[mvt.lapinId];
    final entree = mvt.cageDestinationId == cageId;
    final icon = entree ? Icons.login : Icons.logout;
    final iconColor = entree ? Colors.green : Colors.orange;
    final sens = entree ? 'Entrée' : 'Sortie';
    return Card(
      child: ListTile(
        leading: Icon(icon, color: iconColor),
        title: Text(
          '$sens : ${lapin?.displayName ?? "Lapin #${mvt.lapinId}"}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${formatDate(mvt.date)}${mvt.motif != null ? " • ${mvt.motif}" : ""}',
          style: const TextStyle(fontSize: 12),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Bottom-sheet : sélection d'un lapin à déplacer dans la cage
// ──────────────────────────────────────────────────────────────

class _LapinPickerSheet extends StatefulWidget {
  final List<Lapin> lapins;
  const _LapinPickerSheet({required this.lapins});

  @override
  State<_LapinPickerSheet> createState() => _LapinPickerSheetState();
}

class _LapinPickerSheetState extends State<_LapinPickerSheet> {
  String _filtre = '';

  @override
  Widget build(BuildContext context) {
    final filtered = _filtre.isEmpty
        ? widget.lapins
        : widget.lapins
            .where((l) =>
                l.numeroBague.toLowerCase().contains(_filtre.toLowerCase()) ||
                (l.nom?.toLowerCase().contains(_filtre.toLowerCase()) ?? false))
            .toList();
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.4,
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
            const Text('Sélectionner un lapin',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            TextField(
              decoration: const InputDecoration(
                hintText: 'Rechercher par bague ou nom',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _filtre = v),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text('Aucun résultat.',
                          style: TextStyle(color: Colors.grey.shade600)),
                    )
                  : ListView.builder(
                      controller: scroll,
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final l = filtered[i];
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  l.sexe == 'male' ? Colors.blue : Colors.pink,
                              child: Icon(
                                l.sexe == 'male'
                                    ? Icons.male
                                    : Icons.female,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                            title: Text(l.displayName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            subtitle: Text(
                                '${l.numeroBague} • ${l.statutLabel}'),
                            onTap: () => Navigator.pop(context, l),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
