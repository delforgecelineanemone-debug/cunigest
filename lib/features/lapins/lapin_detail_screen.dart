// ──────────────────────────────────────────────────────────────
// Écran : Fiche détaillée d'un lapin
// ──────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/db_helper.dart';
import '../../models/batiment.dart';
import '../../models/cage.dart';
import '../../models/clapier.dart';
import '../../models/lapin.dart';
import '../../models/mouvement_cage.dart';
import '../../models/pesee_lapin.dart';
import '../../models/saillie.dart';
import '../../models/soin.dart';
import '../../providers/lapin_detail_notifier.dart';
import '../../services/pdf_service.dart';
import '../../utils/theme.dart';
import '../../utils/validators.dart';
import '../../widgets/common_widgets.dart';
import '../cages/cage_detail_screen.dart';
import '../sante/soin_form_screen.dart';
import '../qr/qr_display_screen.dart';
import 'lapin_form_screen.dart';
import 'widgets/lapin_detail_sections.dart';
import '../../ui/cu_ui.dart';

class LapinDetailScreen extends ConsumerStatefulWidget {
  final Lapin lapin;
  const LapinDetailScreen({super.key, required this.lapin});

  @override
  ConsumerState<LapinDetailScreen> createState() => _LapinDetailScreenState();
}

class _LapinDetailScreenState extends ConsumerState<LapinDetailScreen> {
  final db = DBHelper.instance;

  // Cache du dernier snapshot rendu — alimenté à chaque build depuis le
  // LapinDetailNotifier. Permet aux méthodes d'action (_ajouterPesee,
  // _declarerMortalite…) d'accéder à l'état courant sans re-fetch.
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
  List<TimelineEvent> _timeline = [];
  double _depensesLapin = 0;
  double _ventesLapin = 0;

  @override
  void initState() {
    super.initState();
    lapin = widget.lapin;
  }

  /// Recharge la fiche via le notifier. Le DataBus déclenche aussi un
  /// refresh automatique — cet appel explicite reste utile au retour
  /// d'un sous-écran qui n'a pas écrit en base.
  Future<void> _load() async {
    await ref.read(lapinDetailProvider(widget.lapin.id!).notifier).refresh();
  }

  /// Recopie le snapshot du notifier dans les champs locaux + reconstruit
  /// la timeline (présentation pure). Appelé en début de `data:` callback.
  void _syncFromData(LapinDetailData d) {
    lapin = d.lapin;
    _soins = d.soins;
    _pere = d.pere;
    _mere = d.mere;
    _delaiActif = d.delaiActif;
    _cage = d.cage;
    _clapier = d.clapier;
    _batiment = d.batiment;
    _mvts = d.mvts;
    _pesees = d.pesees;
    _depensesLapin = d.depensesLapin;
    _ventesLapin = d.ventesLapin;
    _timeline = _construireTimeline(
      lapinFrais: d.lapin,
      soins: d.soins,
      pesees: d.pesees,
      mvts: d.mvts,
      saillies: d.saillies,
    );
  }

  List<TimelineEvent> _construireTimeline({
    required Lapin lapinFrais,
    required List<Soin> soins,
    required List<PeseeLapin> pesees,
    required List<MouvementCage> mvts,
    required List<Saillie> saillies,
  }) {
    final events = <TimelineEvent>[];

    if (lapinFrais.dateNaissance != null) {
      final d = DateTime.tryParse(lapinFrais.dateNaissance!);
      if (d != null) {
        events.add(TimelineEvent(date: d, icon: Icons.cake,
            color: CuColors.timelineNaissance, title: 'Naissance',
            subtitle: lapinFrais.race ?? ''));
      }
    }

    for (final p in pesees) {
      final d = DateTime.tryParse(p.datePesee);
      if (d == null) continue;
      events.add(TimelineEvent(date: d, icon: Icons.scale,
          color: AppTheme.primary,
          title: 'Pesée — ${p.poids.toStringAsFixed(2)} kg',
          subtitle: p.notes ?? ''));
    }

    for (final s in soins) {
      final d = DateTime.tryParse(s.dateSoin);
      if (d == null) continue;
      events.add(TimelineEvent(date: d, icon: Icons.health_and_safety,
          color: CuColors.timelineSoin, title: s.typeSoin, subtitle: s.produit ?? ''));
    }

    for (final m in mvts) {
      final d = DateTime.tryParse(m.date);
      if (d == null) continue;
      final isSortie = m.cageDestinationId == null;
      events.add(TimelineEvent(
        date: d,
        icon: isSortie ? Icons.logout : Icons.move_to_inbox,
        color: isSortie ? CuColors.timelineMouvementSortie : CuColors.timelineMouvementEntree,
        title: isSortie ? 'Sortie de cage'
            : (m.cageOrigineId == null ? 'Premier placement' : 'Déplacement de cage'),
        subtitle: m.motif ?? '',
      ));
    }

    final estFemelle = lapinFrais.sexe == 'femelle';
    for (final s in saillies) {
      final dSaillie = DateTime.tryParse(s.dateSaillie);
      if (dSaillie != null) {
        events.add(TimelineEvent(date: dSaillie, icon: Icons.favorite,
            color: CuColors.timelineSaillie,
            title: estFemelle ? 'Saillie' : 'Saillie (père)',
            subtitle: s.statutLabel));
      }

      if (!estFemelle) continue;

      if (s.dateMiseBasReelle != null) {
        final d = DateTime.tryParse(s.dateMiseBasReelle!);
        if (d != null) {
          final nb = s.nbVivants;
          events.add(TimelineEvent(
            date: d, icon: Icons.child_care, color: CuColors.timelineMiseBas,
            title: 'Mise bas${nb != null ? " — $nb vivants" : ""}',
            subtitle: s.nbMorts != null && s.nbMorts! > 0 ? '${s.nbMorts} mort-né(s)' : '',
          ));
        }
      }

      if (s.dateSevrage != null) {
        final d = DateTime.tryParse(s.dateSevrage!);
        if (d != null) {
          events.add(TimelineEvent(
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
    // V2.5 — UX Sprint 1 : validation centralisée (bornes 10g-12kg).
    final erreur = Validators.poidsLapin(ctrl.text, requisField: true);
    if (erreur != null) {
      if (mounted) showErrorSnackBar(context, erreur);
      return;
    }
    final poids = double.parse(ctrl.text.replaceAll(',', '.'));
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

  /// Déclare le lapin mort en 1 tap depuis la fiche.
  /// Workflow rapide terrain : sélection cause + date (aujourd'hui par défaut)
  /// → confirme → update statut + cause → log dans la timeline.
  Future<void> _declarerMortalite() async {
    if (lapin.statut == 'mort' || lapin.id == null) return;
    final messenger = ScaffoldMessenger.of(context);
    String causeCode = 'inconnue';
    DateTime dateMort = DateTime.now();
    final notesCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (_, setSt) => AlertDialog(
          title: const Text('Déclarer ce lapin mort'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Cette action est irréversible — le lapin ne pourra plus '
                  'apparaître dans les listes actives.',
                  style: TextStyle(
                      fontSize: 13, color: context.cuTextSecondary),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: causeCode,
                  decoration: const InputDecoration(
                    labelText: 'Cause',
                    prefixIcon: Icon(Icons.medical_information_outlined),
                  ),
                  items: Lapin.causesMortalite.entries
                      .map((e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)))
                      .toList(),
                  onChanged: (v) => setSt(() => causeCode = v ?? causeCode),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today),
                  title: Text('Date : ${dateMort.day}/${dateMort.month}/${dateMort.year}'),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: dateMort,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (d != null) setSt(() => dateMort = d);
                  },
                ),
                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optionnel)',
                    hintText: 'Symptômes observés, traitement tenté…',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annuler')),
            FilledButton.icon(
              icon: const Icon(Icons.check),
              style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
              onPressed: () => Navigator.pop(ctx, true),
              label: const Text('Confirmer'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final notes = notesCtrl.text.trim().isEmpty
          ? null
          : '${lapin.notes ?? ''}\n[Mortalité ${dateMort.toIso8601String().substring(0, 10)}] ${notesCtrl.text.trim()}'
              .trim();
      final updated = lapin.copyWith(
        statut: 'mort',
        causeMortalite: causeCode,
        notes: notes,
      );
      await (await db.lapins).updateLapin(updated);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text('${lapin.displayName} déclaré mort (${Lapin.causesMortalite[causeCode] ?? causeCode}).'),
        backgroundColor: AppTheme.error,
      ));
      await _load();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text('Erreur : $e'),
        backgroundColor: AppTheme.error,
      ));
    }
  }

  Future<void> _confirmerSuppression() async {
    final ok = await showConfirmDialog(context,
        title: 'Supprimer ce lapin ?',
        message:
            'Vous aurez 5 secondes pour annuler après confirmation. '
            'Au-delà, ${lapin.displayName} sera définitivement supprimé.',
        confirmColor: AppTheme.error);
    if (!ok || !mounted) return;
    // V2.5 — UX Sprint 2 : undo SnackBar 5s avant pop.
    bool annule = false;
    await UndoHelper.deleteWithUndo(
      context: context,
      label: lapin.displayName,
      delete: () async => (await db.lapins).deleteLapin(lapin.id!).then((_) {}),
      restore: () async => (await db.lapins).insertLapin(lapin).then((_) {}),
      onUndone: () => annule = true,
    );
    if (!annule && mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(lapinDetailProvider(widget.lapin.id!));
    return async.when(
      skipLoadingOnRefresh: true,
      loading: () => Scaffold(
        appBar: CuAppBar(title: widget.lapin.displayName, showActions: false),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: CuAppBar(title: widget.lapin.displayName, showActions: false),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline,
                    size: 48, color: CuColors.danger),
                const SizedBox(height: 12),
                Text('$e', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Retour'),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (d) {
        _syncFromData(d);
        return _buildScaffold(context);
      },
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final color = lapin.sexe == 'male'
        ? CuColors.sexeMale
        : CuColors.sexeFemelle;
    return Scaffold(
      appBar: CuAppBar(
        title: lapin.displayName,
        showActions: false,
        // V2.5 — Sprint 4 : Delete déplacé dans un menu overflow (2 taps)
        // pour éviter qu'un mis-tap sur Edit déclenche la suppression
        // (auparavant 4 IconButtons collés à 32dp = risque accidentel).
        extraActions: [
          IconButton(
              icon: const Icon(Icons.qr_code),
              tooltip: 'QR code',
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => QrDisplayScreen(lapin: lapin)))),
          IconButton(
              icon: const Icon(Icons.account_tree),
              tooltip: 'Pedigree PDF (4 gén.)',
              onPressed: _genererPedigree),
          IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Modifier',
              onPressed: () async {
                final r = await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => LapinFormScreen(lapin: lapin)));
                if (r == true) _load();
              }),
          PopupMenuButton<String>(
            tooltip: 'Plus d\'actions',
            icon: const Icon(Icons.more_vert),
            onSelected: (v) {
              switch (v) {
                case 'mortalite':
                  _declarerMortalite();
                  break;
                case 'delete':
                  _confirmerSuppression();
                  break;
              }
            },
            itemBuilder: (_) => [
              if (lapin.statut != 'mort')
                const PopupMenuItem(
                  value: 'mortalite',
                  child: Row(children: [
                    Icon(Icons.health_and_safety_outlined,
                        color: AppTheme.error),
                    SizedBox(width: 12),
                    Text('Déclarer mort'),
                  ]),
                ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(children: [
                  Icon(Icons.delete_outline, color: AppTheme.error),
                  SizedBox(width: 12),
                  Text('Supprimer',
                      style: TextStyle(color: AppTheme.error)),
                ]),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          LapinHeaderCard(lapin: lapin, color: color),
          if (_delaiActif != null) ...[
            const SizedBox(height: 12),
            DelaiAttenteBanner(delai: _delaiActif!),
          ],
          const SizedBox(height: 12),
          InfoCard(lapin: lapin, cage: _cage, clapier: _clapier,
              batiment: _batiment, onCageTap: () async {
                await Navigator.push(context,
                    MaterialPageRoute(builder: (_) => CageDetailScreen(cageId: _cage!.id!)));
                _load();
              }),
          const SizedBox(height: 12),
          if (_timeline.isNotEmpty) ...[
            TimelineCard(events: _timeline),
            const SizedBox(height: 12),
          ],
          GenealogieCard(pere: _pere, mere: _mere,
              onNavigate: (parent) async {
                await Navigator.push(context,
                    MaterialPageRoute(builder: (_) => LapinDetailScreen(lapin: parent)));
                _load();
              }),
          const SizedBox(height: 12),
          PeseesCard(pesees: _pesees,
              onAjouter: _ajouterPesee,
              onSupprimer: _supprimerPesee),
          const SizedBox(height: 12),
          RentabiliteCard(lapin: lapin, soins: _soins,
              depenses: _depensesLapin, ventes: _ventesLapin),
          const SizedBox(height: 12),
          if (_mvts.isNotEmpty) ...[
            HistoriqueCagesSection(mvts: _mvts),
            const SizedBox(height: 12),
          ],
          SoinsSection(soins: _soins, lapin: lapin, onRefresh: _load),
          const SizedBox(height: 80),
        ],
      ).responsive(),
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

